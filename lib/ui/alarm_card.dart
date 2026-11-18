import 'package:flutter/material.dart';

import '../engine/alarm.dart';
import '../l10n/l10n.dart';
import 'alarm_text.dart';

enum _Menu { skipOnce, undoSkip, edit, delete }

/// One alarm in the list: its time, when it rings, the on/off switch and
/// the three-dot menu with "Turn off once".
class AlarmCard extends StatelessWidget {
  const AlarmCard({
    super.key,
    required this.alarm,
    required this.onToggle,
    required this.onSkipOnce,
    required this.onUndoSkip,
    required this.onCancelSnooze,
    required this.onEdit,
    required this.onDelete,
    this.now,
  });

  final ClockAlarm alarm;
  final ValueChanged<bool> onToggle;
  final VoidCallback onSkipOnce;
  final VoidCallback onUndoSkip;
  final VoidCallback onCancelSnooze;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// The current time (tests).
  final DateTime? now;

  /// "Turn off once" makes sense while there is a next ring to skip.
  bool get _canSkip =>
      alarm.enabled && !alarm.skipActive && alarm.nextRing != null;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final time = timeOfDayText(context, alarm.hour, alarm.minute);
    final dim = alarm.enabled ? colors.onSurface : colors.onSurfaceVariant;
    final snoozedUntil = alarm.snoozeUntil;

    // One extra line when something is going on with this alarm.
    String? status;
    String? actionLabel;
    VoidCallback? action;
    if (alarm.ringing) {
      status = l.ringingNow;
    } else if (snoozedUntil != null) {
      status = l.snoozedUntil(clockText(context, snoozedUntil));
      actionLabel = l.dismiss;
      action = onCancelSnooze;
    } else if (alarm.skipActive) {
      final next = alarm.nextRing;
      status = next == null
          ? l.offOnce
          : l.offOnceNext(dayText(context, next, now: now));
      actionLabel = l.turnBackOn;
      action = onUndoSkip;
    }

    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          time,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: dim,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (alarm.label.isNotEmpty) alarm.label,
                            repeatText(context, alarm, now: now),
                          ].join(' · '),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: time,
                    child: Switch(value: alarm.enabled, onChanged: onToggle),
                  ),
                  PopupMenuButton<_Menu>(
                    tooltip: l.moreOptions,
                    onSelected: (choice) => switch (choice) {
                      _Menu.skipOnce => onSkipOnce(),
                      _Menu.undoSkip => onUndoSkip(),
                      _Menu.edit => onEdit(),
                      _Menu.delete => onDelete(),
                    },
                    itemBuilder: (context) => [
                      if (_canSkip)
                        PopupMenuItem(
                          value: _Menu.skipOnce,
                          child: Text(l.turnOffOnce),
                        ),
                      if (alarm.skipActive)
                        PopupMenuItem(
                          value: _Menu.undoSkip,
                          child: Text(l.turnBackOn),
                        ),
                      PopupMenuItem(value: _Menu.edit, child: Text(l.edit)),
                      PopupMenuItem(value: _Menu.delete, child: Text(l.delete)),
                    ],
                  ),
                ],
              ),
              if (status != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  // The button drops under the text when both do not fit
                  // on one line (large text, a narrow phone).
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              alarm.ringing
                                  ? Icons.notifications_active_outlined
                                  : snoozedUntil != null
                                  ? Icons.snooze
                                  : Icons.event_busy_outlined,
                              size: 18,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                status,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (actionLabel != null)
                          TextButton(
                            onPressed: action,
                            child: Text(actionLabel),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
