import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_clock/engine/alarm.dart';
import 'package:zerotrust_clock/sync/alarm_sync.dart';

import 'support/fake_engine.dart';

/// The account's copy, shared by the phones of one test.
class FakeVault implements AlarmVault {
  final Map<String, VaultAlarm> items = {};
  final _changes = StreamController<void>.broadcast();
  int writes = 0;

  SyncedAlarm? live(String id) => items[id]?.alarm;

  @override
  Future<Map<String, VaultAlarm>> read() async => {...items};

  @override
  Future<void> save(SyncedAlarm alarm) async {
    writes++;
    items[alarm.id] = VaultAlarm.live(alarm);
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    writes++;
    items[id] = VaultAlarm.deleted(DateTime.fromMillisecondsSinceEpoch(5000));
    _changes.add(null);
  }

  @override
  Stream<void> get changes => _changes.stream;
}

/// One phone: its engine, its deletion record and its sync.
class Phone {
  Phone(this.device, this.vault)
    : engine = FakeClockEngine(),
      prefs = InMemoryPreferencesStore() {
    sync = AlarmSync(
      engine: engine,
      vault: vault,
      deleted: DeletedAlarms(prefs),
      device: device,
    );
  }

  final String device;
  final FakeVault vault;
  final FakeClockEngine engine;
  final InMemoryPreferencesStore prefs;
  late final AlarmSync sync;

  ClockAlarm? get(String id) =>
      engine.alarms.where((a) => a.id == id).firstOrNull;

  Future<void> deleteHere(String id) async {
    await DeletedAlarms(prefs).add(id);
    await engine.delete(id);
  }
}

SyncedAlarm synced(
  String id, {
  int hour = 7,
  int minute = 0,
  Set<int> days = const {1, 2, 3, 4, 5},
  Set<String> onDevices = const {},
  int editedAt = 100,
  String label = '',
}) => SyncedAlarm(
  id: id,
  hour: hour,
  minute: minute,
  days: days,
  label: label,
  onDevices: onDevices,
  editedAt: editedAt,
);

void main() {
  group('planAlarmSync', () {
    test(
      'an alarm only on this phone is sent, with this phone switched on',
      () {
        final plan = planAlarmSync(
          engine: [
            alarm('a', label: 'Gym', updatedAt: 50),
            alarm('b', enabled: false, updatedAt: 60),
          ],
          vault: {},
          deletedHere: {},
          device: 'A',
        );
        expect(plan.toVault.map((s) => s.id), ['a', 'b']);
        expect(plan.toVault[0].onDevices, {'A'});
        expect(plan.toVault[0].label, 'Gym');
        expect(plan.toVault[0].editedAt, 50);
        expect(plan.toVault[1].onDevices, isEmpty);
        expect(plan.toEngine, isEmpty);
      },
    );

    test('an alarm from the account arrives switched off on a new phone', () {
      final plan = planAlarmSync(
        engine: [],
        vault: {
          'a': VaultAlarm.live(synced('a', onDevices: {'A'})),
        },
        deletedHere: {},
        device: 'B',
      );
      expect(plan.toEngine.single.enabled, isFalse);
      expect(plan.toEngine.single.updatedAt, 100);
      expect(plan.added, {'a'});
      expect(plan.toVault, isEmpty);
    });

    test('an alarm switched on for this phone (a restore) comes back on', () {
      final plan = planAlarmSync(
        engine: [],
        vault: {
          'a': VaultAlarm.live(synced('a', onDevices: {'A', 'B'})),
        },
        deletedHere: {},
        device: 'B',
      );
      expect(plan.toEngine.single.enabled, isTrue);
    });

    test(
      'a newer edit elsewhere is taken; this phone keeps its own switch',
      () {
        final plan = planAlarmSync(
          engine: [alarm('a', hour: 7, updatedAt: 100)],
          vault: {
            'a': VaultAlarm.live(
              synced('a', hour: 8, onDevices: {'A', 'B'}, editedAt: 200),
            ),
          },
          deletedHere: {},
          device: 'B',
        );
        expect(plan.toEngine.single.hour, 8);
        expect(plan.toEngine.single.enabled, isTrue);
        expect(plan.toEngine.single.updatedAt, 200);
        expect(plan.added, isEmpty);
        expect(plan.toVault, isEmpty);
      },
    );

    test('a newer edit here is sent and keeps the other phones\' switches', () {
      final plan = planAlarmSync(
        engine: [alarm('a', hour: 9, enabled: false, updatedAt: 300)],
        vault: {
          'a': VaultAlarm.live(synced('a', onDevices: {'A', 'B'})),
        },
        deletedHere: {},
        device: 'B',
      );
      expect(plan.toVault.single.hour, 9);
      expect(plan.toVault.single.onDevices, {'A'});
      expect(plan.toVault.single.editedAt, 300);
      expect(plan.toEngine, isEmpty);
    });

    test('only this phone\'s switch moved: sent, the edit time stays', () {
      // A one-time alarm rang and went off: not an edit by hand.
      final plan = planAlarmSync(
        engine: [alarm('a', enabled: false, updatedAt: 100)],
        vault: {
          'a': VaultAlarm.live(synced('a', onDevices: {'A', 'B'})),
        },
        deletedHere: {},
        device: 'B',
      );
      expect(plan.toVault.single.onDevices, {'A'});
      expect(plan.toVault.single.editedAt, 100);
    });

    test('the same edit on both sides: nothing to do', () {
      final plan = planAlarmSync(
        engine: [alarm('a', updatedAt: 100)],
        vault: {
          'a': VaultAlarm.live(synced('a', onDevices: {'B'})),
        },
        deletedHere: {},
        device: 'B',
      );
      expect(plan.isEmpty, isTrue);
    });

    test('deleted here: the account deletes it too, then it is forgotten', () {
      final plan = planAlarmSync(
        engine: [],
        vault: {'a': VaultAlarm.live(synced('a'))},
        deletedHere: {'a', 'gone-long-ago'},
        device: 'B',
      );
      expect(plan.deleteFromVault, ['a']);
      expect(plan.toEngine, isEmpty);
      expect(plan.deletedHere, {'gone-long-ago'});
    });

    test('deleted elsewhere: deleted here, unless edited here after that', () {
      final deletedAt = DateTime.fromMillisecondsSinceEpoch(500);
      final plan = planAlarmSync(
        engine: [alarm('old', updatedAt: 400), alarm('edited', updatedAt: 600)],
        vault: {
          'old': VaultAlarm.deleted(deletedAt),
          'edited': VaultAlarm.deleted(deletedAt),
        },
        deletedHere: {},
        device: 'B',
      );
      expect(plan.deleteFromEngine, ['old']);
      expect(plan.toVault.single.id, 'edited');
    });

    test('an empty or lost account copy never empties the phone', () {
      final plan = planAlarmSync(
        engine: [alarm('a', updatedAt: 1), alarm('b', updatedAt: 2)],
        vault: {},
        deletedHere: {},
        device: 'B',
      );
      expect(plan.deleteFromEngine, isEmpty);
      expect(plan.toVault.map((s) => s.id), ['a', 'b']);
    });

    test('items from a newer app version are left alone', () {
      final plan = planAlarmSync(
        engine: [alarm('a', updatedAt: 999)],
        vault: {'a': const VaultAlarm.newer(), 'b': const VaultAlarm.newer()},
        deletedHere: {'b'},
        device: 'B',
      );
      expect(plan.isEmpty, isTrue);
      expect(plan.deletedHere, {'b'});
    });

    test('the copy in the account keeps what syncs, as JSON', () {
      final s = SyncedAlarm.fromEngine(
        alarm(
          'a',
          hour: 6,
          minute: 30,
          days: {5, 1},
          label: 'Run',
          skipDate: '2026-11-20',
          updatedAt: 42,
        ),
        device: 'A',
      );
      final back = SyncedAlarm.fromJson('a', s.toJson());
      expect(back, s);
      expect(s.toJson()['days'], [1, 5]);
      // Every field is written, null when empty (kept by older versions).
      expect(s.toJson().containsKey('date'), isTrue);
      expect(s.toJson()['date'], isNull);
    });
  });

  group('AlarmSync between two phones', () {
    test(
      'made on one phone, off on the other until switched on there',
      () async {
        final vault = FakeVault();
        final a = Phone('A', vault);
        final b = Phone('B', vault);
        await a.engine.save(hour: 6, minute: 45, days: {1, 3}, label: 'Gym');
        final id = a.engine.alarms.single.id;

        await a.sync.run();
        final result = await b.sync.run();
        expect(result.added, 1);
        expect(result.engineChanged, isTrue);
        expect(b.get(id)!.enabled, isFalse);
        expect(b.get(id)!.label, 'Gym');
        expect(a.get(id)!.enabled, isTrue);

        // Switched on at B: both on, nothing changes at A.
        await b.engine.setEnabled(id, true);
        await b.sync.run();
        await a.sync.run();
        expect(vault.live(id)!.onDevices, {'A', 'B'});
        expect(a.get(id)!.enabled, isTrue);

        // Time changed at A: B takes the time and stays on.
        await a.engine.save(id: id, hour: 7, minute: 15, days: {1, 3});
        await a.sync.run();
        await b.sync.run();
        expect(b.get(id)!.hour, 7);
        expect(b.get(id)!.minute, 15);
        expect(b.get(id)!.enabled, isTrue);

        // Switched off at B: A still rings.
        await b.engine.setEnabled(id, false);
        await b.sync.run();
        await a.sync.run();
        expect(a.get(id)!.enabled, isTrue);
        expect(vault.live(id)!.onDevices, {'A'});

        // Settled: another round writes nothing.
        final writes = vault.writes;
        await a.sync.run();
        await b.sync.run();
        expect(vault.writes, writes);
      },
    );

    test('deleted on one phone, gone from the other', () async {
      final vault = FakeVault();
      final a = Phone('A', vault);
      final b = Phone('B', vault);
      await a.engine.save(hour: 6, minute: 0);
      final id = a.engine.alarms.single.id;
      await a.sync.run();
      await b.sync.run();
      expect(b.get(id), isNotNull);

      await b.deleteHere(id);
      await b.sync.run();
      expect(vault.live(id), isNull);
      // Not brought back on the next round.
      await b.sync.run();
      expect(b.get(id), isNull);

      await a.sync.run();
      expect(a.get(id), isNull);
    });

    test('a ringing alarm is taken on the next round', () async {
      final vault = FakeVault();
      final b = Phone('B', vault);
      b.engine.alarms.add(alarm('a', hour: 7, updatedAt: 100));
      vault.items['a'] = VaultAlarm.live(
        synced('a', hour: 8, onDevices: {'B'}, editedAt: 200),
      );
      b.engine.ringingIds.add('a');
      await b.sync.run();
      expect(b.get('a')!.hour, 7);

      b.engine.ringingIds.clear();
      await b.sync.run();
      expect(b.get('a')!.hour, 8);
    });

    test('a call during a round runs one more round after it', () async {
      final vault = FakeVault();
      final a = Phone('A', vault);
      await a.engine.save(hour: 6, minute: 0);
      final first = a.sync.run();
      await a.engine.save(hour: 7, minute: 0);
      final second = a.sync.run();
      await Future.wait([first, second]);
      expect(vault.items.length, 2);
    });
  });
}
