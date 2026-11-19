import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/clock_engine.dart';
import '../engine/clock_timer.dart';
import '../l10n/l10n.dart';
import '../time_log/time_log.dart';
import 'alarm_text.dart';
import 'clock_home.dart';
import 'duration_text.dart';
import 'log_time_sheet.dart';
import 'settings_button.dart';
import 'timer_keypad.dart';

/// The Timers tab: every timer, each with its buttons. With none, the
/// keypad to set one.
class TimersPage extends ConsumerStatefulWidget {
  const TimersPage({super.key});

  @override
  ConsumerState<TimersPage> createState() => _TimersPageState();
}

class _TimersPageState extends ConsumerState<TimersPage> {
  Timer? _tick;

  ClockEngine get _engine => ref.read(clockEngineProvider);

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Redraws the countdowns while one runs or rings.
  void _keepTicking(List<ClockTimer> timers) {
    final live = timers.any((t) => t.running || t.ringing);
    if (live && _tick == null) {
      _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
    } else if (!live && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
  }

  Future<void> _run(Future<void> Function() work) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      await work();
    } on Object {
      showSnack(messenger, l.couldNotSave);
    }
    await ref.read(timersProvider.notifier).refresh();
  }

  Future<void> _start(Duration length) async {
    await _run(() => _engine.addTimer(length));
    // A timer that ends with the app closed shows a notification.
    try {
      await _engine.requestNotifications();
    } on Object {
      // The Alarm check screen shows it.
    }
  }

  Future<void> _addAnother() async {
    final length = await Navigator.of(
      context,
    ).push<Duration>(MaterialPageRoute(builder: (_) => const NewTimerPage()));
    if (length != null && mounted) await _start(length);
  }

  Future<void> _editLabel(ClockTimer t) async {
    final label = await showDialog<String>(
      context: context,
      builder: (_) => _LabelDialog(label: t.label),
    );
    if (label == null || !mounted) return;
    await _run(() => _engine.setTimerLabel(t.id, label));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final timers = ref.watch(timersProvider);
    final list = timers.value ?? const <ClockTimer>[];
    _keepTicking(list);
    // "New timer" shortcut: with no timers the keypad is already here.
    onHomeAction(ref, HomeAction.newTimer, () {
      if ((ref.read(timersProvider).value ?? const []).isNotEmpty) {
        _addAnother();
      }
    });
    final now = DateTime.now();
    final logAvailable = ref.watch(timeLogProvider).available;
    return Scaffold(
      appBar: AppBar(title: Text(l.timers), actions: const [SettingsButton()]),
      floatingActionButton: list.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'addTimer',
              onPressed: _addAnother,
              icon: const Icon(Icons.add),
              label: Text(l.addTimer),
            ),
      body: SafeArea(
        child: timers.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(l.couldNotSave)),
          data: (list) => list.isEmpty
              ? TimerKeypad(onStart: _start)
              : ListView(
                  // Room under the last card for the add button.
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 96),
                  children: [
                    for (final t in list)
                      TimerCard(
                        key: ValueKey(t.id),
                        timer: t,
                        now: now,
                        onStart: () => _run(() => _engine.startTimer(t.id)),
                        onPause: () => _run(() => _engine.pauseTimer(t.id)),
                        onAddMinute: () =>
                            _run(() => _engine.addTimerMinute(t.id)),
                        onReset: () => _run(() => _engine.resetTimer(t.id)),
                        onStop: () => _run(_engine.stopRingingTimers),
                        onDelete: () => _run(() => _engine.deleteTimer(t.id)),
                        onLabel: () => _editLabel(t),
                        onLog: logAvailable
                            ? () {
                                // The sound stops first; the sheet is quiet.
                                _run(_engine.stopRingingTimers);
                                LogTimeSheet.show(
                                  context,
                                  length: t.length,
                                  description: t.label,
                                );
                              }
                            : null,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// One timer: its name, the time left, a bar, and its buttons.
class TimerCard extends StatelessWidget {
  const TimerCard({
    super.key,
    required this.timer,
    required this.now,
    required this.onStart,
    required this.onPause,
    required this.onAddMinute,
    required this.onReset,
    required this.onStop,
    required this.onDelete,
    required this.onLabel,
    this.onLog,
  });

  final ClockTimer timer;
  final DateTime now;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onAddMinute;
  final VoidCallback onReset;
  final VoidCallback onStop;
  final VoidCallback onDelete;
  final VoidCallback onLabel;

  /// "Log to ZT Time", offered once the timer has rung; null hides it.
  final VoidCallback? onLog;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final t = timer;
    final name = t.label.isNotEmpty
        ? t.label
        : l.timerOf(countdownText(t.length));
    final status = t.ringing
        ? l.timesUp
        : t.paused
        ? l.timerPaused
        : null;
    // In a row, the suite's full-width filled button needs a small minimum.
    final rowFilled = FilledButton.styleFrom(minimumSize: const Size(0, 48));
    return Card(
      color: t.ringing ? colors.primaryContainer : null,
      margin: const EdgeInsetsDirectional.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onLabel,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (t.ringing && onLog != null)
                  IconButton(
                    key: ValueKey('logTimer-${t.id}'),
                    tooltip: l.logToTime,
                    onPressed: onLog,
                    icon: const Icon(Icons.more_time),
                  ),
                IconButton(
                  tooltip: l.deleteTimer,
                  onPressed: onDelete,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        countdownText(t.leftAt(now)),
                        key: ValueKey('left-${t.id}'),
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: t.ringing ? colors.primary : null,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  if (status != null)
                    Center(
                      child: Text(
                        status,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: t.ringing ? colors.primary : colors.outline,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: t.progress(now),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 16),
                  if (t.ringing)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onAddMinute,
                            child: Text(l.addMinute),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: rowFilled,
                            onPressed: onStop,
                            child: Text(l.stop),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: t.idle ? null : onReset,
                            child: Text(l.reset),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onAddMinute,
                            child: Text(l.addMinute),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: rowFilled,
                            onPressed: t.running ? onPause : onStart,
                            child: Text(
                              t.running
                                  ? l.pause
                                  : t.paused
                                  ? l.resume
                                  : l.start,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Add timer": the keypad on its own screen. Pops with the length.
class NewTimerPage extends StatelessWidget {
  const NewTimerPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.addTimer)),
    body: SafeArea(
      child: TimerKeypad(onStart: (d) => Navigator.of(context).pop(d)),
    ),
  );
}

class _LabelDialog extends StatefulWidget {
  const _LabelDialog({required this.label});

  final String label;

  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  late final _text = TextEditingController(text: widget.label);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.timerLabel),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l.label),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_text.text.trim()),
          child: Text(l.save),
        ),
      ],
    );
  }
}
