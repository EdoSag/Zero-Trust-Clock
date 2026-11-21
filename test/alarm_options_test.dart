import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_clock/engine/alarm.dart';
import 'package:zerotrust_clock/engine/clock_engine.dart';
import 'package:zerotrust_clock/sync/alarm_sync.dart';
import 'package:zerotrust_clock/ui/alarm_card.dart';
import 'package:zerotrust_clock/ui/alarm_editor.dart';

import 'alarms_page_test.dart' show editorScroll, inCard, openMenu;
import 'support/app.dart';
import 'support/fake_engine.dart';

String inDays(int days) {
  final now = DateTime.now();
  return dayKey(DateTime(now.year, now.month, now.day + days));
}

Future<void> scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: editorScroll);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Pause until from the menu; the card says until when', (
    tester,
  ) async {
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {1, 2, 3, 4, 5}),
      ],
    );
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    await openMenu(tester);
    await tester.tap(find.text('Pause until…'));
    await tester.pumpAndSettle();
    // A week ahead is offered; OK takes it.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(engine.calls, ['pause a ${inDays(7)}']);

    final status = find.textContaining('Paused until');
    expect(inCard(status), findsOneWidget);
    // Under the time, with Resume after it.
    final time = tester.getRect(inCard(find.text('7:00 AM')));
    final line = tester.getRect(inCard(status));
    expect(line.top, greaterThan(time.bottom));
    final resume = inCard(find.widgetWithText(TextButton, 'Resume'));
    expect(tester.getRect(resume).left, greaterThan(line.left));

    // The menu offers Resume instead of Pause now.
    await openMenu(tester);
    expect(find.text('Pause until…'), findsNothing);
    expect(find.widgetWithText(PopupMenuItem<Object>, 'Resume'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(resume);
    await tester.pumpAndSettle();
    expect(engine.calls.last, 'resume a');
    expect(inCard(status), findsNothing);
  });

  testWidgets('one-time alarms have no Pause until', (tester) async {
    final engine = FakeClockEngine(alarms: [alarm('a')]);
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    await openMenu(tester);
    expect(find.text('Pause until…'), findsNothing);
    expect(find.text('Turn off once'), findsOneWidget);
  });

  testWidgets('Pause all from the top menu: a card above the alarms', (
    tester,
  ) async {
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {6}),
      ],
    );
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    final top = find.descendant(
      of: find.byType(AppBar),
      matching: find.byTooltip('More options'),
    );
    await tester.tap(top);
    await tester.pumpAndSettle();
    expect(find.text('Resume all alarms'), findsNothing);
    await tester.tap(find.text('Pause all alarms until…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(engine.calls, ['setPauseAll ${inDays(7)}']);

    final banner = find.textContaining('Repeating alarms are paused through');
    expect(banner, findsOneWidget);
    expect(
      tester.getRect(banner).bottom,
      lessThan(tester.getRect(find.byType(AlarmCard)).top),
    );

    await tester.tap(top);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume all alarms'));
    await tester.pumpAndSettle();
    expect(engine.calls.last, 'setPauseAll off');
    expect(banner, findsNothing);
  });

  testWidgets('editor: sound, gradually louder and silence after are saved', (
    tester,
  ) async {
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {1}),
      ],
    )..soundToPick = const PickedSound('file:x.ogg', 'Birds');
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AlarmCard));
    await tester.pumpAndSettle();
    expect(find.byType(AlarmEditorPage), findsOneWidget);
    // A repeating alarm has no date to pick.
    expect(find.text('Date'), findsNothing);

    await scrollTo(tester, find.text('Sound'));
    expect(find.text('ZT chime'), findsOneWidget);
    await tester.tap(find.text('Sound'));
    await tester.pumpAndSettle();
    expect(find.textContaining('copied into the app'), findsOneWidget);
    await tester.tap(find.text('Choose an audio file'));
    await tester.pumpAndSettle();
    expect(engine.calls, contains('pickSound file'));
    expect(find.text('Birds'), findsOneWidget);

    await tester.tap(find.text('Gradually louder'));
    await tester.pumpAndSettle();
    final five = find.descendant(
      of: find.byKey(const ValueKey('silenceAfter')),
      matching: find.widgetWithText(ChoiceChip, '5 min'),
    );
    await scrollTo(tester, five);
    await tester.tap(five);
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save');
    await scrollTo(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(engine.lastSave, {
      'taskCode': null,
      'sound': 'file:x.ogg',
      'soundName': 'Birds',
      'gradual': true,
      'ringMinutes': 5,
      'task': null,
      'skipHolidays': false,
      'date': null,
    });
  });

  testWidgets('editor: a one-time alarm can ring on a picked date', (
    tester,
  ) async {
    final engine = FakeClockEngine(
      alarms: [alarm('a', hour: 23, minute: 59, date: inDays(1))],
    );
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AlarmCard));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Date'));
    expect(find.text('Tomorrow'), findsOneWidget);
    // Under the days, above the label.
    expect(
      tester.getRect(find.text('Date')).bottom,
      lessThan(tester.getRect(find.byType(TextField)).top),
    );
    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save');
    await scrollTo(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(engine.lastSave['date'], inDays(1));
  });

  test(
    'pause, gradually louder and silence after sync; the sound does not',
    () {
      final s = SyncedAlarm.fromEngine(
        alarm(
          'a',
          days: {1},
          pauseUntil: '2026-12-01',
          gradual: true,
          ringMinutes: 5,
          sound: 'file:x.ogg',
          soundName: 'Birds',
        ),
        device: 'A',
      );
      expect(s.toJson().containsKey('sound'), isFalse);
      final back = SyncedAlarm.fromJson('a', s.toJson()).toEngine('B');
      expect(back.pauseUntil, '2026-12-01');
      expect(back.gradual, isTrue);
      expect(back.ringMinutes, 5);
      expect(back.sound, isNull);
    },
  );

  testWidgets('editor: a wake-up task is picked under Silence after', (
    tester,
  ) async {
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {1}),
      ],
    );
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AlarmCard));
    await tester.pumpAndSettle();
    final shake = find.widgetWithText(ChoiceChip, 'Shake 30 times');
    await scrollTo(tester, shake);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'None'))
          .selected,
      isTrue,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('wakeTask'))).top,
      greaterThan(
        tester.getRect(find.byKey(const ValueKey('silenceAfter'))).bottom,
      ),
    );
    await tester.tap(shake);
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save');
    await scrollTo(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(engine.lastSave['task'], 'shake');
    expect(engine.alarms.single.task, WakeTask.shake);
  });

  test('the wake-up task syncs, and an unknown one is dropped', () {
    final s = SyncedAlarm.fromEngine(
      alarm('a', days: {1}, task: WakeTask.math),
      device: 'A',
    );
    expect(s.toJson()['task'], 'math');
    expect(
      SyncedAlarm.fromJson('a', s.toJson()).toEngine('B').task,
      WakeTask.math,
    );
    final none = SyncedAlarm.fromEngine(alarm('b', days: {1}), device: 'A');
    expect(none.toJson()['task'], isNull);
    expect(
      SyncedAlarm.fromJson('c', {...s.toJson(), 'task': 'qr'}).task,
      isNull,
    );
    expect(
      ClockAlarm.fromJson({
        'id': 'x',
        'hour': 7,
        'minute': 0,
        'task': 'shake',
      }).task,
      WakeTask.shake,
    );
  });
}
