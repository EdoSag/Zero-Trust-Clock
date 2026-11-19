import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_clock/engine/bedtime.dart';
import 'package:zerotrust_clock/ui/bedtime_page.dart';
import 'package:zerotrust_clock/ui/clock_home.dart';

import 'support/app.dart';
import 'support/fake_engine.dart';
import 'timers_test.dart' show frames, openTab, tallPhone;

const weekdays = {1, 2, 3, 4, 5};

Future<void> openBedtime(WidgetTester tester, FakeClockEngine engine) async {
  tallPhone(tester);
  await tester.pumpWidget(testApp(engine, home: const ClockHome()));
  await frames(tester);
  await openTab(tester, 'Bedtime');
  expect(find.byType(BedtimePage), findsOneWidget);
}

/// Types [hour]:[minute] into the open time picker, then OK.
Future<void> typeTime(WidgetTester tester, String hour, String minute) async {
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await frames(tester);
  final fields = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), hour);
  await tester.enterText(fields.at(1), minute);
  await tester.tap(find.text('OK'));
  await frames(tester);
}

void main() {
  group('the schedule', () {
    test('a night across midnight ends on the next mornings', () {
      const s = BedtimeSchedule(nights: weekdays);
      expect(s.length, const Duration(hours: 8));
      // Sunday to Thursday nights would be 7, 1..4; Monday to Friday
      // nights end Tuesday to Saturday.
      expect(s.wakeDays, {2, 3, 4, 5, 6});
      const sunday = BedtimeSchedule(nights: {7});
      expect(sunday.wakeDays, {1});
      // An afternoon nap ends the same day.
      const nap = BedtimeSchedule(
        bedHour: 13,
        wakeHour: 14,
        wakeMinute: 30,
        nights: {6},
      );
      expect(nap.length, const Duration(minutes: 90));
      expect(nap.wakeDays, {6});
    });

    test('keeps every field through JSON, as the engine reads it', () {
      const s = BedtimeSchedule(
        enabled: true,
        bedHour: 22,
        bedMinute: 45,
        wakeHour: 6,
        wakeMinute: 15,
        nights: {1, 3},
        reminderMinutes: 30,
        doNotDisturb: true,
        wakeAlarmId: 'a1',
      );
      final back = BedtimeSchedule.fromJson(s.toJson());
      expect(back.toJson(), s.toJson());
      expect(back.nights, {1, 3});
      expect(BedtimeSchedule.fromJson('{}').reminderMinutes, 15);
    });
  });

  testWidgets('bedtime and wake up side by side, the night under them', (
    tester,
  ) async {
    final engine = FakeClockEngine();
    await openBedtime(tester, engine);
    final bed = tester.getRect(find.byKey(const ValueKey('bedTime')));
    final wake = tester.getRect(find.byKey(const ValueKey('wakeTime')));
    final length = tester.getRect(find.byKey(const ValueKey('sleepLength')));
    expect(bed.right, lessThan(wake.left));
    expect(bed.top, wake.top);
    expect(length.top, greaterThanOrEqualTo(bed.bottom));
    expect(find.text('8 h of sleep'), findsOneWidget);
    expect(find.text('11:00 PM'), findsOneWidget);
    expect(find.text('7:00 AM'), findsWidgets);
  });

  testWidgets('a new wake-up time is saved and the night is shorter', (
    tester,
  ) async {
    final engine = FakeClockEngine();
    await openBedtime(tester, engine);
    await tester.tap(find.byKey(const ValueKey('wakeTime')));
    await frames(tester);
    await typeTime(tester, '6', '30');
    expect(engine.schedule.wakeHour, 6);
    expect(engine.schedule.wakeMinute, 30);
    expect(find.text('7 h 30 min of sleep'), findsOneWidget);
  });

  testWidgets('switching the schedule on saves it; the last night stays', (
    tester,
  ) async {
    final engine = FakeClockEngine()
      ..schedule = const BedtimeSchedule(nights: {3});
    await openBedtime(tester, engine);
    await tester.tap(find.byKey(const ValueKey('bedtimeOn')));
    await frames(tester);
    expect(engine.schedule.enabled, isTrue);

    final wed = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Wed'),
    );
    expect(wed.selected, isTrue);
    expect(wed.onSelected, isNull);
    await tester.tap(find.widgetWithText(FilterChip, 'Fri'));
    await frames(tester);
    expect(engine.schedule.nights, {3, 5});

    await tester.tap(find.widgetWithText(ChoiceChip, '30 min').first);
    await frames(tester);
    expect(engine.schedule.reminderMinutes, 30);
  });

  testWidgets('the wake-up alarm rings the mornings after, and follows', (
    tester,
  ) async {
    final engine = FakeClockEngine()
      ..schedule = const BedtimeSchedule(nights: weekdays);
    await openBedtime(tester, engine);
    await tester.tap(find.byKey(const ValueKey('wakeAlarm')));
    await frames(tester);
    // Monday to Friday nights: Tuesday to Saturday mornings.
    expect(engine.calls, contains('save new 7:0 [23456] "Wake up" true 10'));
    final id = engine.alarms.single.id;
    expect(engine.schedule.wakeAlarmId, id);
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('wakeAlarm')))
          .value,
      isTrue,
    );

    // A later wake-up moves the alarm too.
    await tester.tap(find.byKey(const ValueKey('wakeTime')));
    await frames(tester);
    await typeTime(tester, '8', '15');
    expect(engine.calls, contains('save $id 8:15 [23456] "Wake up" true 10'));
    expect(engine.alarms, hasLength(1));

    await tester.tap(find.byKey(const ValueKey('wakeAlarm')));
    await frames(tester);
    expect(engine.calls.last, 'setEnabled $id false');
    expect(engine.alarms, hasLength(1));
  });

  testWidgets('Do Not Disturb without access opens the setting and says so', (
    tester,
  ) async {
    final engine = FakeClockEngine()..hasDndAccess = false;
    await openBedtime(tester, engine);
    expect(find.byKey(const ValueKey('dndAccess')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('bedtimeDnd')));
    await frames(tester);
    expect(engine.schedule.doNotDisturb, isTrue);
    expect(engine.calls, contains('openSettings dndAccess'));
    final note = find.byKey(const ValueKey('dndAccess'));
    expect(note, findsOneWidget);
    // Under its switch.
    expect(
      tester.getRect(note).top,
      greaterThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('bedtimeDnd'))).bottom,
      ),
    );
  });

  testWidgets('sleep sounds play for the picked time, then Stop', (
    tester,
  ) async {
    final engine = FakeClockEngine();
    await openBedtime(tester, engine);
    await tester.scrollUntilVisible(
      find.text('Play'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(BedtimePage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await frames(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Deep noise'));
    await tester.tap(find.widgetWithText(ChoiceChip, '60 min').last);
    await frames(tester);
    await tester.tap(find.text('Play'));
    await frames(tester);
    expect(engine.calls, contains('playSleepSound brown 60'));
    expect(find.text('Play'), findsNothing);
    expect(find.textContaining('Plays until'), findsOneWidget);
    // The choices are locked while it plays.
    final white = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'White noise'),
    );
    expect(white.onSelected, isNull);

    await tester.tap(find.text('Stop'));
    await frames(tester);
    expect(engine.calls.last, 'stopSleepSound');
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('in Hebrew bedtime is on the right, wake up on the left', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    await tester.pumpWidget(
      testApp(engine, home: const BedtimePage(), locale: hebrew),
    );
    await frames(tester);
    expect(find.text('שינה'), findsWidgets);
    final bed = tester.getRect(find.byKey(const ValueKey('bedTime')));
    final wake = tester.getRect(find.byKey(const ValueKey('wakeTime')));
    expect(bed.left, greaterThan(wake.right));
  });
}
