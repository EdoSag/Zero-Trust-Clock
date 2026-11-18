import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/alarm.dart';
import '../engine/clock_engine.dart';
import '../l10n/l10n.dart';
import 'alarm_text.dart';

/// How the editor closed.
enum AlarmEditorResult { saved, delete }

const snoozeChoices = [5, 10, 15, 20, 30];

/// Changes one alarm: time, repeat days, label, vibration, snooze length.
class AlarmEditorPage extends ConsumerStatefulWidget {
  const AlarmEditorPage({super.key, required this.alarm});

  final ClockAlarm alarm;

  @override
  ConsumerState<AlarmEditorPage> createState() => _AlarmEditorPageState();
}

class _AlarmEditorPageState extends ConsumerState<AlarmEditorPage> {
  late int _hour = widget.alarm.hour;
  late int _minute = widget.alarm.minute;
  late final Set<int> _days = {...widget.alarm.days};
  late final _label = TextEditingController(text: widget.alarm.label);
  late bool _vibrate = widget.alarm.vibrate;
  late int _snooze = widget.alarm.snoozeMinutes;
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      await ref
          .read(clockEngineProvider)
          .save(
            id: widget.alarm.id,
            hour: _hour,
            minute: _minute,
            days: _days,
            label: _label.text.trim(),
            vibrate: _vibrate,
            snoozeMinutes: _snooze,
          );
      if (mounted) Navigator.of(context).pop(AlarmEditorResult.saved);
    } on Object {
      if (mounted) setState(() => _saving = false);
      showSnack(messenger, l.couldNotSave);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final soft = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.editAlarm),
        actions: [
          IconButton(
            tooltip: l.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () =>
                Navigator.of(context).pop(AlarmEditorResult.delete),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
          children: [
            Center(
              child: Tooltip(
                message: l.changeTime,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _pickTime,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Text(
                      timeOfDayText(context, _hour, _minute),
                      style: theme.textTheme.displayMedium,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.repeat, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final day in weekOrder(context))
                  FilterChip(
                    label: Text(shortDayName(context, day)),
                    tooltip: fullDayName(context, day),
                    selected: _days.contains(day),
                    onSelected: (on) =>
                        setState(() => on ? _days.add(day) : _days.remove(day)),
                  ),
              ],
            ),
            if (_days.isEmpty) ...[
              const SizedBox(height: 4),
              Text(l.ringsOnce, style: soft),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _label,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.label,
                helperText: l.labelHelper,
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsetsDirectional.zero,
              secondary: const Icon(Icons.vibration),
              title: Text(l.vibrate),
              value: _vibrate,
              onChanged: (on) => setState(() => _vibrate = on),
            ),
            const SizedBox(height: 8),
            Text(l.snoozeLength, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final minutes in {
                  ...snoozeChoices,
                  _snooze,
                }.toList()..sort())
                  ChoiceChip(
                    label: Text(l.minutesShort(minutes)),
                    selected: _snooze == minutes,
                    onSelected: (_) => setState(() => _snooze = minutes),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}
