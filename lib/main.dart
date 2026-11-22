import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import 'app/clock_config.dart';
import 'app/clock_gate.dart';
import 'app/edition.dart';
import 'app/email_links.dart';
import 'engine/clock_engine.dart';
import 'l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The Zero-Trust account is optional here: alarms live on the phone and
  // ring without it. Signing in (Settings) adds encrypted backup and sync.
  // A failure here must not keep the alarms away.
  // The Offline edition has no INTERNET permission and no account at all.
  if (!offlineEdition) {
    try {
      await dotenv.load(fileName: '.env');
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL']!,
        publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
      );
      unawaited(EmailLinks.listen());
    } on Object catch (e) {
      debugPrint('Account setup failed: $e');
    }
  }
  // English or Hebrew, as picked in Settings, from the first frame.
  await ZtLanguageController.preload();
  runApp(
    ProviderScope(
      overrides: [
        ztAppConfigProvider.overrideWithValue(clockAppConfig),
        if (offlineEdition)
          accountServiceProvider.overrideWithValue(
            AccountService(const NoAccountBackend()),
          ),
      ],
      child: const ZeroTrustClockApp(),
    ),
  );
}

class ZeroTrustClockApp extends ConsumerStatefulWidget {
  const ZeroTrustClockApp({super.key, this.home = const ClockGate()});

  final Widget home;

  @override
  ConsumerState<ZeroTrustClockApp> createState() => _ZeroTrustClockAppState();
}

class _ZeroTrustClockAppState extends ConsumerState<ZeroTrustClockApp> {
  @override
  void initState() {
    super.initState();
    _tellEngine(ref.read(ztLanguageProvider));
  }

  /// The ring screen and the notifications are native, so the engine has
  /// to know the app's language too.
  void _tellEngine(Locale? language) {
    ref
        .read(clockEngineProvider)
        .setLanguage(language?.languageCode)
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ztLanguageProvider, (_, next) => _tellEngine(next));
    return ZtThemeBuilder(
      builder: (context, theme, darkTheme, mode) => MaterialApp(
        // On-device task switcher label; the store name is Zero-Trust Clock.
        title: 'ZT Clock',
        theme: theme,
        darkTheme: darkTheme,
        themeMode: mode,
        // English (default) or Hebrew, from Settings → Appearance → Language.
        locale: ref.watch(ztLanguageProvider),
        supportedLocales: ZtLanguages.supported,
        localizationsDelegates: const [
          AppL10n.delegate,
          ...ZtLanguages.delegates,
        ],
        home: widget.home,
        // Any touch on any screen counts as activity for auto-lock.
        builder: (context, child) => Listener(
          onPointerDown: (_) =>
              ref.read(vaultControllerProvider.notifier).touch(),
          child: child,
        ),
      ),
    );
  }
}
