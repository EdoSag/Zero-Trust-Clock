import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/clock_engine.dart';
import '../engine/clock_timer.dart';
import '../l10n/l10n.dart';
import 'alarm_text.dart';
import 'clock_home.dart';
import 'duration_text.dart';
import 'settings_button.dart';

/// The Stopwatch tab: the time, Start / Pause, Lap / Reset, and the laps
/// (newest on top). It keeps counting with the app closed.
class StopwatchPage extends ConsumerStatefulWidget {
  const StopwatchPage({super.key});

  @override
  ConsumerState<StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends ConsumerState<StopwatchPage> {
  Timer? _tick;

  ClockEngine get _engine => ref.read(clockEngineProvider);

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _keepTicking(bool running) {
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running && _tick != null) {
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
    await ref.read(stopwatchProvider.notifier).refresh();
  }

  Future<void> _copyLaps(StopwatchState s) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final times = s.lapTimes;
    final text = [
      for (var i = 0; i < s.laps.length; i++)
        '${l.lapNumber(i + 1)}\t${stopwatchText(times[i])}\t'
            '${stopwatchText(s.laps[i])}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    showSnack(messenger, l.lapsCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final s = ref.watch(stopwatchProvider).value ?? const StopwatchState();
    _keepTicking(s.running);
    onHomeAction(ref, HomeAction.startStopwatch, () {
      final now = ref.read(stopwatchProvider).value;
      if (now == null || !now.running) _run(_engine.stopwatchStart);
    });
    final now = DateTime.now();
    final elapsed = s.elapsed(now);
    final times = s.lapTimes;
    // Fastest and slowest lap, once there are a few to compare.
    Duration? fastest;
    Duration? slowest;
    if (times.length >= 2) {
      fastest = times.reduce((a, b) => a <= b ? a : b);
      slowest = times.reduce((a, b) => a >= b ? a : b);
    }
    final rowFilled = FilledButton.styleFrom(minimumSize: const Size(0, 56));
    final rowOutlined = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 56),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.stopwatch),
        actions: [
          if (s.laps.isNotEmpty)
            IconButton(
              tooltip: l.copyLaps,
              onPressed: () => _copyLaps(s),
              icon: const Icon(Icons.copy_all_outlined),
            ),
          const SettingsButton(),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Directionality(
                textDirection: TextDirection.ltr,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    stopwatchText(elapsed),
                    key: const ValueKey('stopwatchTime'),
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              if (s.laps.isNotEmpty)
                Center(
                  child: Text(
                    '${l.lapNumber(s.laps.length + 1)}  '
                    '${stopwatchText(elapsed - s.laps.last)}',
                    key: const ValueKey('currentLap'),
                    textDirection: Directionality.of(context),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: rowOutlined,
                      onPressed: s.running
                          ? () => _run(_engine.stopwatchLap)
                          : s.zero
                          ? null
                          : () => _run(_engine.stopwatchReset),
                      child: Text(s.running || s.zero ? l.lap : l.reset),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      style: rowFilled,
                      onPressed: () => _run(
                        s.running
                            ? _engine.stopwatchPause
                            : _engine.stopwatchStart,
                      ),
                      child: Text(
                        s.running
                            ? l.pause
                            : s.zero
                            ? l.start
                            : l.resume,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  key: const ValueKey('laps'),
                  itemCount: s.laps.length,
                  itemBuilder: (context, i) {
                    // Newest on top.
                    final n = s.laps.length - 1 - i;
                    final lap = times[n];
                    final color = lap == fastest
                        ? Colors.green.shade700
                        : lap == slowest
                        ? theme.colorScheme.error
                        : null;
                    return _LapRow(
                      number: n + 1,
                      lap: lap,
                      total: s.laps[n],
                      color: color,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LapRow extends StatelessWidget {
  const _LapRow({
    required this.number,
    required this.lap,
    required this.total,
    this.color,
  });

  final int number;
  final Duration lap;
  final Duration total;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digits = theme.textTheme.bodyLarge?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.lapNumber(number),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          Expanded(
            child: Text(
              stopwatchText(lap),
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: digits?.copyWith(color: color),
            ),
          ),
          Expanded(
            child: Text(
              stopwatchText(total),
              textAlign: TextAlign.end,
              textDirection: TextDirection.ltr,
              style: digits?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
