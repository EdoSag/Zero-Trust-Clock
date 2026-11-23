import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../linked/linked_apps.dart';
import '../time_log/time_log.dart';
import 'edition.dart';
import 'email_links.dart';

/// Every Supabase auth event (sign-in, sign-out, password-recovery link).
/// Empty when the account could not be set up (no network config): Clock
/// then simply runs without one.
final authChangesProvider = StreamProvider<AuthState>((ref) {
  if (ref.watch(offlineEditionProvider)) return const Stream.empty();
  try {
    return Supabase.instance.client.auth.onAuthStateChange;
  } on Object {
    return const Stream.empty();
  }
});

/// Whether someone is signed in. Signing in only adds backup and sync:
/// the alarms work the same without it.
final signedInProvider = Provider<bool>((ref) {
  if (ref.watch(offlineEditionProvider)) return false;
  ref.watch(authChangesProvider);
  try {
    return ref.watch(accountServiceProvider).currentUserId != null;
  } on Object {
    return false;
  }
});

/// True after the user opens a "reset password" email link, until they
/// finish `ZtResetPasswordScreen`.
final passwordRecoveryProvider = NotifierProvider<PasswordRecovery, bool>(
  PasswordRecovery.new,
);

class PasswordRecovery extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(authChangesProvider, (_, next) {
      if (next.value?.event == AuthChangeEvent.passwordRecovery) {
        EmailLinks.takeRecovery();
        state = true;
      }
    });
    // Opened from the link: the sign-in may have happened before this
    // listened.
    return EmailLinks.takeRecovery();
  }

  void done() {
    EmailLinks.takeRecovery();
    state = false;
  }
}

/// A sign-in that still has to show its new recovery key (new account, or
/// a password reset) before the vault opens.
final pendingRecoveryKeyProvider =
    NotifierProvider<PendingRecoveryKey, UnlockResult?>(PendingRecoveryKey.new);

class PendingRecoveryKey extends Notifier<UnlockResult?> {
  @override
  UnlockResult? build() => null;

  void set(UnlockResult? result) => state = result;

  /// Zeroes a key still waiting (the app left the screen).
  void drop() {
    final pending = state;
    if (pending == null) return;
    pending.dek.fillRange(0, pending.dek.length, 0);
    state = null;
  }
}

/// Opens the vault after a sign-in or unlock, or first shows the new
/// recovery key when there is one.
void openVault(WidgetRef ref, UnlockResult result) {
  if (result.newRecoveryKey != null) {
    ref.read(pendingRecoveryKeyProvider.notifier).set(result);
    return;
  }
  unlockVault(ref, result.dek, legacyDek: result.legacyDek);
}

/// Opens the vault with the account key. While the key is at hand, Clock
/// also derives ZT Time's key, for "Log to ZT Time", and the keys of the
/// apps it reads for the day ahead (ZT Calendar, ZT Tasks, ZT Quests).
void unlockVault(WidgetRef ref, Uint8List dek, {required bool legacyDek}) {
  final copy = Uint8List.fromList(dek);
  ref
      .read(timeKeyProvider.notifier)
      .deriveFrom(copy)
      .catchError((Object _) {})
      .whenComplete(() => copy.fillRange(0, copy.length, 0));
  final linked = Uint8List.fromList(dek);
  ref
      .read(linkedKeysProvider.notifier)
      .deriveFrom(linked)
      .catchError((Object _) {})
      .whenComplete(() => linked.fillRange(0, linked.length, 0));
  ref.read(vaultControllerProvider.notifier).unlock(dek, legacyDek: legacyDek);
}

void openForgotPassword(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) =>
        ZtForgotPasswordScreen(redirectTo: EmailLinks.passwordReset),
  ),
);

/// The shared sign-in screen, opened from Settings. Back returns to the
/// app as it was; signing in returns to the alarms, now backed up.
class ClockSignInPage extends ConsumerWidget {
  const ClockSignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Stack(
    children: [
      ZtSignInScreen(
        emailRedirectTo: EmailLinks.confirmed,
        onForgotPassword: () => openForgotPassword(context),
        onUnlocked: (result) {
          openVault(ref, result);
          Navigator.of(context).popUntil((r) => r.isFirst);
        },
      ),
      // The shared screen has no way back; here it is optional.
      const SafeArea(
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: 4, top: 4),
          child: Material(type: MaterialType.transparency, child: BackButton()),
        ),
      ),
    ],
  );
}
