import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_clock/app/account.dart';
import 'package:zerotrust_clock/app/edition.dart';
import 'package:zerotrust_clock/ui/alarm_card.dart';
import 'package:zerotrust_clock/ui/settings_page.dart';

import 'alarm_options_test.dart' show scrollTo;
import 'support/app.dart';
import 'support/fake_engine.dart';
import 'timers_test.dart' show tallPhone;

void main() {
  test('the tests run as the full edition', () {
    expect(offlineEdition, isFalse);
  });

  test('the Offline edition has no account, and signing out is harmless', () {
    final account = AccountService(const NoAccountBackend());
    expect(account.currentEmail, isNull);
    expect(account.currentUserId, isNull);
    expect(account.signOut(), completes);
  });

  testWidgets('Offline settings: no sign-in, no holiday download', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        FakeClockEngine(),
        home: const ClockSettingsPage(),
        overrides: [offlineEditionProvider.overrideWithValue(true)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in or create an account'), findsNothing);
    expect(find.text('Account'), findsNothing);
    expect(find.text('Public holidays'), findsNothing);

    // Clock's section opens by saying which edition this is, then the
    // rows that need no network.
    final section = tester.getRect(find.text('Zero-Trust Clock').first);
    final edition = tester.getRect(
      find.byKey(const ValueKey('offlineEdition')),
    );
    final check = tester.getRect(find.text('Alarm check'));
    final screensaver = tester.getRect(find.text('Night clock screensaver'));
    expect(section.bottom, lessThanOrEqualTo(edition.top));
    expect(edition.bottom, lessThanOrEqualTo(check.top));
    expect(check.bottom, lessThanOrEqualTo(screensaver.top));
    expect(find.text('Offline edition'), findsOneWidget);
    expect(find.textContaining('No internet permission'), findsOneWidget);
  });

  testWidgets('the full edition offers sign-in and holidays in settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(FakeClockEngine(), home: const ClockSettingsPage()),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('offlineEdition')), findsNothing);
    final signIn = tester.getRect(find.text('Sign in or create an account'));
    final holidays = tester.getRect(find.text('Public holidays'));
    expect(signIn.bottom, lessThanOrEqualTo(holidays.top));
  });

  testWidgets('Offline alarm editor has no Skip public holidays', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {1, 2}),
      ],
    );
    await tester.pumpWidget(
      testApp(
        engine,
        overrides: [offlineEditionProvider.overrideWithValue(true)],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AlarmCard));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save');
    await scrollTo(tester, save);
    expect(find.byKey(const ValueKey('skipHolidays')), findsNothing);
    expect(find.text('Skip public holidays'), findsNothing);
  });

  testWidgets('Offline never counts as signed in', (tester) async {
    late bool signedIn;
    await tester.pumpWidget(
      testApp(
        FakeClockEngine(),
        overrides: [offlineEditionProvider.overrideWithValue(true)],
        home: Consumer(
          builder: (context, ref, _) {
            signedIn = ref.watch(signedInProvider);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
    expect(signedIn, isFalse);
  });
}
