import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_clock/app/clock_config.dart';
import 'package:zerotrust_clock/engine/clock_engine.dart';
import 'package:zerotrust_clock/main.dart';
import 'package:zerotrust_clock/ui/alarm_check_page.dart';
import 'package:zerotrust_clock/ui/alarms_page.dart';
import 'package:zerotrust_clock/ui/settings_page.dart';

import 'support/app.dart';
import 'support/fake_engine.dart';

void main() {
  testWidgets('settings without an account: the suite rows that need none', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final engine = FakeClockEngine();
    await tester.pumpWidget(testApp(engine, home: const AlarmsPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(ClockSettingsPage), findsOneWidget);

    // Nothing to sign out of, lock or delete: Clock rings without an account.
    for (final gone in [
      'Sign out',
      'Change password',
      'Auto-lock',
      'Lock now',
      'New recovery key',
      'Delete account',
      'Not signed in',
    ]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    // Language and theme stay, then Clock's own section, then About.
    final language = tester.getTopLeft(find.text('Language')).dy;
    final section = tester.getTopLeft(find.text('Zero-Trust Clock').first).dy;
    final check = tester.getTopLeft(find.text('Alarm check')).dy;
    final licences = tester.getTopLeft(find.text('Open-source licences')).dy;
    expect(language, lessThan(section));
    expect(section, lessThan(check));
    expect(check, lessThan(licences));
    expect(find.text('What can stop an alarm on this phone'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);

    await tester.tap(find.text('Alarm check'));
    await tester.pumpAndSettle();
    expect(find.byType(AlarmCheckPage), findsOneWidget);
    expect(find.text('Everything looks right'), findsOneWidget);
  });

  testWidgets('the app tells the engine its language, also when it changes', (
    tester,
  ) async {
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {1}),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockEngineProvider.overrideWithValue(engine),
          ztAppConfigProvider.overrideWithValue(clockAppConfig),
          ztPreferencesStoreProvider.overrideWithValue(
            InMemoryPreferencesStore(),
          ),
          accountServiceProvider.overrideWithValue(
            AccountService(SignedOutBackend()),
          ),
        ],
        child: const ZeroTrustClockApp(),
      ),
    );
    await tester.pumpAndSettle();
    // English until another language is picked.
    expect(engine.language, 'en');
    expect(find.text('Alarms'), findsOneWidget);
    expect(find.text('7:00 AM'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AlarmsPage)),
    );
    await container.read(ztLanguageProvider.notifier).set(const Locale('he'));
    await tester.pumpAndSettle();
    expect(engine.language, 'he');
    expect(find.text('שעונים מעוררים'), findsOneWidget);

    // "Phone language": the ring screen follows the phone too.
    await container.read(ztLanguageProvider.notifier).set(null);
    await tester.pumpAndSettle();
    expect(engine.language, isNull);
  });
}
