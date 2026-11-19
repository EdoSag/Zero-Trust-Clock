import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_clock/engine/bedtime.dart';
import 'package:zerotrust_clock/holidays/holiday_feed.dart';
import 'package:zerotrust_clock/holidays/holidays.dart';
import 'package:zerotrust_clock/sync/alarm_sync.dart';
import 'package:zerotrust_clock/ui/alarm_card.dart';
import 'package:zerotrust_clock/ui/bedtime_page.dart';
import 'package:zerotrust_clock/ui/holidays_page.dart';

import 'alarm_options_test.dart' show inDays, scrollTo;
import 'alarm_sync_test.dart' show FakeVault, Phone, synced;
import 'bedtime_test.dart' show openBedtime, weekdays;
import 'holidays_test.dart' show feed;
import 'support/app.dart';
import 'support/fake_engine.dart';
import 'timers_test.dart' show frames, tallPhone;

/// A vault whose writes wait until [release], so a test can act while a
/// sync round is under way.
class SlowVault extends FakeVault {
  Completer<void>? gate;

  @override
  Future<void> save(SyncedAlarm alarm) async {
    final g = gate;
    if (g != null) await g.future;
    return super.save(alarm);
  }
}

void main() {
  group('sync', () {
    test('a newer edit elsewhere keeps the switch set here offline', () {
      // Switched off here (offline) at 150; the other phone edited the
      // label at 200 before it heard of that.
      final plan = planAlarmSync(
        engine: [alarm('a', enabled: false, updatedAt: 150)],
        vault: {
          'a': VaultAlarm.live(
            synced('a', label: 'Gym', onDevices: {'A', 'B'}, editedAt: 200),
          ),
        },
        deletedHere: {},
        device: 'B',
      );
      expect(plan.toEngine.single.label, 'Gym');
      expect(plan.toEngine.single.enabled, isFalse);
    });

    test('then the account learns this phone\'s switch', () async {
      final vault = FakeVault();
      final b = Phone('B', vault);
      b.engine.alarms.add(alarm('a', enabled: false, updatedAt: 150));
      vault.items['a'] = VaultAlarm.live(
        synced('a', label: 'Gym', onDevices: {'A', 'B'}, editedAt: 200),
      );
      await b.sync.run();
      await b.sync.run();
      expect(b.get('a')!.enabled, isFalse);
      expect(b.get('a')!.label, 'Gym');
      expect(vault.live('a')!.onDevices, {'A'});
      expect(vault.live('a')!.label, 'Gym');
    });

    test('an edit here during a round is not undone by it', () async {
      final vault = FakeVault();
      final b = Phone('B', vault);
      b.engine.alarms.add(alarm('a', updatedAt: 100));
      vault.items['a'] = VaultAlarm.live(
        synced('a', hour: 8, onDevices: {'B'}, editedAt: 200),
      );
      // Edited here (at 300) after the round read the list.
      b.engine.alarms[0] = alarm('a', hour: 9, updatedAt: 300);
      expect(
        await b.engine.importSynced(vault.live('a')!.toEngine('B')),
        isFalse,
      );
      await b.sync.run();
      expect(b.get('a')!.hour, 9);
      expect(vault.live('a')!.hour, 9);
    });

    test('a delete during a round is kept and reaches the account', () async {
      final vault = SlowVault();
      final b = Phone('B', vault);
      b.engine.alarms.add(alarm('a', updatedAt: 100));
      b.engine.alarms.add(alarm('b', updatedAt: 100));
      vault.gate = Completer<void>();
      final round = b.sync.run();
      await Future<void>.delayed(Duration.zero);
      // The round is writing; the user deletes 'b' now.
      await b.deleteHere('b');
      vault.gate!.complete();
      vault.gate = null;
      await round;
      expect(await DeletedAlarms(b.prefs).read(), contains('b'));
      await b.sync.run();
      expect(vault.items['b']!.deletedAt, isNotNull);
      expect(b.get('b'), isNull);
      expect(await DeletedAlarms(b.prefs).read(), isEmpty);
    });
  });

  testWidgets('editor: a label change keeps a one-time alarm\'s day', (
    tester,
  ) async {
    // Snoozed: the day's time has passed, the day is still the one set.
    final engine = FakeClockEngine(
      alarms: [alarm('a', hour: 0, minute: 0, date: inDays(0))],
    );
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AlarmCard));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Pills');
    final save = find.widgetWithText(FilledButton, 'Save');
    await scrollTo(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(engine.lastSave['date'], inDays(0));
  });

  group('bedtime', () {
    testWidgets('the wake-up alarm switched off, then on again, rings', (
      tester,
    ) async {
      final engine = FakeClockEngine()
        ..schedule = const BedtimeSchedule(nights: weekdays);
      await openBedtime(tester, engine);
      final wake = find.byKey(const ValueKey('wakeAlarm'));
      await tester.tap(wake);
      await frames(tester);
      final id = engine.alarms.single.id;
      await tester.tap(wake);
      await frames(tester);
      expect(engine.alarms.single.enabled, isFalse);
      await tester.tap(wake);
      await frames(tester);
      expect(engine.calls, contains('setEnabled $id true'));
      expect(engine.alarms.single.enabled, isTrue);
      expect(tester.widget<SwitchListTile>(wake).value, isTrue);
    });

    testWidgets('moving the schedule keeps Skip public holidays', (
      tester,
    ) async {
      final engine = FakeClockEngine(
        alarms: [
          alarm('w', days: {2, 3, 4, 5, 6}, skipHolidays: true),
        ],
      )..schedule = const BedtimeSchedule(nights: weekdays, wakeAlarmId: 'w');
      await openBedtime(tester, engine);
      await tester.tap(find.widgetWithText(FilterChip, 'Sun'));
      await frames(tester);
      expect(engine.lastSave['skipHolidays'], isTrue);
      expect(engine.alarms.single.days, {1, 2, 3, 4, 5, 6});
    });

    testWidgets('switching on a schedule with a reminder asks to notify', (
      tester,
    ) async {
      final engine = FakeClockEngine();
      await openBedtime(tester, engine);
      await tester.tap(find.byKey(const ValueKey('bedtimeOn')));
      await frames(tester);
      expect(engine.calls, contains('requestNotifications'));
    });

    testWidgets('back from the access screen, Do Not Disturb is applied', (
      tester,
    ) async {
      final engine = FakeClockEngine()
        ..hasDndAccess = false
        ..schedule = const BedtimeSchedule(enabled: true, doNotDisturb: true);
      await openBedtime(tester, engine);
      final saves = engine.calls
          .where((c) => c.startsWith('setBedtime'))
          .length;
      engine.hasDndAccess = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await frames(tester);
      expect(
        engine.calls.where((c) => c.startsWith('setBedtime')).length,
        greaterThan(saves),
      );
      expect(find.byType(BedtimePage), findsOneWidget);
    });
  });

  testWidgets('a calendar picked during a download wins over it', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    final slow = Completer<String>();
    await tester.pumpWidget(
      testApp(
        engine,
        home: const HolidaysPage(),
        overrides: [
          holidayFetcherProvider.overrideWithValue((url) {
            // The first (Israel) is slow; then None is picked.
            return slow.future;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('holidayCalendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Israel (Jewish holidays)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('holidayCalendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();
    slow.complete(feed());
    await tester.pumpAndSettle();
    expect(engine.holidayDays, isEmpty);
    expect(find.text('Rosh Hashana'), findsNothing);
    expect(dayString(DateTime(2027)), '2027-01-01');
  });
}
