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

  /// Before 0.17.1: the groups compared, for whichever account it was.
  static const _metKey = 'clock_settings_met';
  static const _metByAccountKey = 'clock_settings_met_by_account';

  final _changes = StreamController<void>.broadcast();

  /// Each change reads the saved map and writes it back. One at a time,
  /// so a backup round and a change made by hand can't lose each other's.
  Future<void> _queue = Future.value();

  Future<T> _oneAtATime<T>(Future<T> Function() work) {
    final result = _queue.then((_) => work());
    _queue = result.then((_) {}, onError: (Object _) {});
    return result;
  }

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

  Future<void> setEditedAt(String name, int at) => _oneAtATime(
    () async =>
        _prefs.write(_timesKey, jsonEncode({...await _times(), name: at})),
  );

  /// Sets the time of [name] to [at], but only when it still is [was]: a
  /// change made by hand in the meantime keeps its own, newer time.
  Future<bool> setEditedAtIf(
    String name, {
    required int was,
    required int at,
  }) => _oneAtATime(() async {
    final times = await _times();
    if ((times[name] ?? 0) != was) return false;
    if (was != at) {
      await _prefs.write(_timesKey, jsonEncode({...times, name: at}));
    }
    return true;
  });

  /// The user changed the group [name] now.
  Future<void> touch(String name) async {
    await setEditedAt(name, _now().millisecondsSinceEpoch);
    _changes.add(null);
  }

  int nowMillis() => _now().millisecondsSinceEpoch;

  static Set<String> _names(Object? list) => {
    if (list case final List names)
      for (final name in names)
        if (name is String) name,
  };

  /// The groups each account was compared with, by account.
  Future<Map<String, Set<String>>> _met(String account) async {
    try {
      final raw = await _prefs.read(_metByAccountKey);
      if (raw != null && raw.isNotEmpty) {
        return {
          for (final MapEntry(:key, :value) in (jsonDecode(raw) as Map).entries)
            if (key is String) key: _names(value),
        };
      }
      // Kept without the account before: it was the one signed in then,
      // which is the first to come by now.
      final old = await _prefs.read(_metKey);
      if (old == null || old.isEmpty) return {};
      return {account: _names(jsonDecode(old))};
    } on Object {
      return {};
    }
  }

  /// Whether this phone and [account] compared [name] before. Another
  /// account on the same phone starts over, so its first meeting keeps
  /// both sides too.
  Future<bool> met(String name, {String account = ''}) async =>
      (await _met(account))[account]?.contains(name) ?? false;

  Future<void> setMet(String name, {String account = ''}) => _oneAtATime(
    () async {
      final met = await _met(account);
      if (!met.putIfAbsent(account, () => {}).add(name) &&
          await _prefs.read(_metByAccountKey) != null) {
        return;
      }
      await _prefs.write(
        _metByAccountKey,
        jsonEncode({
          for (final MapEntry(:key, :value) in met.entries) key: value.toList(),
        }),
      );
    },
  );
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
    this.accountId = '',
  });

  final List<SettingsSection> sections;
  final SettingsVault vault;
  final SettingsEdits edits;

  /// Whose backup [vault] is (the account's id).
  final String accountId;

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
      final savedAt = await edits.editedAt(name);
      var hereAt = savedAt;
      // Set up before the app kept times (or by a restore): older than
      // any change the account can hold, but still this phone's own.
      if (hereAt == 0 && !_same(here, section.fresh)) hereAt = 1;
      final id = '${SyncedSettings.prefix}$name';
      // The group's time after this round. Not written when the user
      // changed the group meanwhile: that change keeps its newer time,
      // and the round it started sends it.
      Future<void> settle(int at) =>
          edits.setEditedAtIf(name, was: savedAt, at: at);
      // Asked right before the account's copy is written over the group:
      // a change made by hand since this round read it must stay. It is
      // left for the next round, which sees its newer time.
      Future<bool> changedMeanwhile() async {
        if (await edits.editedAt(name) == savedAt &&
            _same(await section.read(), here)) {
          return false;
        }
        _again = true;
        return true;
      }

      if (theirs == null) {
        if (hereAt > 0) {
          await vault.save(
            SyncedSettings(id: id, editedAt: hereAt, data: here),
          );
          await settle(hereAt);
          await edits.setMet(name, account: accountId);
        }
        continue;
      }
      if (_same(here, theirs.data)) {
        if (hereAt > theirs.editedAt) {
          // Changed and changed back here, later than the account knows:
          // the later time is sent, so an older change elsewhere can't
          // win over it.
          await vault.save(
            SyncedSettings(id: id, editedAt: hereAt, data: here),
          );
          await settle(hereAt);
        } else if (hereAt < theirs.editedAt) {
          await settle(theirs.editedAt);
        }
        await edits.setMet(name, account: accountId);
        continue;
      }
      final both = hereAt > 0 && !await edits.met(name, account: accountId)
          ? section.merge(here, theirs.data)
          : null;
      if (hereAt == 0) {
        // Nothing set up here: a new phone, or a group left as it came.
        if (await changedMeanwhile()) continue;
        await section.apply(theirs.data);
        await settle(theirs.editedAt);
        changed = true;
      } else if (both != null) {
        // This phone and the account meet for the first time, each with
        // its own: both are kept.
        if (await changedMeanwhile()) continue;
        final at = edits.nowMillis();
        if (!_same(both, here)) {
          await section.apply(both);
          changed = true;
        }
        await settle(at);
        if (!_same(both, theirs.data)) {
          await vault.save(SyncedSettings(id: id, editedAt: at, data: both));
        }
      } else if (theirs.editedAt > hereAt) {
        if (await changedMeanwhile()) continue;
        await section.apply(theirs.data);
        await settle(theirs.editedAt);
        changed = true;
      } else if (hereAt > theirs.editedAt) {
        await vault.save(SyncedSettings(id: id, editedAt: hereAt, data: here));
        await settle(hereAt);
      }
      // The same time and still different: the account's was taken before
      // and this phone keeps it its own way (a city it doesn't know). Not
      // sent back, so two phones can never push at each other for ever.
      await edits.setMet(name, account: accountId);
    }
    return changed;
  }
}
