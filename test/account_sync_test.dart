import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_clock/app/clock_gate.dart';
import 'package:zerotrust_clock/sync/alarm_sync.dart';
import 'package:zerotrust_clock/sync/alarm_sync_host.dart';
import 'package:zerotrust_clock/ui/alarm_card.dart';
import 'package:zerotrust_clock/ui/settings_page.dart';

import 'alarm_sync_test.dart' show FakeVault, synced;
import 'support/app.dart';
import 'support/fake_engine.dart';

/// The account's copy is open, as after a sign-in and unlock.
List<Override> openAccount(FakeVault vault, {String device = 'B'}) => [
  alarmVaultProvider.overrideWith((ref) async => vault),
  ztDeviceIdProvider.overrideWith((ref) async => device),
];

/// Lets the sync host's gathering delay pass and the round finish.
Future<void> settleSync(WidgetTester tester) async {
  await tester.pump(AlarmSyncHost.delay + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed out: straight to the alarms, sign-in waits in Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {1}),
      ],
    );
    await tester.pumpWidget(testApp(engine, home: const ClockGate()));
    await tester.pumpAndSettle();
    expect(find.byType(AlarmCard), findsOneWidget);
    expect(find.byType(ZtUnlockScreen), findsNothing);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(ClockSettingsPage), findsOneWidget);
    // Account first, above the language.
    final signIn = tester.getTopLeft(find.text('Sign in or create an account'));
    final backup = tester.getTopLeft(
      find.text('Back up and sync with your Zero-Trust account'),
    );
    final language = tester.getTopLeft(find.text('Language'));
    expect(signIn.dy, lessThan(backup.dy));
    expect(backup.dy, lessThan(language.dy));

    await tester.tap(find.text('Sign in or create an account'));
    await tester.pumpAndSettle();
    expect(find.byType(ZtSignInScreen), findsOneWidget);
    // A way back in the top corner, clear of the form.
    final back = tester.getRect(find.byType(BackButton));
    expect(back.left, lessThan(40));
    expect(back.top, lessThan(40));
    expect(
      back.bottom,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(TextField).first).dy),
    );

    // Back: the app is as it was, still without an account.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ClockSettingsPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AlarmCard), findsOneWidget);
  });

  testWidgets('alarms from the account arrive switched off, with a note', (
    tester,
  ) async {
    final vault = FakeVault()
      ..items['gym'] = VaultAlarm.live(
        synced('gym', hour: 6, minute: 30, label: 'Gym', onDevices: {'A'}),
      );
    final engine = FakeClockEngine(
      alarms: [
        alarm('mine', hour: 8, days: {6}, updatedAt: 10),
      ],
    );
    await tester.pumpWidget(
      testApp(engine, home: const ClockGate(), overrides: openAccount(vault)),
    );
    await tester.pumpAndSettle();
    await settleSync(tester);

    // This phone's alarm went to the account, switched on for this phone.
    expect(vault.live('mine')!.onDevices, {'B'});
    // The other phone's alarm is here, first by time, and off.
    final cards = find.byType(AlarmCard);
    expect(cards, findsNWidgets(2));
    final gymCard = find.ancestor(
      of: find.textContaining('Gym'),
      matching: find.byType(AlarmCard),
    );
    final mineCard = find.ancestor(
      of: find.text('Sat'),
      matching: find.byType(AlarmCard),
    );
    expect(
      tester.getTopLeft(gymCard).dy,
      lessThan(tester.getTopLeft(mineCard).dy),
    );
    final gymSwitch = tester.widget<Switch>(
      find.descendant(of: gymCard, matching: find.byType(Switch)),
    );
    expect(gymSwitch.value, isFalse);
    expect(engine.calls, contains('importSynced gym false'));

    const note =
        '1 alarm from your account was added. It stays off on this phone '
        'until you switch it on.';
    expect(find.text(note), findsOneWidget);
    // The note is at the bottom, below the alarms.
    expect(
      tester.getTopLeft(find.text(note)).dy,
      greaterThan(tester.getBottomLeft(mineCard).dy),
    );
  });

  testWidgets('switching on here, then deleting here, reach the account', (
    tester,
  ) async {
    final vault = FakeVault()
      ..items['gym'] = VaultAlarm.live(
        synced('gym', hour: 6, label: 'Gym', onDevices: {'A'}),
      );
    final engine = FakeClockEngine();
    await tester.pumpWidget(
      testApp(engine, home: const ClockGate(), overrides: openAccount(vault)),
    );
    await tester.pumpAndSettle();
    await settleSync(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await settleSync(tester);
    expect(vault.live('gym')!.onDevices, {'A', 'B'});

    await tester.tap(
      find.descendant(
        of: find.byType(AlarmCard),
        matching: find.byTooltip('More options'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await settleSync(tester);
    expect(vault.live('gym'), isNull);
    expect(vault.items['gym']!.deletedAt, isNotNull);
    // And it doesn't come back.
    await settleSync(tester);
    expect(find.byType(AlarmCard), findsNothing);
  });

  testWidgets('without an account nothing is synced and deletes are kept', (
    tester,
  ) async {
    final prefs = InMemoryPreferencesStore();
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {2}),
      ],
    );
    await tester.pumpWidget(
      testApp(engine, home: const ClockGate(), prefs: prefs),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlarmCard),
        matching: find.byTooltip('More options'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await settleSync(tester);
    expect(engine.calls, ['delete a']);
    // Kept, so the account is told after a later sign-in.
    expect(await DeletedAlarms(prefs).read(), {'a'});
  });
}
