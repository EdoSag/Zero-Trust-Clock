import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../sync/alarm_sync_host.dart';
import '../ui/alarms_page.dart';
import 'account.dart';

/// What the app opens on. Unlike the other apps, Clock needs no account:
/// signed out it goes straight to the alarms. Signed in (from Settings) it
/// adds encrypted backup and sync, and then, like every Zero-Trust app,
/// asks to unlock after a cold start or auto-lock. The alarms ring either
/// way: they are in the engine, not behind the lock.
class ClockGate extends ConsumerStatefulWidget {
  const ClockGate({super.key, this.home = const AlarmsPage()});

  /// The alarms screen; tests pass their own.
  final Widget home;

  @override
  ConsumerState<ClockGate> createState() => _ClockGateState();
}

class _ClockGateState extends ConsumerState<ClockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A key still waiting behind the recovery-key screen is zeroed when the
  /// app leaves the foreground, so coming back asks for the password.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(pendingRecoveryKeyProvider.notifier).drop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(vaultControllerProvider, (prev, next) {
      // Auto-lock: don't leave a page (settings, an alarm) open over it.
      if (prev is VaultUnlocked && next is VaultLocked) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });
    ref.listen(signedInProvider, (was, now) {
      if (was == true && !now) {
        ref.read(vaultControllerProvider.notifier).lock();
      }
    });

    final pending = ref.watch(pendingRecoveryKeyProvider);
    if (pending != null) {
      return ZtRecoveryKeyScreen(
        recoveryKey: pending.newRecoveryKey!,
        onDone: () {
          ref.read(pendingRecoveryKeyProvider.notifier).set(null);
          ref
              .read(vaultControllerProvider.notifier)
              .unlock(pending.dek, legacyDek: pending.legacyDek);
        },
      );
    }

    if (ref.watch(passwordRecoveryProvider)) {
      return ZtResetPasswordScreen(
        onUnlocked: (result) {
          ref.read(passwordRecoveryProvider.notifier).done();
          openVault(ref, result);
        },
      );
    }

    final signedIn = ref.watch(signedInProvider);
    if (signedIn && ref.watch(vaultControllerProvider) is VaultLocked) {
      final account = ref.read(accountServiceProvider);
      return ZtUnlockScreen(
        email: account.currentEmail,
        onUnlocked: (result) => openVault(ref, result),
        onSignOut: () => account.signOut(),
        onForgotPassword: () => openForgotPassword(context),
      );
    }

    return AlarmSyncHost(child: widget.home);
  }
}
