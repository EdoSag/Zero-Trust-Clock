import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/alarm.dart';
import '../engine/clock_engine.dart';
import '../l10n/l10n.dart';
import 'alarm_text.dart';

/// How the editor closed.
enum AlarmEditorResult { saved, delete }

const snoozeChoices = [5, 10, 15, 20, 30];
const silenceChoices = [1, 5, 10, 15, 20, 30];

/// Changes one alarm: time, repeat days or the date it rings on, label,
/// sound, vibration, gradually louder, snooze length and silence after.
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
  late String? _sound = widget.alarm.sound;
  late String? _soundName = widget.alarm.soundName;
  late bool _gradual = widget.alarm.gradual;
  late int _silenceAfter = widget.alarm.ringMinutes;

  /// The day an alarm without repeat days rings; null: the next such time.
  late DateTime? _date = widget.alarm.repeats
      ? null
      : parseDay(widget.alarm.date);
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

  /// The day a one-time alarm rings: the picked one while that time is
  /// still ahead, else today or tomorrow.
  DateTime _ringDay() {
    final now = DateTime.now();
    final picked = _date;
    if (picked != null) {
      final at = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _hour,
        _minute,
      );
      if (at.isAfter(now)) return DateUtils.dateOnly(picked);
    }
    final today = DateTime(now.year, now.month, now.day, _hour, _minute);
    return DateUtils.dateOnly(
      today.isAfter(now) ? today : today.add(const Duration(days: 1)),
    );
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _ringDay(),
      firstDate: today,
      lastDate: today.add(const Duration(days: 366)),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  String _soundText(AppL10n l) => switch (_sound) {
    null => l.soundChime,
    'system' => l.soundSystem,
    _ => (_soundName ?? '').isEmpty ? l.soundPicked : _soundName!,
  };

  void _setSound(String? sound, String? name) => setState(() {
    _sound = sound;
    _soundName = name;
  });

  Future<void> _chooseSound() async {
    final l = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      // Scrolls on a small phone or with large text.
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (key, icon, text) in [
                ('chime', Icons.alarm, l.soundChime),
                ('system', Icons.phone_android, l.soundSystem),
                ('ringtone', Icons.library_music_outlined, l.soundRingtone),
                ('file', Icons.audio_file_outlined, l.soundFile),
              ])
                ListTile(
                  leading: Icon(icon),
                  title: Text(text),
                  onTap: () => Navigator.of(context).pop(key),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
                child: Text(
                  l.soundHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'chime':
        _setSound(null, null);
      case 'system':
        _setSound('system', null);
      default:
        final picked = await ref
            .read(clockEngineProvider)
            .pickSound(
              choice == 'ringtone' ? SoundKind.ringtone : SoundKind.file,
            );
        if (picked == null || !mounted) return;
        _setSound(picked.sound, picked.name);
    }
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
            sound: _sound,
            soundName: _soundName,
            gradual: _gradual,
            ringMinutes: _silenceAfter,
            // Only a picked (or kept) day: saving a label alone does not
            // switch an alarm on.
            date: _days.isEmpty && _date != null ? _ringDay() : null,
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
              ListTile(
                contentPadding: EdgeInsetsDirectional.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(l.date),
                subtitle: Text(dayText(context, _ringDay())),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDate,
              ),
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
            ListTile(
              contentPadding: EdgeInsetsDirectional.zero,
              leading: const Icon(Icons.music_note_outlined),
              title: Text(l.sound),
              subtitle: Text(_soundText(l)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _chooseSound,
            ),
            SwitchListTile(
              contentPadding: EdgeInsetsDirectional.zero,
              secondary: const Icon(Icons.trending_up),
              title: Text(l.gradual),
              subtitle: Text(l.gradualHint),
              value: _gradual,
              onChanged: (on) => setState(() => _gradual = on),
            ),
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
              key: const ValueKey('snooze'),
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
            const SizedBox(height: 16),
            Text(l.silenceAfter, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              key: const ValueKey('silenceAfter'),
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final minutes in {
                  ...silenceChoices,
                  _silenceAfter,
                }.toList()..sort())
                  ChoiceChip(
                    label: Text(l.minutesShort(minutes)),
                    selected: _silenceAfter == minutes,
                    onSelected: (_) => setState(() => _silenceAfter = minutes),
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
