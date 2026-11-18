import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_clock/engine/alarm.dart';
import 'package:zerotrust_clock/ui/alarm_card.dart';
import 'package:zerotrust_clock/ui/alarm_check_page.dart';
import 'package:zerotrust_clock/ui/alarm_editor.dart';

import 'support/app.dart';
import 'support/fake_engine.dart';

Finder inCard(Finder what) =>
    find.descendant(of: find.byType(AlarmCard), matching: what);

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More options'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no alarms: + picks a time and the alarm is set', (tester) async {
    final engine = FakeClockEngine();
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    expect(find.text('Alarms'), findsOneWidget);
    expect(find.text('No alarms yet'), findsOneWidget);
    expect(find.byType(AlarmCard), findsNothing);

    await tester.tap(find.byTooltip('Add alarm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(engine.calls.first, startsWith('save new '));
    expect(find.byType(AlarmCard), findsOneWidget);
    expect(find.text('No alarms yet'), findsNothing);
    // Says how long until it rings, and asks for notifications once the
    // first alarm exists.
    expect(find.text('Rings in 8 h 0 min'), findsOneWidget);
    expect(engine.calls, contains('requestNotifications'));
  });

  testWidgets('cancelling the time picker adds nothing', (tester) async {
    final engine = FakeClockEngine();
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add alarm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(engine.calls, isEmpty);
    expect(find.text('No alarms yet'), findsOneWidget);
  });

  testWidgets('a card: time, days, then switch and menu at the end', (
    tester,
  ) async {
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {7, 1, 2, 3, 4}, label: 'Work'),
        alarm('b', hour: 22, minute: 30, enabled: false),
        alarm('c', hour: 9, minute: 15, days: {1, 2, 3, 4, 5, 6, 7}),
      ],
    );
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();

    // Earliest time of day first.
    final first = tester.getTopLeft(find.text('7:00 AM')).dy;
    final second = tester.getTopLeft(find.text('9:15 AM')).dy;
    final third = tester.getTopLeft(find.text('10:30 PM')).dy;
    expect(first, lessThan(second));
    expect(second, lessThan(third));

    // Days in this language's week order, the label first.
    expect(find.text('Work · Sun, Mon, Tue, Wed, Thu'), findsOneWidget);
    expect(find.text('Every day'), findsOneWidget);
    expect(find.text('Once'), findsOneWidget);

    final card = find.byKey(const ValueKey('a'));
    Finder within(Finder what) => find.descendant(of: card, matching: what);
    final time = tester.getRect(find.text('7:00 AM'));
    final days = tester.getRect(find.text('Work · Sun, Mon, Tue, Wed, Thu'));
    final toggle = tester.getRect(within(find.byType(Switch)));
    final menu = tester.getRect(within(find.byTooltip('More options')));
    expect(days.top, greaterThanOrEqualTo(time.bottom));
    expect(days.left, time.left);
    expect(time.right, lessThan(toggle.left));
    expect(toggle.right, lessThanOrEqualTo(menu.left));
    expect(toggle.center.dy, closeTo(menu.center.dy, 1));
    // No status line on an ordinary alarm.
    expect(find.textContaining('Off once'), findsNothing);
    expect(find.text('Turn back on'), findsNothing);

    expect(tester.widget<Switch>(within(find.byType(Switch))).value, isTrue);
    expect(
      tester
          .widget<Switch>(
            find.descendant(
              of: find.byKey(const ValueKey('b')),
              matching: find.byType(Switch),
            ),
          )
          .value,
      isFalse,
    );
  });

  testWidgets('Turn off once from the three-dot menu, and back on', (
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
    expect(find.text('Turn off once'), findsOneWidget);
    expect(find.text('Turn back on'), findsNothing);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Turn off once'));
    await tester.pumpAndSettle();

    expect(engine.calls, ['skipOnce a']);
    // The alarm stays on: only the next ring is skipped.
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    final status = inCard(find.textContaining('Off once. Next: '));
    expect(status, findsOneWidget);
    final back = inCard(find.widgetWithText(TextButton, 'Turn back on'));
    expect(back, findsOneWidget);
    // The status line sits under the time, its button at the end.
    expect(
      tester.getRect(status).top,
      greaterThan(tester.getRect(find.text('7:00 AM')).bottom),
    );
    expect(
      tester.getRect(back).left,
      greaterThanOrEqualTo(tester.getRect(status).right),
    );
    expect(
      tester.getRect(back).top,
      greaterThanOrEqualTo(tester.getRect(find.byType(Switch)).bottom - 8),
    );
    // The snackbar says the same and offers Undo.
    expect(find.widgetWithText(SnackBarAction, 'Undo'), findsOneWidget);

    // The menu now offers the way back instead.
    await openMenu(tester);
    expect(find.text('Turn off once'), findsNothing);
    // Once on the card, once in the menu.
    expect(find.text('Turn back on'), findsNWidgets(2));
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(engine.calls, ['skipOnce a', 'undoSkip a']);
    expect(inCard(find.textContaining('Off once')), findsNothing);
    expect(inCard(find.text('Turn back on')), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('Undo on the snackbar takes Turn off once back', (tester) async {
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {1}),
      ],
    );
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    await openMenu(tester);
    await tester.tap(find.text('Turn off once'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
    await tester.pumpAndSettle();
    expect(engine.calls, ['skipOnce a', 'undoSkip a']);
    expect(inCard(find.textContaining('Off once')), findsNothing);
  });

  testWidgets('the switch turns it off for good; "Just once" changes that', (
    tester,
  ) async {
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {1, 2}),
      ],
    );
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(engine.calls, ['setEnabled a false']);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('Alarm off'), findsOneWidget);

    await tester.tap(find.widgetWithText(SnackBarAction, 'Just once'));
    await tester.pumpAndSettle();
    expect(engine.calls, [
      'setEnabled a false',
      'setEnabled a true',
      'skipOnce a',
    ]);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(inCard(find.textContaining('Off once. Next: ')), findsOneWidget);
  });

  testWidgets('an alarm that is off: no "Turn off once", on says when', (
    tester,
  ) async {
    final engine = FakeClockEngine(alarms: [alarm('a', enabled: false)]);
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    await openMenu(tester);
    expect(find.text('Turn off once'), findsNothing);
    expect(find.text('Turn back on'), findsNothing);
    expect(find.text('Edit'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(engine.calls, ['setEnabled a true']);
    expect(find.text('Rings in 8 h 0 min'), findsOneWidget);
    // Switching on never offers "Just once".
    expect(find.byType(SnackBarAction), findsNothing);
  });

  testWidgets('delete from the menu, with Undo', (tester) async {
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {6}, label: 'Run', enabled: false, snoozeMinutes: 5),
      ],
    );
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    await openMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(engine.alarms, isEmpty);
    expect(find.byType(AlarmCard), findsNothing);
    expect(find.text('Alarm deleted'), findsOneWidget);

    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
    await tester.pumpAndSettle();
    expect(engine.calls, [
      'delete a',
      'save new 7:0 [6] "Run" true 5',
      // It was off before, so it comes back off.
      'setEnabled new-1 false',
    ]);
    expect(find.text('Run · Sat'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('a snoozed alarm says until when, and can be dismissed', (
    tester,
  ) async {
    final engine = FakeClockEngine(
      alarms: [
        alarm(
          'a',
          days: {1},
          snoozeUntil: DateTime.now().add(const Duration(minutes: 9)),
        ),
      ],
    );
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    expect(inCard(find.textContaining('Snoozed until ')), findsOneWidget);
    await tester.tap(inCard(find.widgetWithText(TextButton, 'Dismiss')));
    await tester.pumpAndSettle();
    expect(engine.calls, ['cancelSnooze a']);
    expect(find.textContaining('Snoozed until'), findsNothing);
  });

  testWidgets('while an alarm rings: Snooze and Dismiss side by side on top', (
    tester,
  ) async {
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {1}, label: 'Work', ringing: true),
      ],
    );
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();

    expect(find.text('Ringing now · Work'), findsOneWidget);
    final snooze = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Snooze'),
    );
    final dismiss = tester.getRect(
      find.widgetWithText(FilledButton, 'Dismiss'),
    );
    expect(snooze.center.dy, closeTo(dismiss.center.dy, 1));
    expect(snooze.right, lessThan(dismiss.left));
    expect(snooze.width, closeTo(dismiss.width, 1));
    expect(snooze.width, greaterThan(120));
    expect(
      dismiss.bottom,
      lessThan(tester.getRect(find.byType(AlarmCard)).top),
    );
    expect(inCard(find.text('Ringing now')), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Dismiss'));
    await tester.pumpAndSettle();
    expect(engine.calls, ['ringDismiss']);
    expect(find.textContaining('Ringing now'), findsNothing);
  });

  testWidgets('a problem on the phone shows above the alarms', (tester) async {
    final engine = FakeClockEngine(
      alarms: [alarm('a')],
      checkResult: const AlarmCheck(fullScreen: false, exactAlarms: false),
    );
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    expect(find.text('Alarms may not ring'), findsOneWidget);
    expect(find.text('2 things on this phone need attention.'), findsOneWidget);
    final open = find.widgetWithText(TextButton, 'Open Alarm check');
    expect(
      tester.getRect(open).bottom,
      lessThan(tester.getRect(find.byType(AlarmCard)).top),
    );
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byType(AlarmCheckPage), findsOneWidget);
  });

  testWidgets('nothing wrong on the phone: no warning', (tester) async {
    await tester.pumpWidget(testApp(FakeClockEngine(alarms: [alarm('a')])));
    await tester.pumpAndSettle();
    expect(find.text('Alarms may not ring'), findsNothing);
  });

  testWidgets('follows changes made outside the screen', (tester) async {
    final engine = FakeClockEngine(alarms: [alarm('a')]);
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    engine.alarms.add(alarm('b', hour: 8));
    engine.changedOutside();
    await tester.pumpAndSettle();
    expect(find.byType(AlarmCard), findsNWidgets(2));

    // Coming back to the app reads the list again too.
    engine.alarms.removeWhere((a) => a.id == 'a');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(AlarmCard), findsOneWidget);
    expect(find.text('8:00 AM'), findsOneWidget);
  });

  testWidgets('says so when a change did not go through', (tester) async {
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {1}),
      ],
    )..failNext = true;
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('That did not work. Try again.'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('edit: days, label and snooze are saved', (tester) async {
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {1}),
      ],
    );
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7:00 AM'));
    await tester.pumpAndSettle();
    expect(find.byType(AlarmEditorPage), findsOneWidget);
    expect(find.text('Edit alarm'), findsOneWidget);

    // The week starts on Sunday here, and the chips follow it.
    final chips = [
      for (final day in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])
        tester.getRect(find.widgetWithText(FilterChip, day)),
    ];
    for (var i = 1; i < chips.length; i++) {
      expect(chips[i].left, greaterThan(chips[i - 1].right));
      expect(chips[i].top, chips.first.top);
    }
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Mon'))
          .selected,
      isTrue,
    );
    expect(find.text('No day picked: the alarm rings once.'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Wed'));
    await tester.enterText(find.byType(TextField), ' Gym ');
    await tester.tap(find.widgetWithText(ChoiceChip, '15 min'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(engine.calls, ['save a 7:0 [13] "Gym" true 15']);
    expect(find.byType(AlarmEditorPage), findsNothing);
    expect(find.text('Gym · Mon, Wed'), findsOneWidget);
    expect(find.text('Rings in 8 h 0 min'), findsOneWidget);
  });

  testWidgets('edit: no day left means it rings once; time can change', (
    tester,
  ) async {
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {1}),
      ],
    );
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Mon'));
    await tester.pumpAndSettle();
    expect(find.text('No day picked: the alarm rings once.'), findsOneWidget);

    await tester.tap(find.byTooltip('Change time'));
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    // Leaving without Save changes nothing.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(engine.calls, isEmpty);
    expect(find.text('Mon'), findsOneWidget);
  });

  testWidgets('edit: the bin deletes, with Undo back on the list', (
    tester,
  ) async {
    final engine = FakeClockEngine(alarms: [alarm('a')]);
    await tester.pumpWidget(testApp(engine));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(engine.calls, ['delete a']);
    expect(find.text('Alarm deleted'), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, 'Undo'), findsOneWidget);
  });

  testWidgets('Hebrew: translated, and laid out right to left', (tester) async {
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {7, 1}, ringing: true),
      ],
    );
    await tester.pumpWidget(testApp(engine, locale: hebrew));
    await tester.pumpAndSettle();
    expect(find.text('שעונים מעוררים'), findsOneWidget);

    // Mirrored: the menu at the left edge, then the switch, then the time.
    final time = tester.getRect(find.text('7:00'));
    final toggle = tester.getRect(find.byType(Switch));
    final menu = tester.getRect(find.byTooltip('אפשרויות נוספות'));
    expect(menu.right, lessThanOrEqualTo(toggle.left));
    expect(toggle.right, lessThan(time.left));

    // Snooze is the first button, so it is on the right.
    final snooze = tester.getRect(
      find.widgetWithText(OutlinedButton, 'נודניק'),
    );
    final dismiss = tester.getRect(find.widgetWithText(FilledButton, 'סגירה'));
    expect(dismiss.right, lessThan(snooze.left));

    await tester.tap(find.widgetWithText(FilledButton, 'סגירה'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('אפשרויות נוספות'));
    await tester.pumpAndSettle();
    expect(find.text('כיבוי לפעם אחת'), findsOneWidget);
    expect(find.text('עריכה'), findsOneWidget);
    expect(find.text('מחיקה'), findsOneWidget);
    await tester.tap(find.text('כיבוי לפעם אחת'));
    await tester.pumpAndSettle();
    expect(inCard(find.textContaining('כבוי לפעם אחת. הבא: ')), findsOneWidget);
    expect(inCard(find.text('הפעלה מחדש')), findsOneWidget);
  });

  testWidgets('Hebrew editor: the week starts on Sunday, on the right', (
    tester,
  ) async {
    final engine = FakeClockEngine(alarms: [alarm('a')]);
    await tester.pumpWidget(testApp(engine, locale: hebrew));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7:00'));
    await tester.pumpAndSettle();
    expect(find.text('עריכת שעון מעורר'), findsOneWidget);
    final chips = tester
        .widgetList<FilterChip>(find.byType(FilterChip))
        .toList();
    expect(chips, hasLength(7));
    expect(chips.first.tooltip, 'יום ראשון');
    expect(chips.last.tooltip, 'יום שבת');
    // Hebrew names its days by letter: Sunday is "א׳".
    expect(find.widgetWithText(FilterChip, 'א׳'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'ש׳'), findsOneWidget);
    final first = tester.getRect(find.byType(FilterChip).first);
    final last = tester.getRect(find.byType(FilterChip).last);
    expect(first.left, greaterThan(last.right));
    expect(first.top, last.top);
    expect(find.text('שמירה'), findsOneWidget);
  });

  testWidgets('small phone, large text: nothing overflows', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final engine = FakeClockEngine(
      alarms: [
        alarm(
          'a',
          days: {1, 2, 3, 4, 5, 6},
          label: 'A long label for the morning',
          ringing: true,
        ),
        alarm('b', hour: 8, days: {1}, skipActive: true),
        alarm(
          'c',
          hour: 9,
          snoozeUntil: DateTime.now().add(const Duration(minutes: 5)),
        ),
      ],
      checkResult: const AlarmCheck(notifications: false),
    );
    for (final locale in [null, hebrew]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(testApp(engine, locale: locale, textScale: 1.6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The banner and the warning fill this screen: scroll to the cards.
      final snoozed = find.byKey(const ValueKey('c'));
      await tester.scrollUntilVisible(snoozed, 200);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlarmCard), findsWidgets);

      await tester.tap(
        find.descendant(of: snoozed, matching: find.byType(Text)).first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlarmEditorPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
