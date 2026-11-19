import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_clock/engine/clock_timer.dart';
import 'package:zerotrust_clock/ui/alarms_page.dart';
import 'package:zerotrust_clock/ui/clock_home.dart';
import 'package:zerotrust_clock/ui/duration_text.dart';
import 'package:zerotrust_clock/ui/stopwatch_page.dart';
import 'package:zerotrust_clock/ui/timer_keypad.dart';
import 'package:zerotrust_clock/ui/timers_page.dart';

import 'support/app.dart';
import 'support/fake_engine.dart';

/// A tall phone, so the keypad and its Start button fit.
void tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

/// A few frames; the countdowns tick, so the screen never "settles".
Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await frames(tester);
}

void main() {
  group('lengths', () {
    test('typed digits fill seconds, then minutes, then hours', () {
      expect(keypadDuration(''), Duration.zero);
      expect(keypadDuration('5'), const Duration(seconds: 5));
      expect(keypadDuration('130'), const Duration(minutes: 1, seconds: 30));
      expect(keypadDuration('10000'), const Duration(hours: 1));
      // 90 seconds count on into the next minute.
      expect(keypadDuration('90'), const Duration(seconds: 90));
      expect(keypadDuration('999999'), maxTimer);
    });

    test('countdowns round up; the stopwatch shows hundredths', () {
      expect(countdownText(const Duration(minutes: 5)), '5:00');
      expect(
        countdownText(const Duration(seconds: 299, milliseconds: 1)),
        '5:00',
      );
      expect(countdownText(const Duration(hours: 1, seconds: 3)), '1:00:03');
      expect(countdownText(const Duration(seconds: -12)), '-0:12');
      expect(stopwatchText(const Duration(milliseconds: 83456)), '1:23.45');
      expect(
        stopwatchText(const Duration(hours: 2, milliseconds: 5)),
        '2:00:00.00',
      );
    });
  });

  testWidgets('the tabs are at the bottom; Timers opens on the keypad', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    await tester.pumpWidget(testApp(engine, home: const ClockHome()));
    await frames(tester);
    expect(find.byType(AlarmsPage), findsOneWidget);
    final bar = tester.getRect(find.byType(NavigationBar));
    final screen = tester.getRect(find.byType(ClockHome));
    expect(bar.bottom, screen.bottom);
    // Alarms, Clock, Timers, Stopwatch, in that order across the bar.
    final xs = [
      for (final label in ['Alarms', 'Clock', 'Timers', 'Stopwatch'])
        tester
            .getCenter(
              find.descendant(
                of: find.byType(NavigationBar),
                matching: find.text(label),
              ),
            )
            .dx,
    ];
    expect(xs[0], lessThan(xs[1]));
    expect(xs[1], lessThan(xs[2]));
    expect(xs[2], lessThan(xs[3]));

    await openTab(tester, 'Timers');
    expect(find.byType(TimerKeypad), findsOneWidget);
    // Quick timers above the typed time, the keys below, Start last.
    final quick = tester.getRect(find.byKey(const ValueKey('quickTimers')));
    final display = tester.getRect(find.byKey(const ValueKey('keypadDisplay')));
    final one = tester.getRect(find.text('1'));
    final start = tester.getRect(find.widgetWithText(FilledButton, 'Start'));
    expect(quick.bottom, lessThan(display.top));
    expect(display.bottom, lessThan(one.top));
    expect(one.bottom, lessThan(start.top));
    expect(start.bottom, lessThanOrEqualTo(bar.top));
    // Nothing typed: nothing to start.
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('typing 1 3 0 and Start runs a 1:30 timer with its buttons', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    await tester.pumpWidget(testApp(engine, home: const TimersPage()));
    await frames(tester);
    for (final key in ['1', '3', '0']) {
      await tester.tap(find.text(key).last);
      await tester.pump();
    }
    expect(find.text('01'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    // Hours, minutes, seconds, left to right.
    expect(
      tester.getCenter(find.text('01')).dx,
      lessThan(tester.getCenter(find.text('30')).dx),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await frames(tester);
    expect(engine.calls, contains('addTimer 90s'));

    final card = find.byType(TimerCard);
    expect(card, findsOneWidget);
    expect(find.text('1:30 timer'), findsOneWidget);
    final left = find.byKey(const ValueKey('left-timer-1'));
    expect(tester.widget<Text>(left).data, anyOf('1:30', '1:29'));
    // Name, then the time, then the buttons.
    final name = tester.getRect(find.text('1:30 timer'));
    final time = tester.getRect(left);
    final pause = tester.getRect(find.widgetWithText(FilledButton, 'Pause'));
    expect(name.bottom, lessThanOrEqualTo(time.top));
    expect(time.bottom, lessThan(pause.top));
    // Reset, +1:00, Pause across the card; Pause at the end.
    final reset = tester.getRect(find.widgetWithText(OutlinedButton, 'Reset'));
    final plus = tester.getRect(find.widgetWithText(OutlinedButton, '+1:00'));
    expect(reset.right, lessThan(plus.left));
    expect(plus.right, lessThan(pause.left));
    expect(reset.top, pause.top);

    await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
    await frames(tester);
    expect(engine.calls, contains('pauseTimer timer-1'));
    expect(find.text('Paused'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Resume'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '+1:00'));
    await frames(tester);
    expect(engine.calls, contains('addTimerMinute timer-1'));

    // A second timer from the add button, on its own keypad screen.
    await tester.tap(find.text('Add timer'));
    await frames(tester);
    expect(find.byType(NewTimerPage), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, '5:00'));
    await frames(tester);
    expect(find.byType(NewTimerPage), findsNothing);
    expect(engine.calls, contains('addTimer 300s'));
    expect(find.byType(TimerCard), findsNWidgets(2));
    // The older one stays on top.
    expect(
      tester.getTopLeft(find.text('1:30 timer')).dy,
      lessThan(tester.getTopLeft(find.text('5:00 timer')).dy),
    );

    await tester.tap(find.byTooltip('Delete timer').first);
    await frames(tester);
    expect(engine.calls, contains('deleteTimer timer-1'));
    expect(find.byType(TimerCard), findsOneWidget);
  });

  testWidgets('a quick timer can be saved, and removed with undo', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    final prefs = InMemoryPreferencesStore();
    await tester.pumpWidget(
      testApp(engine, home: const TimersPage(), prefs: prefs),
    );
    await frames(tester);
    expect(find.text('Save as a quick timer'), findsNothing);
    await tester.tap(find.text('4').last);
    await tester.tap(find.text('5').last);
    await tester.pump();
    await tester.tap(find.text('Save as a quick timer'));
    await frames(tester);
    final saved = find.widgetWithText(InputChip, '0:45');
    expect(saved, findsOneWidget);
    // After the everyday ones.
    expect(
      tester.getTopLeft(saved).dy,
      greaterThanOrEqualTo(
        tester.getTopLeft(find.widgetWithText(ActionChip, '30:00')).dy,
      ),
    );
    expect(await prefs.read('clock_quick_timers'), '[45]');

    await tester.tap(
      find.descendant(of: saved, matching: find.byTooltip('Delete')),
    );
    await frames(tester);
    expect(find.widgetWithText(InputChip, '0:45'), findsNothing);
    await tester.tap(find.text('Undo'));
    await frames(tester);
    expect(find.widgetWithText(InputChip, '0:45'), findsOneWidget);
  });

  testWidgets('a finished timer says so, with +1:00 and Stop', (tester) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    engine.timerList.add(
      ClockTimer(
        id: 'egg',
        length: const Duration(minutes: 6),
        label: 'Eggs',
        endsAt: DateTime.now().subtract(const Duration(seconds: 12)),
        ringing: true,
      ),
    );
    await tester.pumpWidget(testApp(engine, home: const TimersPage()));
    await frames(tester);
    expect(find.text('Eggs'), findsOneWidget);
    expect(find.text("Time's up"), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('left-egg'))).data,
      startsWith('-0:1'),
    );
    final plus = tester.getRect(find.widgetWithText(OutlinedButton, '+1:00'));
    final stop = tester.getRect(find.widgetWithText(FilledButton, 'Stop'));
    expect(plus.right, lessThan(stop.left));
    expect(find.widgetWithText(FilledButton, 'Pause'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Stop'));
    await frames(tester);
    expect(engine.calls, contains('stopRingingTimers'));
    expect(find.text("Time's up"), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
  });

  testWidgets('a timer label is set from its name', (tester) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    engine.timerList.add(
      const ClockTimer(id: 't', length: Duration(minutes: 10)),
    );
    await tester.pumpWidget(testApp(engine, home: const TimersPage()));
    await frames(tester);
    await tester.tap(find.text('10:00 timer'));
    await frames(tester);
    await tester.enterText(find.byType(TextField), 'Pizza');
    await tester.tap(find.text('Save'));
    await frames(tester);
    expect(engine.calls, contains('setTimerLabel t "Pizza"'));
    expect(find.text('Pizza'), findsOneWidget);
  });

  testWidgets('the stopwatch counts, takes laps (newest on top) and resets', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    await tester.pumpWidget(testApp(engine, home: const StopwatchPage()));
    await frames(tester);
    final time = find.byKey(const ValueKey('stopwatchTime'));
    expect(tester.widget<Text>(time).data, '0:00.00');
    // At zero: Lap does nothing yet.
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Lap'))
          .onPressed,
      isNull,
    );
    final lapButton = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Lap'),
    );
    final startButton = tester.getRect(
      find.widgetWithText(FilledButton, 'Start'),
    );
    expect(lapButton.right, lessThan(startButton.left));
    expect(tester.getRect(time).bottom, lessThan(startButton.top));

    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await frames(tester);
    expect(engine.calls, contains('stopwatchStart'));
    expect(find.widgetWithText(FilledButton, 'Pause'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Lap'));
    await frames(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Lap'));
    await frames(tester);
    expect(find.text('Lap 1'), findsOneWidget);
    expect(find.text('Lap 2'), findsOneWidget);
    // The lap now running, under the time.
    expect(find.byKey(const ValueKey('currentLap')), findsOneWidget);
    // Laps below the buttons, newest first.
    final lap1 = tester.getRect(find.text('Lap 1'));
    final lap2 = tester.getRect(find.text('Lap 2'));
    expect(lap2.top, lessThan(lap1.top));
    expect(
      lap2.top,
      greaterThan(
        tester.getRect(find.widgetWithText(FilledButton, 'Pause')).bottom,
      ),
    );
    expect(find.byTooltip('Copy laps'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
    await frames(tester);
    expect(find.widgetWithText(FilledButton, 'Resume'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
    await frames(tester);
    expect(engine.calls.last, 'stopwatchReset');
    expect(tester.widget<Text>(time).data, '0:00.00');
    expect(find.text('Lap 1'), findsNothing);
  });

  testWidgets('a notification opens its tab, at start and while open', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine()..tabAtLaunch = 'stopwatch';
    await tester.pumpWidget(testApp(engine, home: const ClockHome()));
    await frames(tester);
    expect(find.byType(StopwatchPage), findsOneWidget);

    engine.openTabOutside('timers');
    await frames(tester);
    expect(find.byType(TimersPage), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });

  testWidgets('in Hebrew the keypad still reads hours, minutes, seconds', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    await tester.pumpWidget(
      testApp(engine, home: const TimersPage(), locale: hebrew),
    );
    await frames(tester);
    expect(find.text('טיימרים'), findsOneWidget);
    final hours = tester.getCenter(find.text('ש׳')).dx;
    final minutes = tester.getCenter(find.text('ד׳')).dx;
    final seconds = tester.getCenter(find.text('שנ׳')).dx;
    expect(hours, lessThan(minutes));
    expect(minutes, lessThan(seconds));
    // The keys too: 1 2 3 left to right.
    expect(
      tester.getCenter(find.text('1')).dx,
      lessThan(tester.getCenter(find.text('3')).dx),
    );
  });
}
