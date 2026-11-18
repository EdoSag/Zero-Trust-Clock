import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_clock/engine/alarm.dart';
import 'package:zerotrust_clock/ui/alarm_check_page.dart';

import 'support/app.dart';
import 'support/fake_engine.dart';

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('all fine: says so, and there is nothing to fix', (tester) async {
    tall(tester);
    final engine = FakeClockEngine(
      checkResult: const AlarmCheck(alarmVolume: 5, alarmVolumeMax: 7),
    );
    await tester.pumpWidget(testApp(engine, home: const AlarmCheckPage()));
    await tester.pumpAndSettle();

    expect(find.text('Alarm check'), findsOneWidget);
    expect(find.text('Everything looks right'), findsOneWidget);
    expect(find.text('Alarms may not ring'), findsNothing);
    expect(find.text('Fix'), findsNothing);
    expect(find.text('On'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Allowed'), findsNWidgets(2));
    expect(find.text('5 of 7'), findsOneWidget);
    expect(find.text('Alarms can ring'), findsOneWidget);
    expect(find.text('Main profile'), findsOneWidget);
    expect(
      find.text('No restart seen since the app was installed.'),
      findsOneWidget,
    );

    // The summary first, then the checks, then the tests.
    final tops = [
      for (final text in [
        'Everything looks right',
        'Notifications',
        '"Ringing alarms" notifications',
        'Alarm screen over the lock screen',
        'Exact alarms',
        'Alarm volume',
        'Do Not Disturb',
        'Phone profile',
        'After a restart',
        'Try it',
        'Test alarm in 10 seconds',
        'Restart test',
      ])
        tester.getTopLeft(find.text(text)).dy,
    ];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: 'row $i');
    }
  });

  testWidgets('each problem has its own Fix that opens the right screen', (
    tester,
  ) async {
    tall(tester);
    final engine = FakeClockEngine(
      checkResult: AlarmCheck(
        notifications: false,
        ringChannel: false,
        fullScreen: false,
        exactAlarms: false,
        alarmVolume: 0,
        alarmVolumeMax: 7,
        totalSilence: true,
        ownerProfile: false,
        bootAt: DateTime.now().subtract(const Duration(hours: 1)),
        bootLocked: true,
      ),
    )..grantNotifications = false;
    await tester.pumpWidget(testApp(engine, home: const AlarmCheckPage()));
    await tester.pumpAndSettle();

    expect(find.text('Everything looks right'), findsNothing);
    expect(find.text('Alarms may not ring'), findsOneWidget);
    expect(find.text('6 things on this phone need attention.'), findsOneWidget);
    // The kind of notification cannot be read while notifications are off.
    expect(find.text('"Ringing alarms" notifications'), findsNothing);
    expect(
      find.textContaining('before the phone was unlocked'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Secondary profile. When this profile is ended, its alarms do '
        'not ring.',
      ),
      findsOneWidget,
    );

    // Five fixes (the profile has none), each at the end of its own row.
    final fixes = find.widgetWithText(TextButton, 'Fix');
    expect(fixes, findsNWidgets(5));
    final titles = [
      'Notifications',
      'Alarm screen over the lock screen',
      'Exact alarms',
      'Alarm volume',
      'Do Not Disturb',
    ];
    for (var i = 0; i < titles.length; i++) {
      final row = tester.getRect(
        find.ancestor(
          of: find.text(titles[i]),
          matching: find.byType(ListTile),
        ),
      );
      final fix = tester.getRect(fixes.at(i));
      expect(row.contains(fix.center), isTrue, reason: titles[i]);
      expect(
        fix.left,
        greaterThan(tester.getRect(find.text(titles[i])).right),
        reason: titles[i],
      );
    }

    for (var i = 0; i < 5; i++) {
      await tester.tap(fixes.at(i));
      await tester.pumpAndSettle();
    }
    expect(engine.calls, [
      // Asks first; refused, so the system screen opens.
      'requestNotifications',
      'openSettings notifications',
      'openSettings fullScreen',
      'openSettings exactAlarms',
      'openSettings sound',
      'openSettings doNotDisturb',
    ]);
  });

  testWidgets('notifications: granted on the spot needs no settings screen', (
    tester,
  ) async {
    tall(tester);
    final engine = FakeClockEngine(
      checkResult: const AlarmCheck(notifications: false),
    );
    await tester.pumpWidget(testApp(engine, home: const AlarmCheckPage()));
    await tester.pumpAndSettle();
    engine.checkResult = const AlarmCheck();
    await tester.tap(find.widgetWithText(TextButton, 'Fix'));
    await tester.pumpAndSettle();
    expect(engine.calls, ['requestNotifications']);
    expect(find.text('Everything looks right'), findsOneWidget);
    expect(find.text('Fix'), findsNothing);
  });

  testWidgets('the ring notification turned down is its own problem', (
    tester,
  ) async {
    tall(tester);
    final engine = FakeClockEngine(
      checkResult: const AlarmCheck(ringChannel: false),
    );
    await tester.pumpWidget(testApp(engine, home: const AlarmCheckPage()));
    await tester.pumpAndSettle();
    expect(find.text('1 thing on this phone needs attention.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Fix'));
    await tester.pumpAndSettle();
    expect(engine.calls, ['openSettings ringChannel']);

    // Fixed in the system screen: coming back reads it all again.
    engine.checkResult = const AlarmCheck();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Everything looks right'), findsOneWidget);
  });

  testWidgets('the two test alarms', (tester) async {
    tall(tester);
    final engine = FakeClockEngine();
    await tester.pumpWidget(testApp(engine, home: const AlarmCheckPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test alarm in 10 seconds'));
    await tester.pumpAndSettle();
    expect(engine.calls, ['testAlarm 10']);
    expect(find.text('Test alarm rings in 10 seconds.'), findsOneWidget);

    await tester.tap(find.text('Restart test'));
    await tester.pumpAndSettle();
    expect(engine.calls, ['testAlarm 10', 'testAlarm 180']);
    expect(
      find.text(
        'Test alarm rings in 3 minutes. Restart the phone now and do not '
        'unlock it.',
      ),
      findsOneWidget,
    );

    engine.failNext = true;
    await tester.tap(find.text('Test alarm in 10 seconds'));
    await tester.pumpAndSettle();
    expect(find.text('That did not work. Try again.'), findsOneWidget);
  });

  testWidgets('Hebrew, small phone, large text: translated, no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final engine = FakeClockEngine(
      checkResult: const AlarmCheck(
        fullScreen: false,
        alarmVolume: 0,
        totalSilence: true,
      ),
    );
    await tester.pumpWidget(
      testApp(
        engine,
        home: const AlarmCheckPage(),
        locale: hebrew,
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('בדיקת השעון המעורר'), findsOneWidget);
    expect(find.text('3 דברים בטלפון הזה דורשים טיפול.'), findsOneWidget);

    // Right to left: the Fix button is at the left end of its row.
    final title = find.text('מסך השעון המעורר מעל מסך הנעילה');
    await tester.scrollUntilVisible(title, 200);
    await tester.pumpAndSettle();
    final fix = find.descendant(
      of: find.ancestor(of: title, matching: find.byType(ListTile)),
      matching: find.widgetWithText(TextButton, 'תיקון'),
    );
    expect(tester.getRect(fix).right, lessThan(tester.getRect(title).left));

    final last = find.text('בדיקת הפעלה מחדש');
    await tester.scrollUntilVisible(last, 200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(last, findsOneWidget);
  });
}
