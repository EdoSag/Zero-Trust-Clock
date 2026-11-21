import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../app/account.dart';
import '../app/edition.dart';
import '../engine/clock_engine.dart';
import '../l10n/l10n.dart';
import '../world/world_cities.dart';
import '../world/world_zone.dart';
import 'alarm_check_page.dart';
import 'holidays_page.dart';
import 'world_clock_page.dart';

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
    final ring = ref.watch(ringSettingsProvider).value ?? const RingSettings();
    final offline = ref.watch(offlineEditionProvider);
    final homeId = ref.watch(homeZoneProvider).value;
    final home = ref.watch(homeZoneInfoProvider).value;
    return ZtSettingsPage(
      accountOptional: true,
      showSyncStatus: true,
      // The Offline edition has no account to sign in to.
      onSignIn: offline
          ? null
          : () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const ClockSignInPage()),
            ),
      onSignedOut: () => Navigator.of(context).popUntil((r) => r.isFirst),
      onOpenUrl: (url) => launchUrl(url, mode: LaunchMode.externalApplication),
      privacyPolicyUrl: Uri.parse('https://zerotrust.bz/privacy'),
      termsUrl: Uri.parse('https://zerotrust.bz/terms'),
      supportUrl: Uri.parse('https://zerotrust.bz/support'),
      appSection: [
        if (offline)
          ListTile(
            key: const ValueKey('offlineEdition'),
            leading: const Icon(Icons.cloud_off_outlined),
            title: Text(l.offlineEdition),
            subtitle: Text(l.offlineEditionHint),
          ),
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
          key: const ValueKey('volumeButtons'),
          leading: const Icon(Icons.volume_up_outlined),
          title: Text(l.volumeButtons),
          subtitle: Text(volumeButtonsText(l, ring.volumeButtons)),
          onTap: () async {
            final picked = await chooseOne<VolumeButtons>(
              context,
              title: l.volumeButtons,
              about: l.volumeButtonsAbout,
              current: ring.volumeButtons,
              choices: [
                for (final v in VolumeButtons.values)
                  (v, volumeButtonsText(l, v)),
              ],
            );
            if (picked == null) return;
            await ref
                .read(ringSettingsProvider.notifier)
                .set(ring.copyWith(volumeButtons: picked));
          },
        ),
        ListTile(
          key: const ValueKey('minVolume'),
          leading: const Icon(Icons.notifications_active_outlined),
          title: Text(l.minVolume),
          subtitle: Text(minVolumeText(l, ring.minVolume)),
          onTap: () async {
            final picked = await chooseOne<int>(
              context,
              title: l.minVolume,
              about: l.minVolumeAbout,
              current: ring.minVolume,
              choices: [
                for (final p in RingSettings.minVolumeChoices)
                  (p, minVolumeText(l, p)),
              ],
            );
            if (picked == null) return;
            await ref
                .read(ringSettingsProvider.notifier)
                .set(ring.copyWith(minVolume: picked));
          },
        ),
        ListTile(
          key: const ValueKey('homeZone'),
          leading: const Icon(Icons.home_outlined),
          title: Text(l.homeTimeZone),
          subtitle: Text(
            homeId == null
                ? l.homeTimeZoneOff
                : l.homeTimeZoneOn(home?.city ?? homeId),
          ),
          onTap: () => _pickHome(context, ref, homeId),
        ),
        // Holiday calendars are downloaded, so not in the Offline edition.
        if (!offline)
          ListTile(
            leading: const Icon(Icons.beach_access_outlined),
            title: Text(l.publicHolidays),
            subtitle: Text(l.publicHolidaysHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const HolidaysPage()),
            ),
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

/// What the home sheet answers: a zone id, or "off".
const _homeOff = 'off';
const _homePick = 'pick';

/// "Home time zone": this phone's zone now, any city, or off.
Future<void> _pickHome(
  BuildContext context,
  WidgetRef ref,
  String? current,
) async {
  final l = context.l10n;
  WorldZone? here;
  try {
    here = await ref.read(localZoneProvider.future);
  } on Object {
    here = null;
  }
  if (!context.mounted) return;
  final navigator = Navigator.of(context);
  final picked = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: Text(
                l.homeTimeZone,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (here != null)
              ListTile(
                key: const ValueKey('homeHere'),
                leading: const Icon(Icons.my_location),
                title: Text(l.homeHere(here.city)),
                selected: current == here.id,
                onTap: () => Navigator.of(context).pop(here!.id),
              ),
            ListTile(
              key: const ValueKey('homePick'),
              leading: const Icon(Icons.search),
              title: Text(l.homePickCity),
              onTap: () => Navigator.of(context).pop(_homePick),
            ),
            if (current != null)
              ListTile(
                key: const ValueKey('homeOff'),
                leading: const Icon(Icons.block),
                title: Text(l.off),
                onTap: () => Navigator.of(context).pop(_homeOff),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
              child: Text(
                l.homeTimeZoneAbout,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (picked == null) return;
  var id = picked == _homeOff ? null : picked;
  if (picked == _homePick) {
    id = await navigator.push<String>(
      MaterialPageRoute(builder: (_) => const CityPickerPage(forHome: true)),
    );
    if (id == null) return;
  }
  await ref.read(homeZoneProvider.notifier).set(id);
}

String volumeButtonsText(AppL10n l, VolumeButtons v) => switch (v) {
  VolumeButtons.volume => l.volumeButtonsVolume,
  VolumeButtons.snooze => l.snooze,
  VolumeButtons.dismiss => l.dismiss,
};

String minVolumeText(AppL10n l, int percent) =>
    percent <= 0 ? l.minVolumeOff : l.minVolumePercent(percent);

/// A short list to pick one of, from the bottom: the current one is
/// ticked. Null when closed without picking.
Future<T?> chooseOne<T>(
  BuildContext context, {
  required String title,
  required String about,
  required T current,
  required List<(T, String)> choices,
}) => showModalBottomSheet<T>(
  context: context,
  showDragHandle: true,
  // Scrolls on a small phone or with large text.
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final (value, text) in choices)
            ListTile(
              leading: Icon(
                value == current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: value == current
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(text),
              selected: value == current,
              onTap: () => Navigator.of(context).pop(value),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
            child: Text(about, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    ),
  ),
);
