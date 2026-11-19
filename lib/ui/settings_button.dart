import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'settings_page.dart';

/// The Settings button every tab has in its top bar.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.settings,
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const ClockSettingsPage())),
  );
}
