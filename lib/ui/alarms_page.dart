import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/alarm.dart';
import '../engine/clock_engine.dart';
import '../sync/alarm_sync_host.dart';
import '../l10n/l10n.dart';
import 'alarm_card.dart';
import 'alarm_check_page.dart';
import 'alarm_editor.dart';
import 'alarm_text.dart';
import 'settings_page.dart';

/// The home screen: every alarm, with the switch and "Turn off once".
class AlarmsPage extends ConsumerStatefulWidget {
  const AlarmsPage({super.key});

  @override
  ConsumerState<AlarmsPage> createState() => _AlarmsPageState();
}

class _AlarmsPageState extends ConsumerState<AlarmsPage>
    with WidgetsBindingObserver {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // "Off once" and "Tomorrow" change with the clock, not with a tap.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      ref.invalidate(alarmCheckProvider);
    }
  }

  ClockEngine get _engine => ref.read(clockEngineProvider);

  Future<void> _refresh() => ref.read(alarmsProvider.notifier).refresh();

  /// Runs one change in the engine, then shows the list as it now is.
  /// Returns false (and says so) when the engine refused.
  Future<bool> _change(Future<void> Function() work) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      await work();
      await _refresh();
      return true;
    } on Object {
      showSnack(messenger, l.couldNotSave);
      return false;
    }
  }

  ClockAlarm? _find(String id) {
    for (final a in ref.read(alarmsProvider).value ?? const <ClockAlarm>[]) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// "Rings in 7 h 30 min" for the alarm as the engine now has it.
  void _sayRingsIn(ScaffoldMessengerState messenger, AppL10n l, String id) {
    final next = _find(id)?.nextRing;
    if (next == null) return;
    showSnack(messenger, ringsInText(l, next.difference(DateTime.now())));
  }

  Future<void> _add() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    String? id;
    final ok = await _change(() async {
      id = await _engine.save(hour: picked.hour, minute: picked.minute);
    });
    if (!ok || id == null) return;
    _sayRingsIn(messenger, l, id!);
    // Android 13 and later ask before an app may show notifications, and
    // the alarm screen is one. Asked with the first alarm, not at start.
    try {
      await _engine.requestNotifications();
    } on Object {
      // The Alarm check screen shows it and offers the fix.
    }
    ref.invalidate(alarmCheckProvider);
  }

  Future<void> _toggle(ClockAlarm alarm, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final hadNextRing = alarm.enabled && alarm.nextRing != null;
    if (!await _change(() => _engine.setEnabled(alarm.id, on))) return;
    if (on) {
      _sayRingsIn(messenger, l, alarm.id);
    } else if (hadNextRing) {
      // The switch turns it off for good. One tap makes it "just once".
      showSnack(
        messenger,
        l.alarmOff,
        actionLabel: l.justOnce,
        onAction: () async {
          await _change(() async {
            await _engine.setEnabled(alarm.id, true);
            await _engine.skipOnce(alarm.id);
          });
        },
      );
    }
  }

  Future<void> _skipOnce(ClockAlarm alarm) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    if (!await _change(() => _engine.skipOnce(alarm.id))) return;
    if (!mounted) return;
    final next = _find(alarm.id)?.nextRing;
    showSnack(
      messenger,
      next == null ? l.offOnce : l.offOnceNext(dayText(context, next)),
      actionLabel: l.undo,
      onAction: () => _change(() => _engine.undoSkip(alarm.id)),
    );
  }

  /// A day from tomorrow on, for "Pause until".
  Future<DateTime?> _pickPauseDay(DateTime? current) {
    final today = DateUtils.dateOnly(DateTime.now());
    return showDatePicker(
      context: context,
      initialDate: current ?? today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 366)),
      helpText: context.l10n.pauseUntilHelp,
    );
  }

  Future<void> _pause(ClockAlarm alarm) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final day = await _pickPauseDay(null);
    if (day == null || !mounted) return;
    if (!await _change(() => _engine.pause(alarm.id, day))) return;
    if (!mounted) return;
    showSnack(
      messenger,
      l.pausedUntil(dayText(context, day)),
      actionLabel: l.undo,
      onAction: () => _change(() => _engine.resume(alarm.id)),
    );
  }

  Future<void> _pauseAll() async {
    final current = ref.read(pauseAllProvider).value;
    final day = await _pickPauseDay(current);
    if (day == null || !mounted) return;
    await _change(() => _engine.setPauseAll(day));
    ref.invalidate(pauseAllProvider);
  }

  Future<void> _resumeAll() async {
    await _change(() => _engine.setPauseAll(null));
    ref.invalidate(pauseAllProvider);
  }

  Future<void> _delete(ClockAlarm alarm) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    // Noted first, so a sync round in between can't bring it back.
    try {
      await ref.read(deletedAlarmsProvider).add(alarm.id);
    } on Object {
      // Without the note it may come back from the account; still delete.
    }
    if (!await _change(() => _engine.delete(alarm.id))) return;
    showSnack(
      messenger,
      l.alarmDeleted,
      actionLabel: l.undo,
      onAction: () => _change(() async {
        final id = await _engine.save(
          hour: alarm.hour,
          minute: alarm.minute,
          days: alarm.days,
          label: alarm.label,
          vibrate: alarm.vibrate,
          snoozeMinutes: alarm.snoozeMinutes,
        );
        if (!alarm.enabled) await _engine.setEnabled(id, false);
      }),
    );
  }

  Future<void> _edit(ClockAlarm alarm) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final result = await Navigator.of(context).push<AlarmEditorResult>(
      MaterialPageRoute(builder: (_) => AlarmEditorPage(alarm: alarm)),
    );
    if (!mounted) return;
    switch (result) {
      case AlarmEditorResult.saved:
        await _refresh();
        _sayRingsIn(messenger, l, alarm.id);
      case AlarmEditorResult.delete:
        await _delete(alarm);
      case null:
        break;
    }
  }

  void _openCheck() => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => const AlarmCheckPage()));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final alarms = ref.watch(alarmsProvider);
    final problems = ref.watch(alarmCheckProvider).value?.problems ?? 0;
    final pausedAll = ref.watch(pauseAllProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.alarms),
        actions: [
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const ClockSettingsPage()),
            ),
          ),
          PopupMenuButton<bool>(
            tooltip: l.moreOptions,
            onSelected: (pause) => pause ? _pauseAll() : _resumeAll(),
            itemBuilder: (context) => [
              PopupMenuItem(value: true, child: Text(l.pauseAll)),
              if (pausedAll != null)
                PopupMenuItem(value: false, child: Text(l.resumeAll)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l.addAlarm,
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: alarms.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(l.couldNotSave)),
          data: (list) {
            final ringing = list.where((a) => a.ringing).firstOrNull;
            return ListView(
              // Room under the last card for the + button.
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 96),
              children: [
                if (ringing != null)
                  _RingingBanner(
                    alarm: ringing,
                    onSnooze: () => _change(_engine.ringSnooze),
                    onDismiss: () => _change(_engine.ringDismiss),
                  ),
                if (problems > 0)
                  _MayNotRingCard(problems: problems, onOpen: _openCheck),
                if (pausedAll != null)
                  _PausedAllCard(until: pausedAll, onResume: _resumeAll),
                if (list.isEmpty) const _NoAlarms(),
                for (final alarm in list)
                  AlarmCard(
                    key: ValueKey(alarm.id),
                    alarm: alarm,
                    onToggle: (on) => _toggle(alarm, on),
                    onSkipOnce: () => _skipOnce(alarm),
                    onUndoSkip: () => _change(() => _engine.undoSkip(alarm.id)),
                    onCancelSnooze: () =>
                        _change(() => _engine.cancelSnooze(alarm.id)),
                    onEdit: () => _edit(alarm),
                    onDelete: () => _delete(alarm),
                    onPause: () => _pause(alarm),
                    onResume: () => _change(() => _engine.resume(alarm.id)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Repeating alarms are paused until ...", with Resume.
class _PausedAllCard extends StatelessWidget {
  const _PausedAllCard({required this.until, required this.onResume});

  final DateTime until;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      color: colors.secondaryContainer,
      margin: const EdgeInsetsDirectional.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pause_circle_outline,
                  color: colors.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.pausedAllUntil(dayText(context, until)),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(onPressed: onResume, child: Text(l.resume)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoAlarms extends StatelessWidget {
  const _NoAlarms();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 96),
      child: Column(
        children: [
          Icon(Icons.alarm, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(l.noAlarms, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            l.noAlarmsHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown while an alarm rings with the app open.
class _RingingBanner extends StatelessWidget {
  const _RingingBanner({
    required this.alarm,
    required this.onSnooze,
    required this.onDismiss,
  });

  final ClockAlarm alarm;
  final VoidCallback onSnooze;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      color: colors.primaryContainer,
      margin: const EdgeInsetsDirectional.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    [
                      l.ringingNow,
                      if (alarm.label.isNotEmpty) alarm.label,
                    ].join(' · '),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSnooze,
                    child: Text(l.snooze),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    // The suite theme makes filled buttons full width,
                    // which a row cannot lay out.
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: onDismiss,
                    child: Text(l.dismiss),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Something on the phone can stop alarms: say so where alarms are set.
class _MayNotRingCard extends StatelessWidget {
  const _MayNotRingCard({required this.problems, required this.onOpen});

  final int problems;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      color: colors.errorContainer,
      margin: const EdgeInsetsDirectional.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, color: colors.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.mayNotRing,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.onErrorContainer,
                        ),
                      ),
                      Text(
                        l.mayNotRingHint(problems),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: colors.onErrorContainer,
                ),
                onPressed: onOpen,
                child: Text(l.openAlarmCheck),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
