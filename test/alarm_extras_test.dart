import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_clock/engine/alarm.dart';
import 'package:zerotrust_clock/engine/clock_engine.dart';
import 'package:zerotrust_clock/sync/alarm_sync.dart';
import 'package:zerotrust_clock/ui/alarm_card.dart';
import 'package:zerotrust_clock/ui/settings_page.dart';

import 'alarm_options_test.dart' show scrollTo;
import 'settings_sync_test.dart' show FakeSettingsVault, Phone;
import 'support/app.dart';
import 'support/fake_engine.dart';
import 'timers_test.dart' show tallPhone;

const code = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

Future<FakeClockEngine> openEditor(
  WidgetTester tester, {
  ClockAlarm? first,
  Locale? locale,
}) async {
  tallPhone(tester);
  final engine = FakeClockEngine(
    alarms: [
      first ?? alarm('a', days: {1}),
    ],
  );
  await tester.pumpWidget(testApp(engine, locale: locale));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(AlarmCard));
  await tester.pumpAndSettle();
  return engine;
}

Future<void> save(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Save');
  await scrollTo(tester, button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  group('built-in sounds', () {
    testWidgets('the list has the app\'s sounds, each with a button to hear '
        'it', (tester) async {
      final engine = await openEditor(tester);
      await scrollTo(tester, find.text('Sound'));
      await tester.tap(find.text('Sound'));
      await tester.pumpAndSettle();

      // The app's own sounds first, in order, then the phone's.
      final names = [
        'ZT chime',
        'Bells',
        'Beeps',
        'Sunrise',
        'Buzzer',
        'The phone\'s alarm sound',
        'Choose a phone sound',
        'Choose an audio file',
      ];
      // "ZT chime" is also the row behind the list: the last one is the list's.
      final ys = [
        for (final n in names) tester.getTopLeft(find.text(n).last).dy,
      ];
      expect(ys, [...ys]..sort());
      // The one in use is ticked.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('sound-chime')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );

      // Play is at the end of its row, after the name, and plays that sound.
      final row = find.byKey(const ValueKey('sound-builtin:bells'));
      final play = find.descendant(of: row, matching: find.byTooltip('Play'));
      expect(
        tester.getRect(play).left,
        greaterThan(tester.getRect(find.text('Bells')).right),
      );
      await tester.tap(play);
      await tester.pumpAndSettle();
      expect(engine.calls.last, 'previewSound builtin:bells');
      // Hearing one does not pick it.
      expect(find.byKey(const ValueKey('sound-builtin:bells')), findsOneWidget);

      await tester.tap(find.text('Bells'));
      await tester.pumpAndSettle();
      // The preview stops with the list, and the row says what was picked.
      expect(engine.calls.last, 'stopPreview');
      expect(find.byKey(const ValueKey('sound-builtin:bells')), findsNothing);
      expect(find.text('Bells'), findsOneWidget);

      await save(tester);
      expect(engine.lastSave['sound'], 'builtin:bells');
      expect(engine.lastSave['soundName'], isNull);
    });

    testWidgets('a saved built-in sound shows by its name, in Hebrew too', (
      tester,
    ) async {
      await openEditor(
        tester,
        first: alarm('a', days: {1}, sound: 'builtin:sunrise'),
        locale: hebrew,
      );
      await scrollTo(tester, find.text('צליל'));
      expect(find.text('זריחה'), findsOneWidget);
    });
  });

  group('scan a code', () {
    testWidgets('the task is only taken once a code was scanned', (
      tester,
    ) async {
      final engine = await openEditor(tester);
      final scan = find.widgetWithText(ChoiceChip, 'Scan a code');
      await scrollTo(tester, scan);

      // Nothing scanned (the camera was closed): the task stays as it was.
      await tester.tap(scan);
      await tester.pumpAndSettle();
      expect(engine.calls.last, 'scanCode');
      expect(find.text('No code was scanned'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(scan).selected, isFalse);
      expect(find.byKey(const ValueKey('scanCode')), findsNothing);
      // The message goes away by itself.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('No code was scanned'), findsNothing);

      engine.codeToScan = code;
      await tester.tap(scan);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(scan).selected, isTrue);
      // "Code saved" under the tasks, with "Scan another" at its end.
      final row = find.byKey(const ValueKey('scanCode'));
      await scrollTo(tester, row);
      expect(
        tester.getRect(row).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey('wakeTask'))).bottom,
        ),
      );
      final again = find.widgetWithText(TextButton, 'Scan another');
      expect(
        tester.getRect(again).left,
        greaterThan(tester.getRect(find.text('Code saved')).right),
      );

      await save(tester);
      expect(engine.lastSave['task'], 'scan');
      expect(engine.lastSave['taskCode'], code);
    });

    testWidgets('another task forgets the code; coming back keeps it', (
      tester,
    ) async {
      final engine = await openEditor(
        tester,
        first: alarm('a', days: {1}, task: WakeTask.scan, taskCode: code),
      );
      final scan = find.widgetWithText(ChoiceChip, 'Scan a code');
      await scrollTo(tester, scan);
      expect(tester.widget<ChoiceChip>(scan).selected, isTrue);
      expect(find.text('Code saved'), findsOneWidget);

      // Sums and back: no new scan is asked for.
      await scrollTo(tester, find.widgetWithText(ChoiceChip, 'Solve 3 sums'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Solve 3 sums'));
      await tester.pumpAndSettle();
      expect(find.text('Code saved'), findsNothing);
      await tester.tap(scan);
      await tester.pumpAndSettle();
      expect(engine.calls, isNot(contains('scanCode')));
      expect(find.text('Code saved'), findsOneWidget);

      // Saved with sums, the code is not kept.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Solve 3 sums'));
      await tester.pumpAndSettle();
      await save(tester);
      expect(engine.lastSave['task'], 'math');
      expect(engine.lastSave['taskCode'], isNull);
    });

    test('the code goes to the other phones with the task', () {
      final s = SyncedAlarm.fromEngine(
        alarm('a', days: {1}, task: WakeTask.scan, taskCode: code),
        device: 'A',
      );
      expect(s.toJson()['task'], 'scan');
      expect(s.toJson()['taskCode'], code);
      final there = SyncedAlarm.fromJson('a', s.toJson()).toEngine('B');
      expect(there.task, WakeTask.scan);
      expect(there.taskCode, code);

      // A code left over under another task is not sent.
      final math = SyncedAlarm.fromEngine(
        alarm('b', days: {1}, task: WakeTask.math, taskCode: code),
        device: 'A',
      );
      expect(math.toJson()['taskCode'], isNull);
    });
  });

  group('ring settings', () {
    Future<FakeClockEngine> openSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final engine = FakeClockEngine();
      await tester.pumpWidget(testApp(engine, home: const ClockSettingsPage()));
      await tester.pumpAndSettle();
      return engine;
    }

    testWidgets('volume buttons: change the volume, snooze or dismiss', (
      tester,
    ) async {
      final engine = await openSettings(tester);
      final row = find.byKey(const ValueKey('volumeButtons'));
      // Under Alarm check, and it says what the buttons do now.
      expect(
        tester.getRect(row).top,
        greaterThan(tester.getRect(find.text('Alarm check')).bottom),
      );
      expect(
        find.descendant(of: row, matching: find.text('Change the volume')),
        findsOneWidget,
      );

      await tester.tap(row);
      await tester.pumpAndSettle();
      // The three choices in order, the explanation under them.
      final ys = [
        for (final t in ['Change the volume', 'Snooze', 'Dismiss'])
          tester.getTopLeft(find.text(t).last).dy,
        tester.getTopLeft(find.textContaining('A wake-up task is still')).dy,
      ];
      expect(ys, [...ys]..sort());
      await tester.tap(find.text('Snooze'));
      await tester.pumpAndSettle();
      expect(engine.calls.last, 'setRingSettings snooze 0');
      expect(
        find.descendant(of: row, matching: find.text('Snooze')),
        findsOneWidget,
      );
    });

    testWidgets('ring at least this loud keeps the other setting', (
      tester,
    ) async {
      final engine = await openSettings(tester);
      engine.ring = const RingSettings(volumeButtons: VolumeButtons.dismiss);
      // Read again from the engine.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(testApp(engine, home: const ClockSettingsPage()));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('minVolume'));
      expect(
        tester.getRect(row).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey('volumeButtons'))).bottom,
        ),
      );
      expect(
        find.descendant(
          of: row,
          matching: find.text('Off: the phone\'s alarm volume'),
        ),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      for (final p in [30, 50, 70, 100]) {
        expect(find.text('$p% of the loudest'), findsOneWidget);
      }
      await tester.tap(find.text('70% of the loudest'));
      await tester.pumpAndSettle();
      expect(engine.calls.last, 'setRingSettings dismiss 70');
      expect(
        find.descendant(of: row, matching: find.text('70% of the loudest')),
        findsOneWidget,
      );
    });

    testWidgets('closing the list without picking changes nothing', (
      tester,
    ) async {
      final engine = await openSettings(tester);
      await tester.tap(find.byKey(const ValueKey('minVolume')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(
        engine.calls.where((c) => c.startsWith('setRingSettings')),
        isEmpty,
      );
    });

    test('they are backed up, and arrive on the other phone', () async {
      final vault = FakeSettingsVault();
      final a = Phone(vault);
      final b = Phone(vault);
      await a.container.read(ringSettingsProvider.future);
      // Untouched, nothing is sent.
      await a.sync();
      expect(vault.items.keys, isNot(contains('ring')));

      await a.container
          .read(ringSettingsProvider.notifier)
          .set(
            const RingSettings(
              volumeButtons: VolumeButtons.snooze,
              minVolume: 50,
            ),
          );
      await a.sync();
      expect(vault.items['ring']!.data, {
        'volumeButtons': 'snooze',
        'minVolume': 50,
        'morning': 'counts',
      });
      await b.sync();
      expect(b.engine.ring.volumeButtons, VolumeButtons.snooze);
      expect(b.engine.ring.minVolume, 50);
    });

    test('a broken copy falls back to the plain settings', () {
      final s = RingSettings.fromMap(const {
        'volumeButtons': 'mute',
        'minVolume': 42,
      });
      expect(s.volumeButtons, VolumeButtons.volume);
      expect(s.minVolume, 0);
      expect(RingSettings.fromMap(const {'minVolume': 'loud'}).minVolume, 0);
    });
  });
}
