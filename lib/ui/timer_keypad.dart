import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../timers/quick_timers.dart';
import 'alarm_text.dart';
import 'duration_text.dart';

/// The longest timer the keypad can set: 99:59:59.
const maxTimer = Duration(hours: 99, minutes: 59, seconds: 59);

/// Typed digits as a length: "130" is 1 minute 30 seconds, "9000" is
/// 90 minutes. Minutes and seconds above 59 count on (90 s = 1:30).
Duration keypadDuration(String digits) {
  final d = digits.padLeft(6, '0');
  final total = Duration(
    hours: int.parse(d.substring(0, 2)),
    minutes: int.parse(d.substring(2, 4)),
    seconds: int.parse(d.substring(4, 6)),
  );
  return total > maxTimer ? maxTimer : total;
}

/// Sets a new timer: quick timers on top, then the length typed on a
/// keypad, the way a kitchen timer is set. [onStart] gets the length.
class TimerKeypad extends ConsumerStatefulWidget {
  const TimerKeypad({super.key, required this.onStart});

  final ValueChanged<Duration> onStart;

  @override
  ConsumerState<TimerKeypad> createState() => _TimerKeypadState();
}

class _TimerKeypadState extends ConsumerState<TimerKeypad> {
  String _digits = '';

  Duration get _length => keypadDuration(_digits);

  void _type(String keys) {
    setState(() {
      final next = (_digits + keys).replaceFirst(RegExp('^0+'), '');
      if (next.length <= 6) _digits = next;
    });
  }

  void _back() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Future<void> _saveQuick() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    await ref.read(quickTimersProvider.notifier).add(_length);
    showSnack(messenger, l.quickTimerSaved);
  }

  Future<void> _removeQuick(Duration d) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final quick = ref.read(quickTimersProvider.notifier);
    await quick.remove(d);
    showSnack(
      messenger,
      l.quickTimerRemoved,
      actionLabel: l.undo,
      onAction: () => quick.add(d),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final saved = ref.watch(quickTimersProvider).value ?? const <Duration>[];
    final d = _digits.padLeft(6, '0');
    final typed = _digits.isNotEmpty;
    final digitStyle = theme.textTheme.displayMedium?.copyWith(
      color: typed ? theme.colorScheme.primary : theme.colorScheme.outline,
    );
    final unitStyle = theme.textTheme.titleLarge?.copyWith(
      color: typed ? theme.colorScheme.primary : theme.colorScheme.outline,
    );
    Widget part(String two, String unit) => Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(two, style: digitStyle),
        const SizedBox(width: 2),
        Text(unit, style: unitStyle),
      ],
    );

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
      children: [
        Text(l.quickTimers, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          key: const ValueKey('quickTimers'),
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final q in defaultQuickTimers)
              ActionChip(
                label: Text(countdownText(q)),
                onPressed: () => widget.onStart(q),
              ),
            for (final q in saved)
              InputChip(
                avatar: const Icon(Icons.bookmark_outline, size: 18),
                label: Text(countdownText(q)),
                onPressed: () => widget.onStart(q),
                onDeleted: () => _removeQuick(q),
                deleteButtonTooltipMessage: l.delete,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l.quickTimersHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        // Hours, minutes, seconds: left to right in Hebrew too, like a clock.
        Directionality(
          textDirection: TextDirection.ltr,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              key: const ValueKey('keypadDisplay'),
              mainAxisSize: MainAxisSize.min,
              children: [
                part(d.substring(0, 2), l.hoursUnit),
                const SizedBox(width: 12),
                part(d.substring(2, 4), l.minutesUnit),
                const SizedBox(width: 12),
                part(d.substring(4, 6), l.secondsUnit),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: typed
              ? Center(
                  child: TextButton.icon(
                    onPressed: _saveQuick,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(l.saveQuickTimer),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 8),
        Directionality(
          textDirection: TextDirection.ltr,
          child: _Keys(
            onType: _type,
            onBack: _back,
            backTooltip: l.deleteDigit,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _length > Duration.zero
              ? () => widget.onStart(_length)
              : null,
          icon: const Icon(Icons.play_arrow),
          label: Text(l.start),
        ),
      ],
    );
  }
}

class _Keys extends StatelessWidget {
  const _Keys({
    required this.onType,
    required this.onBack,
    required this.backTooltip,
  });

  final ValueChanged<String> onType;
  final VoidCallback onBack;
  final String backTooltip;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium;
    Widget key(String keys) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(0, 64)),
          onPressed: () => onType(keys),
          child: Text(keys, style: style),
        ),
      ),
    );
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final k in row) key(k)]),
        Row(
          children: [
            key('00'),
            key('0'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: IconButton(
                  style: IconButton.styleFrom(minimumSize: const Size(0, 64)),
                  tooltip: backTooltip,
                  onPressed: onBack,
                  icon: const Icon(Icons.backspace_outlined),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
