import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/alarm.dart';
import '../engine/bedtime.dart';
import '../engine/clock_engine.dart';
import '../l10n/l10n.dart';
import 'alarm_text.dart';
import 'settings_button.dart';

/// "8 h", "7 h 30 min".
String lengthText(AppL10n l, Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return l.minutesShort(m);
  return m == 0 ? l.hoursOnly(h) : l.hoursAndMinutes(h, m);
}

/// The Bedtime tab: when the night starts and ends, a reminder, Do Not
/// Disturb, a wake-up alarm, and sleep sounds.
class BedtimePage extends ConsumerStatefulWidget {
  const BedtimePage({super.key});

  static const reminderChoices = [0, 15, 30, 60];
  static const sleepTimerChoices = [15, 30, 45, 60, 90];

  @override
  ConsumerState<BedtimePage> createState() => _BedtimePageState();
}

class _BedtimePageState extends ConsumerState<BedtimePage>
    with WidgetsBindingObserver {
  SleepSound _sound = SleepSound.pink;
  int _minutes = 30;
  Timer? _tick;

  ClockEngine get _engine => ref.read(clockEngineProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Sleep sounds end on their own; the card follows.
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) ref.read(sleepSoundProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from Android's Do Not Disturb access screen: a night under way
    // gets Do Not Disturb now, not only from the next one.
    if (state != AppLifecycleState.resumed) return;
    ref.invalidate(dndAccessProvider);
    ref.invalidate(sleepAccessProvider);
    final s = ref.read(bedtimeProvider).value;
    if (s != null && s.enabled && s.doNotDisturb) {
      ref.read(bedtimeProvider.notifier).save(s).catchError((Object _) {});
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
  }

  ClockAlarm? _wakeAlarm(BedtimeSchedule s) {
    final id = s.wakeAlarmId;
    if (id == null) return null;
    for (final a in ref.read(alarmsProvider).value ?? const <ClockAlarm>[]) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Saves the schedule. A wake-up alarm that is on follows its times and
  /// nights.
  Future<void> _save(BedtimeSchedule s) => _run(() async {
    final before = ref.read(bedtimeProvider).value;
    final remindedBefore =
        before != null && before.enabled && before.reminderMinutes > 0;
    if (s.enabled && s.reminderMinutes > 0 && !remindedBefore) {
      // The reminder is a notification (Android 13 and later ask).
      try {
        await _engine.requestNotifications();
      } on Object {
        // The Alarm check screen shows it.
      }
    }
    final alarm = _wakeAlarm(s);
    if (alarm != null &&
        alarm.enabled &&
        (alarm.hour != s.wakeHour ||
            alarm.minute != s.wakeMinute ||
            !_sameDays(alarm.days, s.wakeDays))) {
      await _saveWakeAlarm(s, alarm);
    }
    await ref.read(bedtimeProvider.notifier).save(s);
  });

  static bool _sameDays(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);

  Future<String> _saveWakeAlarm(BedtimeSchedule s, ClockAlarm? alarm) async {
    final id = await _engine.save(
      id: alarm?.id,
      hour: s.wakeHour,
      minute: s.wakeMinute,
      days: s.wakeDays,
      label: alarm?.label ?? context.l10n.wakeUp,
      vibrate: alarm?.vibrate ?? true,
      snoozeMinutes: alarm?.snoozeMinutes ?? 10,
      sound: alarm?.sound,
      soundName: alarm?.soundName,
      gradual: alarm?.gradual ?? false,
      ringMinutes: alarm?.ringMinutes ?? ClockAlarm.defaultRingMinutes,
      task: alarm?.task,
      skipHolidays: alarm?.skipHolidays ?? false,
    );
    await ref.read(alarmsProvider.notifier).refresh();
    return id;
  }

  Future<void> _setWakeAlarm(BedtimeSchedule s, bool on) => _run(() async {
    final alarm = _wakeAlarm(s);
    if (on) {
      final id = await _saveWakeAlarm(s, alarm);
      // Saving keeps an unchanged alarm as it was: switched off stays off.
      if (alarm != null && !alarm.enabled) {
        await _engine.setEnabled(id, true);
        await ref.read(alarmsProvider.notifier).refresh();
      }
      if (id != s.wakeAlarmId) {
        await ref
            .read(bedtimeProvider.notifier)
            .save(s.copyWith(wakeAlarmId: id));
      }
      try {
        await _engine.requestNotifications();
      } on Object {
        // The Alarm check screen shows it.
      }
    } else if (alarm != null) {
      await _engine.setEnabled(alarm.id, false);
      await ref.read(alarmsProvider.notifier).refresh();
    }
  });

  Future<void> _pickTime(BedtimeSchedule s, {required bool bed}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: bed
          ? TimeOfDay(hour: s.bedHour, minute: s.bedMinute)
          : TimeOfDay(hour: s.wakeHour, minute: s.wakeMinute),
    );
    if (picked == null || !mounted) return;
    await _save(
      bed
          ? s.copyWith(bedHour: picked.hour, bedMinute: picked.minute)
          : s.copyWith(wakeHour: picked.hour, wakeMinute: picked.minute),
    );
  }

  Future<void> _setDnd(BedtimeSchedule s, bool on) async {
    await _save(s.copyWith(doNotDisturb: on));
    if (on && !(await ref.read(dndAccessProvider.future))) {
      await _run(() => _engine.openSettings('dndAccess'));
    }
  }

  Future<void> _setSunrise(BedtimeSchedule s, bool on) async {
    await _save(s.copyWith(sunrise: on));
    if (!on) return;
    // The sunrise opens from a notification (Android 13 and later ask).
    try {
      await _engine.requestNotifications();
    } on Object {
      // The Alarm check screen shows it.
    }
  }

  /// Asks Health Connect first: the switch only turns on when allowed.
  Future<void> _setSaveSleep(BedtimeSchedule s, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    if (on) {
      var allowed = false;
      try {
        allowed = await _engine.requestSleepAccess();
      } on Object {
        allowed = false;
      }
      ref.invalidate(sleepAccessProvider);
      if (!allowed) {
        showSnack(messenger, l.saveSleepNotAllowed);
        return;
      }
    }
    await _save(s.copyWith(saveSleep: on));
  }

  /// "Allow" under the switch: asks again, and when Android no longer
  /// shows the question, opens the app's page in Health Connect.
  Future<void> _allowSleep() => _run(() async {
    final allowed = await _engine.requestSleepAccess();
    ref.invalidate(sleepAccessProvider);
    if (!allowed) await _engine.openSettings('healthConnect');
  });

  Future<void> _play() => _run(() async {
    await _engine.playSleepSound(_sound, _minutes);
    await ref.read(sleepSoundProvider.notifier).refresh();
  });

  Future<void> _stop() => _run(() async {
    await _engine.stopSleepSound();
    await ref.read(sleepSoundProvider.notifier).refresh();
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bedtime = ref.watch(bedtimeProvider);
    ref.watch(alarmsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.bedtime), actions: const [SettingsButton()]),
      body: SafeArea(
        child: bedtime.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(l.couldNotSave)),
          data: (s) => ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
            children: [
              _scheduleCard(context, s),
              const SizedBox(height: 12),
              _soundsCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scheduleCard(BuildContext context, BedtimeSchedule s) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final soft = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final dndAccess = ref.watch(dndAccessProvider).value ?? true;
    final wake = _wakeAlarm(s);
    final wakeOn = wake != null && wake.enabled;
    final sleep = ref.watch(sleepAccessProvider).value ?? const SleepAccess();
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: const ValueKey('bedtimeOn'),
              contentPadding: EdgeInsetsDirectional.zero,
              title: Text(l.bedtimeSchedule),
              subtitle: Text(l.bedtimeScheduleHint),
              value: s.enabled,
              onChanged: (on) => _save(s.copyWith(enabled: on)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TimeTile(
                    key: const ValueKey('bedTime'),
                    icon: Icons.bedtime_outlined,
                    label: l.bedtimeStart,
                    time: timeOfDayText(context, s.bedHour, s.bedMinute),
                    onTap: () => _pickTime(s, bed: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeTile(
                    key: const ValueKey('wakeTime'),
                    icon: Icons.wb_sunny_outlined,
                    label: l.wakeUp,
                    time: timeOfDayText(context, s.wakeHour, s.wakeMinute),
                    onTap: () => _pickTime(s, bed: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                l.sleepFor(lengthText(l, s.length)),
                key: const ValueKey('sleepLength'),
                style: soft,
              ),
            ),
            const SizedBox(height: 16),
            Text(l.nights, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final day in weekOrder(context))
                  FilterChip(
                    label: Text(shortDayName(context, day)),
                    tooltip: fullDayName(context, day),
                    selected: s.nights.contains(day),
                    // At least one night stays picked.
                    onSelected: s.nights.length == 1 && s.nights.contains(day)
                        ? null
                        : (on) => _save(
                            s.copyWith(
                              nights: on
                                  ? {...s.nights, day}
                                  : ({...s.nights}..remove(day)),
                            ),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l.reminder, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final m in BedtimePage.reminderChoices)
                  ChoiceChip(
                    label: Text(m == 0 ? l.off : l.minutesShort(m)),
                    selected: s.reminderMinutes == m,
                    onSelected: (_) => _save(s.copyWith(reminderMinutes: m)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey('bedtimeDnd'),
              contentPadding: EdgeInsetsDirectional.zero,
              title: Text(l.doNotDisturbAtBedtime),
              subtitle: Text(l.doNotDisturbHint),
              value: s.doNotDisturb,
              onChanged: (on) => _setDnd(s, on),
            ),
            if (s.doNotDisturb && !dndAccess)
              Row(
                key: const ValueKey('dndAccess'),
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l.dndNeedsAccess, style: soft)),
                  TextButton(
                    onPressed: () =>
                        _run(() => _engine.openSettings('dndAccess')),
                    child: Text(l.allow),
                  ),
                ],
              ),
            SwitchListTile(
              key: const ValueKey('wakeAlarm'),
              contentPadding: EdgeInsetsDirectional.zero,
              title: Text(l.wakeUpAlarm),
              subtitle: Text(
                l.wakeUpAlarmHint(
                  timeOfDayText(context, s.wakeHour, s.wakeMinute),
                ),
              ),
              value: wakeOn,
              onChanged: (on) => _setWakeAlarm(s, on),
            ),
            SwitchListTile(
              key: const ValueKey('sunrise'),
              contentPadding: EdgeInsetsDirectional.zero,
              title: Text(l.sunrise),
              subtitle: Text(
                wakeOn || s.sunrise
                    ? l.sunriseHint(BedtimeSchedule.sunriseMinutes)
                    : l.sunriseNeedsAlarm,
              ),
              value: s.sunrise,
              // Follows the wake-up alarm; can always be switched off.
              onChanged: wakeOn || s.sunrise
                  ? (on) => _setSunrise(s, on)
                  : null,
            ),
            if (sleep.available) ...[
              SwitchListTile(
                key: const ValueKey('saveSleep'),
                contentPadding: EdgeInsetsDirectional.zero,
                title: Text(l.saveSleep),
                subtitle: Text(l.saveSleepHint),
                value: s.saveSleep,
                onChanged: (on) => _setSaveSleep(s, on),
              ),
              if (s.saveSleep && !sleep.allowed)
                Row(
                  key: const ValueKey('sleepAccess'),
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.saveSleepNeedsAccess, style: soft)),
                    TextButton(onPressed: _allowSleep, child: Text(l.allow)),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _soundsCard(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final playing = ref.watch(sleepSoundProvider).value;
    final soft = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    String name(SleepSound s) => switch (s) {
      SleepSound.white => l.soundWhite,
      SleepSound.pink => l.soundPink,
      SleepSound.brown => l.soundDeep,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.sleepSounds, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l.sleepSoundsHint, style: soft),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final s in SleepSound.values)
                  ChoiceChip(
                    label: Text(name(s)),
                    selected: (playing?.sound ?? _sound) == s,
                    onSelected: playing != null
                        ? null
                        : (_) => setState(() => _sound = s),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l.stopAfter, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final m in BedtimePage.sleepTimerChoices)
                  ChoiceChip(
                    label: Text(l.minutesShort(m)),
                    selected: _minutes == m,
                    onSelected: playing != null
                        ? null
                        : (_) => setState(() => _minutes = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (playing != null) ...[
              Text(
                l.stopsAt(
                  timeOfDayText(
                    context,
                    playing.endsAt.hour,
                    playing.endsAt.minute,
                  ),
                ),
                key: const ValueKey('soundEnds'),
                style: soft,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _stop,
                icon: const Icon(Icons.stop),
                label: Text(l.stop),
              ),
            ] else
              FilledButton.icon(
                onPressed: _play,
                icon: const Icon(Icons.play_arrow),
                label: Text(l.play),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Bedtime 23:00": a time to tap and change.
class _TimeTile extends StatelessWidget {
  const _TimeTile({
    super.key,
    required this.icon,
    required this.label,
    required this.time,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(time, style: theme.textTheme.headlineMedium),
            ],
          ),
        ),
      ),
    );
  }
}
