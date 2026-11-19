import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// ZT Time's app id: its items are the time entries and projects.
const timeAppId = 'time';

/// The ZT Time key of the unlocked account, derived at unlock while the
/// account key is at hand, and zeroed when the vault locks. Clock only
/// reads Time's projects and adds entries ("Log to ZT Time").
final timeKeyProvider = NotifierProvider<TimeKey, Uint8List?>(TimeKey.new);

class TimeKey extends Notifier<Uint8List?> {
  // Kept here too: state can't be read while the provider is disposed.
  Uint8List? _key;

  /// Bumped by every derive, clear and dispose: a derive that finishes
  /// after the vault locked is dropped.
  int _generation = 0;

  @override
  Uint8List? build() {
    ref.listen(vaultControllerProvider, (_, VaultState next) {
      if (next is VaultLocked) clear();
    });
    ref.onDispose(() {
      _generation++;
      _zero();
    });
    return null;
  }

  Future<void> deriveFrom(Uint8List dek) async {
    final mine = ++_generation;
    final key = await KeyHierarchy.appKey(dek, timeAppId);
    if (mine != _generation) {
      key.fillRange(0, key.length, 0);
      return;
    }
    _zero();
    _key = key;
    state = key;
    // An entry logged offline earlier goes up now.
    unawaited(ref.read(timeLogProvider).flush().catchError((Object _) {}));
  }

  void clear() {
    _generation++;
    _zero();
    state = null;
  }

  void _zero() {
    final key = _key;
    key?.fillRange(0, key.length, 0);
    _key = null;
  }
}

/// A ZT Time project, as Clock needs it.
class TimeProject {
  const TimeProject(this.id, this.name, {this.client = ''});
  final String id;
  final String name;
  final String client;
}

/// What "Log to ZT Time" needs. Tests replace it.
abstract class TimeLog {
  /// Signed in and unlocked: Time's data can be reached.
  bool get available;

  /// The projects in ZT Time, not archived, by name.
  Future<List<TimeProject>> projects();

  /// Sends entries logged while offline, if any.
  Future<void> flush();

  /// Adds an entry to ZT Time, synced to the account.
  Future<void> log({
    required DateTime start,
    required DateTime end,
    required String description,
    String? projectId,
  });
}

final timeLogProvider = Provider<TimeLog>((ref) {
  ref.watch(timeKeyProvider);
  return VaultTimeLog(ref);
});

/// An entry as ZT Time writes it (its `TimeEntry.toJson`, version 1).
Map<String, Object?> timeEntryJson({
  required DateTime start,
  required DateTime end,
  required String description,
  required DateTime now,
  String? projectId,
}) => {
  'description': description,
  'projectId': projectId,
  'tags': <String>[],
  'start': start.toUtc().toIso8601String(),
  'end': end.toUtc().toIso8601String(),
  'billable': false,
  'createdAt': now.toUtc().toIso8601String(),
  ZtCollection.kindKey: 'entry',
  ZtCollection.versionKey: 1,
};

/// A new item id in ZT Time's format (a random UUID).
String newTimeItemId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Reaches ZT Time's encrypted items in the same account, keeping a small
/// copy of them on this phone (opened with the Time key) so an entry made
/// offline is pushed later.
class VaultTimeLog implements TimeLog {
  VaultTimeLog(this.ref);
  final Ref ref;

  @override
  bool get available => ref.read(timeKeyProvider) != null;

  Future<T> _withEngine<T>(
    Future<T> Function(ItemSyncEngine engine, ZtLocalStore store) run,
  ) async {
    final unlocked = ref.read(timeKeyProvider);
    if (unlocked == null) throw const VaultIsLocked();
    final key = Uint8List.fromList(unlocked);
    try {
      final userId = ref.read(accountServiceProvider).currentUserId;
      if (userId == null) throw StateError('Not signed in');
      final path = await ZtLocalStore.pathFor(
        appId: 'clock_time',
        userId: userId,
      );
      ZtLocalStore store;
      try {
        store = await ZtLocalStore.open(appKey: key, path: path);
      } on LocalStoreUnreadable {
        await ZtLocalStore.moveAside(path);
        store = await ZtLocalStore.open(appKey: key, path: path);
      }
      final engine = await ItemSyncEngine.fromVault(
        appId: timeAppId,
        appKey: key,
        deviceId: await ref.read(ztDeviceIdProvider.future),
        store: store,
        backend: ref.read(ztSyncBackendProvider),
      );
      try {
        return await run(engine, store);
      } finally {
        await engine.close();
        await store.close();
      }
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  /// Set while an entry is on this phone only (logged offline).
  static const pendingKey = 'clock_time_pending';

  PreferencesStore get _prefs => ref.read(ztPreferencesStoreProvider);

  /// True when the round reached the account.
  Future<bool> _sync(ItemSyncEngine engine) async {
    try {
      await engine.sync();
      return true;
    } on Object {
      // Offline: what is here is used, and pushed by [flush] later.
      return false;
    }
  }

  @override
  Future<void> flush() async {
    if (!available || (await _prefs.read(pendingKey)) != '1') return;
    final sent = await _withEngine((engine, _) => _sync(engine));
    if (sent) await _prefs.write(pendingKey, '');
  }

  @override
  Future<List<TimeProject>> projects() => _withEngine((engine, store) async {
    if (await _sync(engine)) await _prefs.write(pendingKey, '');
    final out = <TimeProject>[];
    for (final item in await store.all()) {
      final j = item.json;
      if (item.deleted || j == null) continue;
      if (j[ZtCollection.kindKey] != 'project') continue;
      if (ZtCollection.versionOf(j) > 1 || j['archived'] == true) continue;
      final name = (j['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      out.add(
        TimeProject(item.itemId, name, client: j['client'] as String? ?? ''),
      );
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  });

  @override
  Future<void> log({
    required DateTime start,
    required DateTime end,
    required String description,
    String? projectId,
  }) => _withEngine((engine, _) async {
    await engine.save(
      newTimeItemId(),
      timeEntryJson(
        start: start,
        end: end,
        description: description,
        projectId: projectId,
        now: DateTime.now(),
      ),
    );
    // Offline: kept here and sent at the next unlock (or the next log).
    await _prefs.write(pendingKey, await _sync(engine) ? '' : '1');
  });
}
