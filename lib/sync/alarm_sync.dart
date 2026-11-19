import 'dart:async';
import 'dart:convert';

import 'package:zero_trust_core/zero_trust_core.dart';

import '../engine/alarm.dart';
import '../engine/clock_engine.dart';

/// An alarm as the account keeps it: an end-to-end encrypted item of the
/// Clock app (`app = 'clock'`, `kind = 'alarm'`), no database change.
///
/// The alarms on the phone stay in the engine, which rings them without
/// the account; this is the copy that backs them up and moves them between
/// phones. Each phone has its own switch: [onDevices] lists the phones the
/// alarm is switched on for, so an alarm made on one phone arrives switched
/// off on the others (Edo's choice, 2026-11-18).
class SyncedAlarm {
  const SyncedAlarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.days = const {},
    this.date,
    this.skipDate,
    this.label = '',
    this.vibrate = true,
    this.snoozeMinutes = 10,
    this.onDevices = const {},
    this.editedAt = 0,
  });

  final String id;
  final int hour;
  final int minute;
  final Set<int> days;
  final String? date;
  final String? skipDate;
  final String label;
  final bool vibrate;
  final int snoozeMinutes;

  /// Install ids of the phones this alarm is switched on for.
  final Set<String> onDevices;

  /// The engine's `updatedAt` of the edit this copy holds.
  final int editedAt;

  factory SyncedAlarm.fromJson(String id, Map<String, Object?> j) =>
      SyncedAlarm(
        id: id,
        hour: ((j['hour'] as num?)?.toInt() ?? 0).clamp(0, 23),
        minute: ((j['minute'] as num?)?.toInt() ?? 0).clamp(0, 59),
        days: {
          for (final d in (j['days'] as List? ?? const []))
            if (d is num && d >= 1 && d <= 7) d.toInt(),
        },
        date: j['date'] as String?,
        skipDate: j['skipDate'] as String?,
        label: j['label'] as String? ?? '',
        vibrate: j['vibrate'] as bool? ?? true,
        snoozeMinutes: ((j['snoozeMinutes'] as num?)?.toInt() ?? 10).clamp(
          1,
          60,
        ),
        onDevices: {
          for (final d in (j['onDevices'] as List? ?? const []))
            if (d is String) d,
        },
        editedAt: (j['editedAt'] as num?)?.toInt() ?? 0,
      );

  /// Every field, null for a cleared one (see [ZtCollection]).
  Map<String, Object?> toJson() => {
    'hour': hour,
    'minute': minute,
    'days': days.toList()..sort(),
    'date': date,
    'skipDate': skipDate,
    'label': label,
    'vibrate': vibrate,
    'snoozeMinutes': snoozeMinutes,
    'onDevices': onDevices.toList()..sort(),
    'editedAt': editedAt,
  };

  /// The alarm on this phone, as the copy from the account says it.
  factory SyncedAlarm.fromEngine(
    ClockAlarm a, {
    required String device,
    Set<String> onDevices = const {},
    int? editedAt,
  }) => SyncedAlarm(
    id: a.id,
    hour: a.hour,
    minute: a.minute,
    days: a.days,
    date: a.repeats ? null : a.date,
    skipDate: a.skipDate,
    label: a.label,
    vibrate: a.vibrate,
    snoozeMinutes: a.snoozeMinutes,
    onDevices: {...onDevices.where((d) => d != device), if (a.enabled) device},
    editedAt: editedAt ?? a.updatedAt,
  );

  /// What the engine on [device] is given: on only if switched on there.
  ClockAlarm toEngine(String device) => ClockAlarm(
    id: id,
    hour: hour,
    minute: minute,
    days: days,
    enabled: onDevices.contains(device),
    label: label,
    vibrate: vibrate,
    snoozeMinutes: snoozeMinutes,
    date: days.isEmpty ? date : null,
    skipDate: skipDate,
    updatedAt: editedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is SyncedAlarm &&
      other.id == id &&
      jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => Object.hash(id, jsonEncode(toJson()));
}

final syncedAlarms = ZtCollection<SyncedAlarm>(
  kind: 'alarm',
  fromJson: (id, json, _) => SyncedAlarm.fromJson(id, json),
  toJson: (a) => a.toJson(),
  idOf: (a) => a.id,
);

/// One item of the account's copy, as sync needs to see it.
class VaultAlarm {
  const VaultAlarm.live(SyncedAlarm this.alarm)
    : deletedAt = null,
      newer = false;
  const VaultAlarm.deleted(DateTime this.deletedAt)
    : alarm = null,
      newer = false;

  /// Written by a newer app version: left alone.
  const VaultAlarm.newer() : alarm = null, deletedAt = null, newer = true;

  final SyncedAlarm? alarm;
  final DateTime? deletedAt;
  final bool newer;
}

/// What one sync round changes, worked out by [planAlarmSync].
class AlarmSyncPlan {
  const AlarmSyncPlan({
    this.toVault = const [],
    this.deleteFromVault = const [],
    this.toEngine = const [],
    this.deleteFromEngine = const [],
    this.deletedHere = const {},
    this.added = const {},
  });

  final List<SyncedAlarm> toVault;
  final List<String> deleteFromVault;
  final List<ClockAlarm> toEngine;
  final List<String> deleteFromEngine;

  /// Alarms deleted on this phone that the account still has to be told
  /// about (kept for the next round).
  final Set<String> deletedHere;

  /// Ids of alarms that are new on this phone (from another phone, or
  /// restored).
  final Set<String> added;

  bool get isEmpty =>
      toVault.isEmpty &&
      deleteFromVault.isEmpty &&
      toEngine.isEmpty &&
      deleteFromEngine.isEmpty;
}

/// Compares the alarms on this phone with the account's copy.
///
/// - The newer edit wins, by [ClockAlarm.updatedAt] and
///   [SyncedAlarm.editedAt]. Ringing, snoozing and a skip running out are
///   not edits and are not sent.
/// - This phone's switch is its own: switching on or off here only changes
///   whether [device] is in [SyncedAlarm.onDevices].
/// - An alarm the account doesn't have is sent, one this phone doesn't have
///   is added (switched off unless switched on for this phone), unless it
///   was deleted here ([deletedHere]): then the account deletes it too.
/// - An alarm deleted elsewhere goes here too, unless it was edited here
///   after that. Nothing on the phone is deleted without that record, so a
///   lost or new account copy can never empty the phone.
AlarmSyncPlan planAlarmSync({
  required List<ClockAlarm> engine,
  required Map<String, VaultAlarm> vault,
  required Set<String> deletedHere,
  required String device,
}) {
  final toVault = <SyncedAlarm>[];
  final deleteFromVault = <String>[];
  final toEngine = <ClockAlarm>[];
  final deleteFromEngine = <String>[];
  final stillDeleted = {...deletedHere};
  final added = <String>{};

  final onPhone = {for (final a in engine) a.id: a};
  for (final e in engine) {
    stillDeleted.remove(e.id);
    final v = vault[e.id];
    if (v == null) {
      toVault.add(SyncedAlarm.fromEngine(e, device: device));
    } else if (v.newer) {
      continue;
    } else if (v.alarm case final SyncedAlarm s) {
      if (s.editedAt > e.updatedAt) {
        toEngine.add(s.toEngine(device));
      } else if (e.updatedAt > s.editedAt) {
        toVault.add(
          SyncedAlarm.fromEngine(e, device: device, onDevices: s.onDevices),
        );
      } else if (s.onDevices.contains(device) != e.enabled) {
        // Only this phone's switch moved (an alarm that rang once went
        // off): no edit, so the time of the last edit stays.
        toVault.add(
          SyncedAlarm.fromEngine(
            e,
            device: device,
            onDevices: s.onDevices,
            editedAt: s.editedAt,
          ),
        );
      }
    } else if (v.deletedAt case final DateTime gone) {
      if (e.updatedAt > gone.millisecondsSinceEpoch) {
        toVault.add(SyncedAlarm.fromEngine(e, device: device));
      } else {
        deleteFromEngine.add(e.id);
      }
    }
  }

  for (final MapEntry(key: id, value: v) in vault.entries) {
    if (onPhone.containsKey(id)) continue;
    final s = v.alarm;
    if (s == null) {
      if (!v.newer) stillDeleted.remove(id);
      continue;
    }
    if (stillDeleted.remove(id)) {
      deleteFromVault.add(id);
    } else {
      toEngine.add(s.toEngine(device));
      added.add(id);
    }
  }

  return AlarmSyncPlan(
    toVault: toVault,
    deleteFromVault: deleteFromVault,
    toEngine: toEngine,
    deleteFromEngine: deleteFromEngine,
    deletedHere: stillDeleted,
    added: added,
  );
}

/// The account's copy of the alarms.
abstract interface class AlarmVault {
  Future<Map<String, VaultAlarm>> read();
  Future<void> save(SyncedAlarm alarm);
  Future<void> delete(String id);

  /// Fires when the copy changed (another phone's change arrived).
  Stream<void> get changes;
}

/// [AlarmVault] on the shared encrypted store and sync of Zero-Trust-Core.
class StoreAlarmVault implements AlarmVault {
  StoreAlarmVault(this._store, this._sync);

  final LocalItemStore _store;
  final SyncController _sync;

  @override
  Future<Map<String, VaultAlarm>> read() async {
    final out = <String, VaultAlarm>{};
    for (final item in await _store.all()) {
      if (item.deleted) {
        out[item.itemId] = VaultAlarm.deleted(item.updatedAt);
        continue;
      }
      if (!syncedAlarms.owns(item.json)) continue;
      if (ZtCollection.versionOf(item.json!) > syncedAlarms.version) {
        out[item.itemId] = const VaultAlarm.newer();
        continue;
      }
      if (syncedAlarms.decode(item) case final SyncedAlarm a) {
        out[item.itemId] = VaultAlarm.live(a);
      }
    }
    return out;
  }

  @override
  Future<void> save(SyncedAlarm alarm) =>
      syncedAlarms.save(_sync, _store, alarm);

  @override
  Future<void> delete(String id) => syncedAlarms.delete(_sync, id);

  @override
  Stream<void> get changes => switch (_store) {
    final ZtLocalStore s => s.changes.map((_) {}),
    _ => const Stream.empty(),
  };
}

/// Alarms deleted on this phone, kept until the account has been told
/// (also across a sign-out, so a deletion made without an account still
/// reaches it). At most [limit] are kept.
class DeletedAlarms {
  DeletedAlarms(this._prefs);

  final PreferencesStore _prefs;
  static const _key = 'clock_deleted_alarms';
  static const limit = 200;

  Future<Set<String>> read() async {
    try {
      final raw = await _prefs.read(_key);
      if (raw == null) return {};
      return {
        for (final id in jsonDecode(raw) as List)
          if (id is String) id,
      };
    } on Object {
      return {};
    }
  }

  Future<void> write(Set<String> ids) async {
    final kept = ids.length > limit ? ids.skip(ids.length - limit) : ids;
    await _prefs.write(_key, jsonEncode(kept.toList()));
  }

  Future<void> add(String id) async => write({...await read(), id});
}

/// What [AlarmSync.run] did to this phone.
class AlarmSyncResult {
  const AlarmSyncResult({this.added = 0, this.engineChanged = false});

  /// Alarms new on this phone.
  final int added;

  /// Something on this phone changed (the list should be read again).
  final bool engineChanged;
}

/// Runs sync rounds between the engine and the account's copy, one at a
/// time: a call during a round runs one more round after it.
class AlarmSync {
  AlarmSync({
    required this.engine,
    required this.vault,
    required this.deleted,
    required this.device,
  });

  final ClockEngine engine;
  final AlarmVault vault;
  final DeletedAlarms deleted;
  final String device;

  Future<AlarmSyncResult>? _running;
  bool _again = false;

  /// One round (or joins the running one and repeats it).
  Future<AlarmSyncResult> run() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    final round = _loop();
    _running = round;
    return round.whenComplete(() => _running = null);
  }

  Future<AlarmSyncResult> _loop() async {
    var added = 0;
    var changed = false;
    do {
      _again = false;
      final r = await _round();
      added += r.added;
      changed = changed || r.engineChanged;
    } while (_again);
    return AlarmSyncResult(added: added, engineChanged: changed);
  }

  Future<AlarmSyncResult> _round() async {
    final plan = planAlarmSync(
      engine: await engine.list(),
      vault: await vault.read(),
      deletedHere: await deleted.read(),
      device: device,
    );
    for (final a in plan.toVault) {
      await vault.save(a);
    }
    for (final id in plan.deleteFromVault) {
      await vault.delete(id);
    }
    var added = 0;
    for (final a in plan.toEngine) {
      // False while it rings; the next round takes it.
      if (await engine.importSynced(a) && plan.added.contains(a.id)) added++;
    }
    for (final id in plan.deleteFromEngine) {
      await engine.delete(id);
    }
    await deleted.write(plan.deletedHere);
    return AlarmSyncResult(
      added: added,
      engineChanged:
          plan.toEngine.isNotEmpty || plan.deleteFromEngine.isNotEmpty,
    );
  }
}
