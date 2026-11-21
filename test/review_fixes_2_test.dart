import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_clock/engine/alarm.dart';
import 'package:zerotrust_clock/engine/bedtime.dart';
import 'package:zerotrust_clock/engine/clock_engine.dart';
import 'package:zerotrust_clock/sync/settings_sync.dart';

import 'bedtime_test.dart' show openBedtime, typeTime, weekdays;
import 'settings_sync_test.dart' show FakeSettingsVault, Phone, WordsPhone;
import 'support/fake_engine.dart';
import 'timers_test.dart' show frames;

const code = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

/// Preferences that take a moment, like the phone's own: two changes
/// under way at once can read the same old value.
class SlowPrefs implements PreferencesStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    values[key] = value;
  }
}

void main() {
  group('settings backup', () {
    test('changed and changed back later: the later time is sent, and an '
        'older change elsewhere does not win', () async {
      final vault = FakeSettingsVault()
        ..put('words', 100, {
          'words': ['x'],
        });
      final here = WordsPhone(vault);
      final other = WordsPhone(vault);
      await here.sync.run();
      await other.sync.run();
      // The other phone changes to y at 200, offline. This one goes to z
      // and back to x, last at 300.
      await other.edit(['y'], 200);
      await here.edit(['x'], 300);

      await here.sync.run();
      expect(vault.items['words']!.editedAt, 300);
      expect(vault.items['words']!.data, {
        'words': ['x'],
      });
      await other.sync.run();
      expect(other.section.words, ['x']);
      await here.sync.run();
      expect(here.section.words, ['x']);
      // Settled: nothing more to send either way.
      final writes = vault.writes;
      await here.sync.run();
      await other.sync.run();
      expect(vault.writes, writes);
    });

    test('a change made while a save is under way keeps its time and is '
        'sent by the next round', () async {
      final vault = FakeSettingsVault();
      final phone = WordsPhone(vault);
      await phone.edit(['a'], 100);
      vault.duringSave = () => phone.edit(['a', 'b'], 200);
      await phone.sync.run();
      // The round sent what it had read; the newer time was not undone.
      expect(vault.items['words']!.data, {
        'words': ['a'],
      });
      expect(await phone.edits.editedAt('words'), 200);

      await phone.sync.run();
      expect(vault.items['words']!.editedAt, 200);
      expect(vault.items['words']!.data, {
        'words': ['a', 'b'],
      });
    });

    test('the same while a group\'s first copy goes up', () async {
      // First upload of a group set up before times were kept (time 1).
      final vault = FakeSettingsVault();
      final phone = WordsPhone(vault)..section.words = ['a'];
      vault.duringSave = () => phone.edit(['a', 'b'], 500);
      await phone.sync.run();
      expect(await phone.edits.editedAt('words'), 500);
      await phone.sync.run();
      expect(vault.items['words']!.data, {
        'words': ['a', 'b'],
      });
    });

    test(
      'two groups changed at the same moment both keep their time',
      () async {
        final edits = SettingsEdits(SlowPrefs());
        await Future.wait([
          edits.setEditedAt('cities', 100),
          edits.setEditedAt('ring', 200),
          edits.setEditedAtIf('home', was: 0, at: 300),
        ]);
        expect(await edits.editedAt('cities'), 100);
        expect(await edits.editedAt('ring'), 200);
        expect(await edits.editedAt('home'), 300);
        // Only when it is still what the round read.
        expect(await edits.setEditedAtIf('ring', was: 100, at: 50), isFalse);
        expect(await edits.editedAt('ring'), 200);
        expect(await edits.setEditedAtIf('ring', was: 200, at: 250), isTrue);
        expect(await edits.editedAt('ring'), 250);
      },
    );

    test('another account on the same phone meets it for the first time '
        'too: both lists are kept', () async {
      final prefs = InMemoryPreferencesStore();
      final first = FakeSettingsVault()
        ..put('words', 100, {
          'words': ['one'],
        });
      final phone = WordsPhone(
        first,
        merges: true,
        store: prefs,
        accountId: 'first',
      );
      await phone.edit(['mine'], 50);
      await phone.sync.run();
      expect(phone.section.words, ['mine', 'one']);

      // Signed in to another account, whose list is newer.
      final second = FakeSettingsVault()
        ..put('words', 99999, {
          'words': ['two'],
        });
      final again = WordsPhone(
        second,
        merges: true,
        store: prefs,
        accountId: 'second',
      )..section.words = ['mine', 'one'];
      await again.sync.run();
      expect(again.section.words, ['mine', 'one', 'two']);
      expect(await again.edits.met('words', account: 'first'), isTrue);
      expect(await again.edits.met('words', account: 'second'), isTrue);
      expect(await again.edits.met('words', account: 'third'), isFalse);
    });

    test('what was compared before the update counts for the account '
        'signed in now', () async {
      final prefs = InMemoryPreferencesStore();
      await prefs.write('clock_settings_met', jsonEncode(['words']));
      final edits = SettingsEdits(prefs);
      expect(await edits.met('words', account: 'me'), isTrue);
      expect(await edits.met('cities', account: 'me'), isFalse);
      await edits.setMet('cities', account: 'me');
      // Written the new way, with the old ones kept; another account
      // starts over.
      expect(await edits.met('words', account: 'me'), isTrue);
      expect(await edits.met('cities', account: 'me'), isTrue);
      expect(await edits.met('words', account: 'other'), isFalse);
    });
  });

  group('bedtime', () {
    testWidgets('a new wake-up time keeps the alarm\'s scan task and code', (
      tester,
    ) async {
      final engine = FakeClockEngine(
        alarms: [
          alarm(
            'w',
            days: {2, 3, 4, 5, 6},
            task: WakeTask.scan,
            taskCode: code,
            label: 'Wake up',
          ),
        ],
      )..schedule = const BedtimeSchedule(nights: weekdays, wakeAlarmId: 'w');
      await openBedtime(tester, engine);
      await tester.tap(find.byKey(const ValueKey('wakeTime')));
      await frames(tester);
      await typeTime(tester, '8', '15');
      expect(engine.calls, contains('save w 8:15 [23456] "Wake up" true 10'));
      expect(engine.lastSave['task'], 'scan');
      expect(engine.lastSave['taskCode'], code);
      expect(engine.alarms.single.task, WakeTask.scan);
      expect(engine.alarms.single.taskCode, code);
    });

    test('the account\'s schedule arrives: this phone\'s own wake-up alarm '
        'stays the one Bedtime controls, moved to the new time', () async {
      final vault = FakeSettingsVault();
      final a = Phone(vault);
      final b = Phone(vault);
      // Each phone made its own wake-up alarm before the backup existed.
      b.engine.alarms.add(
        alarm(
          'mine',
          days: {2, 3, 4, 5, 6},
          task: WakeTask.scan,
          taskCode: code,
        ),
      );
      b.engine.schedule = const BedtimeSchedule(
        nights: weekdays,
        wakeAlarmId: 'mine',
      );
      await a.container.read(bedtimeProvider.future);
      await a.container
          .read(bedtimeProvider.notifier)
          .save(
            const BedtimeSchedule(
              wakeHour: 6,
              wakeMinute: 30,
              nights: {7, 1, 2, 3, 4},
              wakeAlarmId: 'theirs',
            ),
          );
      await a.sync();
      await b.sync();

      final s = b.engine.schedule;
      expect([s.wakeHour, s.wakeMinute], [6, 30]);
      expect(s.nights, {7, 1, 2, 3, 4});
      expect(s.wakeAlarmId, 'mine');
      // Sunday to Thursday nights: Monday to Friday mornings.
      expect(b.engine.calls, contains('save mine 6:30 [12345] "" true 10'));
      final mine = b.engine.alarms.single;
      expect([mine.hour, mine.minute, mine.enabled], [6, 30, true]);
      expect(mine.taskCode, code);
      // Keeping its own alarm is not a change to send back.
      final writes = vault.writes;
      await b.sync();
      await a.sync();
      expect(vault.writes, writes);
      expect(a.engine.schedule.wakeAlarmId, 'theirs');
    });

    test('with its own wake-up alarm switched off, or none, the account\'s '
        'is taken', () async {
      final vault = FakeSettingsVault();
      final a = Phone(vault);
      final b = Phone(vault);
      b.engine.alarms.add(alarm('mine', days: {2}, enabled: false));
      b.engine.schedule = const BedtimeSchedule(wakeAlarmId: 'mine');
      await a.container.read(bedtimeProvider.future);
      await a.container
          .read(bedtimeProvider.notifier)
          .save(const BedtimeSchedule(wakeHour: 6, wakeAlarmId: 'theirs'));
      await a.sync();
      await b.sync();
      expect(b.engine.schedule.wakeAlarmId, 'theirs');
      expect(b.engine.calls.where((c) => c.startsWith('save ')), isEmpty);
    });
  });
}
