import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// One group of Clock's settings as the account keeps it: an end-to-end
/// encrypted item of the Clock app (`app = 'clock'`, `kind = 'settings'`),
/// no database change. The groups are the world clock's cities, the saved
/// quick timers, the bedtime schedule, the holiday calendar and the night
/// clock (see `settings_sections.dart`).
///
/// With the alarms (`alarm_sync.dart`) this is everything a new phone
/// needs to look like the old one.
class SyncedSettings {
  const SyncedSettings({
    required this.id,
    required this.editedAt,
    required this.data,
  });

  /// `settings-<group>`, so it can never be an alarm's id.
  final String id;

  /// When the group was last changed by hand, in milliseconds.
  final int editedAt;
  final Map<String, Object?> data;

  static const prefix = 'settings-';
}

final syncedSettings = ZtCollection<SyncedSettings>(
  kind: 'settings',
  fromJson: (id, json, _) => SyncedSettings(
    id: id,
    editedAt: (json['editedAt'] as num?)?.toInt() ?? 0,
    data: switch (json['data']) {
      final Map m => m.cast<String, Object?>(),
      _ => const {},
    },
  ),
  toJson: (s) => {'editedAt': s.editedAt, 'data': s.data},
  idOf: (s) => s.id,
);

/// One group of settings on this phone.
abstract interface class SettingsSection {
  /// The group's name: `cities`, `quick-timers`, `bedtime`, `holidays`,
  /// `night-clock`.
  String get name;

  /// The group as a new install has it. A phone still like this has
  /// nothing of its own to keep.
  Map<String, Object?> get fresh;

  /// What is on this phone now. The same settings always give the same
  /// JSON (lists in order, map keys sorted).
  Future<Map<String, Object?>> read();

  /// Puts [data] on this phone. Not a change made by hand: it must not
  /// call [SettingsEdits.touch].
  Future<void> apply(Map<String, Object?> data);

  /// The first time this phone and the account meet with different
  /// settings on both sides: what to keep. Null: the newer one wins.
  Map<String, Object?>? merge(
    Map<String, Object?> here,
    Map<String, Object?> account,
  );
}

/// The account's copy of the settings groups, by group name.
abstract interface class SettingsVault {
  /// A null value: written by a newer app version, left alone.
  Future<Map<String, SyncedSettings?>> read();
  Future<void> save(SyncedSettings settings);

  /// Fires when the copy changed (another phone's change arrived).
  Stream<void> get changes;
}

/// [SettingsVault] on the shared encrypted store and sync of
/// Zero-Trust-Core, next to the alarms.
class StoreSettingsVault implements SettingsVault {
  StoreSettingsVault(this._store, this._sync);

  final LocalItemStore _store;
  final SyncController _sync;

  @override
  Future<Map<String, SyncedSettings?>> read() async {
    final out = <String, SyncedSettings?>{};
    for (final item in await _store.all()) {
      if (item.deleted || !syncedSettings.owns(item.json)) continue;
      if (!item.itemId.startsWith(SyncedSettings.prefix)) continue;
      final name = item.itemId.substring(SyncedSettings.prefix.length);
      out[name] = ZtCollection.versionOf(item.json!) > syncedSettings.version
          ? null
          : syncedSettings.decode(item);
    }
    return out;
  }

  @override
  Future<void> save(SyncedSettings settings) =>
      syncedSettings.save(_sync, _store, settings);

  @override
  Stream<void> get changes => switch (_store) {
    final ZtLocalStore s => s.changes.map((_) {}),
    _ => const Stream.empty(),
  };
}

/// When each settings group was last changed by hand on this phone, and
/// which groups this phone and the account have already compared.
class SettingsEdits {
  SettingsEdits(this._prefs, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final PreferencesStore _prefs;
  final DateTime Function() _now;
  static const _timesKey = 'clock_settings_edited';
  static const _metKey = 'clock_settings_met';

  final _changes = StreamController<void>.broadcast();

  /// Fires after [touch]: there is something to back up.
  Stream<void> get changes => _changes.stream;

  Future<Map<String, int>> _times() async {
    try {
      final raw = await _prefs.read(_timesKey);
      if (raw == null || raw.isEmpty) return {};
      return {
        for (final MapEntry(:key, :value) in (jsonDecode(raw) as Map).entries)
          if (key is String && value is num) key: value.toInt(),
      };
    } on Object {
      return {};
    }
  }

  /// 0: never changed by hand here.
  Future<int> editedAt(String name) async => (await _times())[name] ?? 0;

  Future<void> setEditedAt(String name, int at) async =>
      _prefs.write(_timesKey, jsonEncode({...await _times(), name: at}));

  /// The user changed the group [name] now.
  Future<void> touch(String name) async {
    await setEditedAt(name, _now().millisecondsSinceEpoch);
    _changes.add(null);
  }

  int nowMillis() => _now().millisecondsSinceEpoch;

  Future<Set<String>> _met() async {
    try {
      final raw = await _prefs.read(_metKey);
      if (raw == null || raw.isEmpty) return {};
      return {
        for (final name in jsonDecode(raw) as List)
          if (name is String) name,
      };
    } on Object {
      return {};
    }
  }

  /// Whether this phone and the account compared [name] before.
  Future<bool> met(String name) async => (await _met()).contains(name);

  Future<void> setMet(String name) async {
    final met = await _met();
    if (met.add(name)) await _prefs.write(_metKey, jsonEncode(met.toList()));
  }
}

final settingsEditsProvider = Provider<SettingsEdits>(
  (ref) => SettingsEdits(ref.watch(ztPreferencesStoreProvider)),
);

/// Backs up the settings groups and brings them to a new phone, one round
/// at a time: a call during a round runs one more round after it.
///
/// For each group the newer change wins, by the time it was made by hand.
/// A group never changed here takes the account's. The first time a phone
/// with its own cities or quick timers meets an account that has others,
/// both are kept ([SettingsSection.merge]). An account without a copy
/// never empties the phone.
class SettingsSync {
  SettingsSync({
    required this.sections,
    required this.vault,
    required this.edits,
  });

  final List<SettingsSection> sections;
  final SettingsVault vault;
  final SettingsEdits edits;

  Future<bool>? _running;
  bool _again = false;

  /// One round. True when something on this phone changed.
  Future<bool> run() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    final round = _loop();
    _running = round;
    return round.whenComplete(() => _running = null);
  }

  Future<bool> _loop() async {
    var changed = false;
    do {
      _again = false;
      changed = await _round() || changed;
    } while (_again);
    return changed;
  }

  static bool _same(Map<String, Object?> a, Map<String, Object?> b) =>
      jsonEncode(a) == jsonEncode(b);

  Future<bool> _round() async {
    final account = await vault.read();
    var changed = false;
    for (final section in sections) {
      final name = section.name;
      // Written by a newer app version: left alone, both ways.
      if (account.containsKey(name) && account[name] == null) continue;
      final theirs = account[name];
      final here = await section.read();
      var hereAt = await edits.editedAt(name);
      // Set up before the app kept times (or by a restore): older than
      // any change the account can hold, but still this phone's own.
      if (hereAt == 0 && !_same(here, section.fresh)) hereAt = 1;
      final id = '${SyncedSettings.prefix}$name';

      if (theirs == null) {
        if (hereAt > 0) {
          await vault.save(
            SyncedSettings(id: id, editedAt: hereAt, data: here),
          );
          await edits.setEditedAt(name, hereAt);
          await edits.setMet(name);
        }
        continue;
      }
      if (_same(here, theirs.data)) {
        if (hereAt != theirs.editedAt) {
          await edits.setEditedAt(name, theirs.editedAt);
        }
        await edits.setMet(name);
        continue;
      }
      final both = hereAt > 0 && !await edits.met(name)
          ? section.merge(here, theirs.data)
          : null;
      if (hereAt == 0) {
        // Nothing set up here: a new phone, or a group left as it came.
        await section.apply(theirs.data);
        await edits.setEditedAt(name, theirs.editedAt);
        changed = true;
      } else if (both != null) {
        // This phone and the account meet for the first time, each with
        // its own: both are kept.
        final at = edits.nowMillis();
        if (!_same(both, here)) {
          await section.apply(both);
          changed = true;
        }
        await edits.setEditedAt(name, at);
        if (!_same(both, theirs.data)) {
          await vault.save(SyncedSettings(id: id, editedAt: at, data: both));
        }
      } else if (theirs.editedAt > hereAt) {
        await section.apply(theirs.data);
        await edits.setEditedAt(name, theirs.editedAt);
        changed = true;
      } else if (hereAt > theirs.editedAt) {
        await vault.save(SyncedSettings(id: id, editedAt: hereAt, data: here));
        await edits.setEditedAt(name, hereAt);
      }
      // The same time and still different: the account's was taken before
      // and this phone keeps it its own way (a city it doesn't know). Not
      // sent back, so two phones can never push at each other for ever.
      await edits.setMet(name);
    }
    return changed;
  }
}
