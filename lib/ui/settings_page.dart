import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../app/account.dart';
import '../engine/clock_engine.dart';
import '../l10n/l10n.dart';
import 'alarm_check_page.dart';
import 'holidays_page.dart';

/// The suite's settings screen. Clock works without an account, so with
/// nobody signed in it shows what needs none (language, theme, the app's
/// own rows, About) and "Sign in or create account" for encrypted backup
/// and sync. Signed in, it is the full account section with sync status.
class ClockSettingsPage extends ConsumerWidget {
  const ClockSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final night = ref.watch(screensaverNightProvider).value ?? true;
    return ZtSettingsPage(
      accountOptional: true,
      showSyncStatus: true,
      onSignIn: () => Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const ClockSignInPage())),
      onSignedOut: () => Navigator.of(context).popUntil((r) => r.isFirst),
      onOpenUrl: (url) => launchUrl(url, mode: LaunchMode.externalApplication),
      privacyPolicyUrl: Uri.parse('https://zerotrust.bz/privacy'),
      termsUrl: Uri.parse('https://zerotrust.bz/terms'),
      supportUrl: Uri.parse('https://zerotrust.bz/support'),
      appSection: [
        ListTile(
          leading: const Icon(Icons.fact_check_outlined),
          title: Text(l.alarmCheck),
          subtitle: Text(l.alarmCheckSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const AlarmCheckPage()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.beach_access_outlined),
          title: Text(l.publicHolidays),
          subtitle: Text(l.publicHolidaysHint),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(
            context,
          ).push<void>(MaterialPageRoute(builder: (_) => const HolidaysPage())),
        ),
        ListTile(
          leading: const Icon(Icons.nightlight_outlined),
          title: Text(l.screensaver),
          subtitle: Text(l.screensaverHint),
          trailing: const Icon(Icons.open_in_new),
          onTap: () =>
              ref.read(clockEngineProvider).openSettings('screensaver'),
        ),
        SwitchListTile(
          key: const ValueKey('screensaverNight'),
          secondary: const Icon(Icons.dark_mode_outlined),
          title: Text(l.screensaverNight),
          subtitle: Text(l.screensaverNightHint),
          value: night,
          onChanged: (on) =>
              ref.read(screensaverNightProvider.notifier).set(on),
        ),
      ],
    );
  }
}
