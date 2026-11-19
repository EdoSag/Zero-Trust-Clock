import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_clock/app/clock_config.dart';
import 'package:zerotrust_clock/engine/clock_engine.dart';
import 'package:zerotrust_clock/l10n/l10n.dart';
import 'package:zerotrust_clock/ui/alarms_page.dart';

import 'fake_engine.dart';

/// Nobody is signed in, which is how Clock starts.
class SignedOutBackend implements AccountBackend {
  @override
  String? get currentUserId => null;
  @override
  String? get currentEmail => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const hebrew = Locale('he');

/// One screen inside the app's theme and languages, on the fake engine.
Widget testApp(
  FakeClockEngine engine, {
  Widget home = const AlarmsPage(),
  Locale? locale,
  double textScale = 1,
  List<Override> overrides = const [],
  PreferencesStore? prefs,
}) => ProviderScope(
  overrides: [
    ...overrides,
    clockEngineProvider.overrideWithValue(engine),
    ztAppConfigProvider.overrideWithValue(clockAppConfig),
    ztPreferencesStoreProvider.overrideWithValue(
      prefs ?? InMemoryPreferencesStore(),
    ),
    accountServiceProvider.overrideWithValue(
      AccountService(SignedOutBackend()),
    ),
  ],
  child: MaterialApp(
    theme: ZtTheme.light(accent: clockAppConfig.accent),
    locale: locale,
    supportedLocales: ZtLanguages.supported,
    localizationsDelegates: const [AppL10n.delegate, ...ZtLanguages.delegates],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  ),
);
