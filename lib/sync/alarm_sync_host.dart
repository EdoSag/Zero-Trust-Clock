import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../engine/clock_engine.dart';
import '../l10n/l10n.dart';
import '../ui/alarm_text.dart';
import 'alarm_sync.dart';

final deletedAlarmsProvider = Provider<DeletedAlarms>(
  (ref) => DeletedAlarms(ref.watch(ztPreferencesStoreProvider)),
);

/// The account's copy of the alarms while the vault is open; null signed
/// out or locked. Tests override it.
final alarmVaultProvider = FutureProvider<AlarmVault?>((ref) async {
  final open = ref.watch(
    vaultControllerProvider.select((s) => s is VaultUnlocked),
  );
  if (!open) return null;
  final store = await ref.watch(ztLocalStoreProvider.future);
  return StoreAlarmVault(store, ref.read(ztSyncControllerProvider.notifier));
});

/// Sync between this phone's alarms and the account; null when there is no
/// open account.
final alarmSyncProvider = FutureProvider<AlarmSync?>((ref) async {
  final vault = await ref.watch(alarmVaultProvider.future);
  if (vault == null) return null;
  return AlarmSync(
    engine: ref.watch(clockEngineProvider),
    vault: vault,
    deleted: ref.watch(deletedAlarmsProvider),
    device: await ref.watch(ztDeviceIdProvider.future),
  );
});

/// Keeps the alarms and the account in step while the account is open:
/// after every change on this phone, and whenever another phone's change
/// arrives. Without an account it does nothing.
class AlarmSyncHost extends ConsumerStatefulWidget {
  const AlarmSyncHost({super.key, required this.child});

  final Widget child;

  /// How long changes are gathered before a round runs.
  static const delay = Duration(milliseconds: 800);

  @override
  ConsumerState<AlarmSyncHost> createState() => _AlarmSyncHostState();
}

class _AlarmSyncHostState extends ConsumerState<AlarmSyncHost> {
  Timer? _soon;
  StreamSubscription<void>? _vaultChanges;
  ProviderSubscription<AsyncValue<AlarmSync?>>? _sync;

  @override
  void initState() {
    super.initState();
    _sync = ref.listenManual(alarmSyncProvider, (_, next) {
      _vaultChanges?.cancel();
      _vaultChanges = next.value?.vault.changes.listen((_) => _schedule());
      _schedule();
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _soon?.cancel();
    _vaultChanges?.cancel();
    _sync?.close();
    super.dispose();
  }

  void _schedule() {
    _soon?.cancel();
    _soon = Timer(AlarmSyncHost.delay, _run);
  }

  Future<void> _run() async {
    if (!mounted) return;
    final sync = ref.read(alarmSyncProvider).value;
    if (sync == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final result = await sync.run();
      if (!mounted || !result.engineChanged) return;
      final text = context.l10n.alarmsAdded(result.added);
      await ref.read(alarmsProvider.notifier).refresh();
      if (result.added > 0 && messenger != null) showSnack(messenger, text);
    } on Object {
      // Locked mid-round, or offline: the next change or unlock retries.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Runs the account's sync (pull, push, live changes) while it is open.
    ref.watch(ztSyncControllerProvider);
    ref.listen(alarmsProvider, (_, _) => _schedule());
    return widget.child;
  }
}
