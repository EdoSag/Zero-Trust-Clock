import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/alarm.dart';
import '../engine/clock_engine.dart';
import '../l10n/l10n.dart';
import 'alarm_text.dart';

/// Everything on this phone that can stop an alarm, each with its fix,
/// and two test alarms to see for yourself: one in ten seconds, one that
/// should survive a restart.
class AlarmCheckPage extends ConsumerStatefulWidget {
  const AlarmCheckPage({super.key});

  @override
  ConsumerState<AlarmCheckPage> createState() => _AlarmCheckPageState();
}

class _AlarmCheckPageState extends ConsumerState<AlarmCheckPage>
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from a system settings screen: read everything again.
    if (state == AppLifecycleState.resumed) ref.invalidate(alarmCheckProvider);
  }

  ClockEngine get _engine => ref.read(clockEngineProvider);

  Future<void> _open(String which) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      await _engine.openSettings(which);
    } on Object {
      showSnack(messenger, l.couldNotSave);
    }
  }

  Future<void> _fixNotifications() async {
    var granted = false;
    try {
      granted = await _engine.requestNotifications();
    } on Object {
      granted = false;
    }
    // Android stops asking after two refusals; its settings still work.
    if (!granted) await _open('notifications');
    ref.invalidate(alarmCheckProvider);
  }

  Future<void> _test(int seconds, String said) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      await _engine.testAlarm(seconds);
      showSnack(messenger, said);
    } on Object {
      showSnack(messenger, l.couldNotSave);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final check = ref.watch(alarmCheckProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.alarmCheck)),
      body: SafeArea(
        child: check.when(
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(l.couldNotSave)),
          data: (c) => ListView(
            padding: const EdgeInsetsDirectional.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                child: Text(
                  l.alarmCheckIntro,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              _Summary(problems: c.problems),
              _CheckRow(
                title: l.checkNotifications,
                ok: c.notifications,
                status: c.notifications
                    ? l.checkNotificationsOk
                    : l.checkNotificationsBad,
                onFix: _fixNotifications,
              ),
              // With notifications off this one cannot be read or fixed.
              if (c.notifications)
                _CheckRow(
                  title: l.checkRingChannel,
                  ok: c.ringChannel,
                  status: c.ringChannel
                      ? l.checkRingChannelOk
                      : l.checkRingChannelBad,
                  onFix: () => _open('ringChannel'),
                ),
              _CheckRow(
                title: l.checkFullScreen,
                ok: c.fullScreen,
                status: c.fullScreen
                    ? l.checkFullScreenOk
                    : l.checkFullScreenBad,
                onFix: () => _open('fullScreen'),
              ),
              _CheckRow(
                title: l.checkExact,
                ok: c.exactAlarms,
                status: c.exactAlarms ? l.checkExactOk : l.checkExactBad,
                onFix: () => _open('exactAlarms'),
              ),
              _CheckRow(
                title: l.checkVolume,
                ok: !c.volumeZero,
                status: c.volumeZero
                    ? l.checkVolumeBad
                    : l.checkVolumeOk(c.alarmVolume, c.alarmVolumeMax),
                onFix: () => _open('sound'),
              ),
              _CheckRow(
                title: l.checkSilence,
                ok: !c.totalSilence,
                status: c.totalSilence ? l.checkSilenceBad : l.checkSilenceOk,
                onFix: () => _open('doNotDisturb'),
              ),
              _CheckRow(
                title: l.checkProfile,
                ok: c.ownerProfile,
                status: c.ownerProfile ? l.checkProfileOk : l.checkProfileBad,
              ),
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: Text(l.checkRestart),
                subtitle: Text(_restartText(context, c)),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
                child: Text(
                  l.tryIt,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.alarm_on),
                title: Text(l.testIn10),
                subtitle: Text(l.testIn10Hint),
                onTap: () => _test(10, l.testStarted),
              ),
              ListTile(
                leading: const Icon(Icons.phonelink_lock),
                title: Text(l.restartTest),
                subtitle: Text(l.restartTestHint),
                onTap: () => _test(180, l.restartTestStarted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _restartText(BuildContext context, AlarmCheck c) {
    final l = context.l10n;
    final at = c.bootAt;
    if (at == null) return l.checkRestartNever;
    final when = '${dayText(context, at)}, ${clockText(context, at)}';
    return c.bootLocked
        ? l.checkRestartLocked(when)
        : l.checkRestartUnlocked(when);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.problems});

  final int problems;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final good = problems == 0;
    return Card(
      color: good ? colors.secondaryContainer : colors.errorContainer,
      margin: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
      child: ListTile(
        leading: Icon(
          good ? Icons.check_circle_outline : Icons.warning_amber,
          color: good ? colors.onSecondaryContainer : colors.onErrorContainer,
        ),
        title: Text(
          good ? l.allGood : l.mayNotRing,
          style: TextStyle(
            color: good ? colors.onSecondaryContainer : colors.onErrorContainer,
          ),
        ),
        subtitle: good
            ? null
            : Text(
                l.mayNotRingHint(problems),
                style: TextStyle(color: colors.onErrorContainer),
              ),
      ),
    );
  }
}

/// One thing that was checked: fine, or what is wrong and a Fix button.
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.title,
    required this.ok,
    required this.status,
    this.onFix,
  });

  final String title;
  final bool ok;
  final String status;

  /// Opens the system screen that fixes it. Null: nothing the app can open.
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        ok ? Icons.check_circle : Icons.error,
        color: ok ? colors.primary : colors.error,
      ),
      title: Text(title),
      subtitle: Text(status),
      trailing: ok || onFix == null
          ? null
          : TextButton(onPressed: onFix, child: Text(l.fix)),
    );
  }
}
