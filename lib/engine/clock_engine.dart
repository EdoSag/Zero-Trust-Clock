import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alarm.dart';
import 'bedtime.dart';
import 'clock_timer.dart';
import '../sync/settings_sync.dart';
import '../world/world_zone.dart';

/// The alarm engine on the phone. It keeps the alarms, hands them to
/// Android and rings them, also with the app closed and before the
/// phone's first unlock. The screens call it for every change.
abstract class ClockEngine {
  Future<List<ClockAlarm>> list();

  /// Adds an alarm ([id] null) or changes one. Returns its id. A new or
  /// re-timed alarm is switched on.
  Future<String> save({
    String? id,
    required int hour,
    required int minute,
    Set<int> days = const {},
    String label = '',
    bool vibrate = true,
    int snoozeMinutes = 10,
    String? sound,
    String? soundName,
    bool gradual = false,
    int ringMinutes = ClockAlarm.defaultRingMinutes,
    WakeTask? task,
    String? taskCode,
    bool skipHolidays = false,
    DateTime? date,
    ShiftPattern? shift,
    CalendarLink? calendar,
    int smartWake = 0,
  });

  /// Opens the camera to save a code for [WakeTask.scan]. The code's
  /// hash, or null when nothing was scanned.
  Future<String?> scanCode();

  /// Plays [sound] once, on the alarm volume ([ClockAlarm.sound] values).
  Future<void> previewSound(String? sound);
  Future<void> stopPreview();

  /// What the volume buttons do while an alarm rings, and how loud a ring
  /// is at least.
  Future<RingSettings> ringSettings();
  Future<void> setRingSettings(RingSettings settings);

  /// "Pause until": a repeating alarm is silent through [until].
  Future<void> pause(String id, DateTime until);
  Future<void> resume(String id);

  /// "Pause all alarms until" (repeating ones, this phone), or null.
  Future<DateTime?> pauseAllUntil();
  Future<void> setPauseAll(DateTime? until);

  /// Lets the user pick a phone sound ([SoundKind.ringtone]) or an audio
  /// file. Null when cancelled.
  Future<PickedSound?> pickSound(SoundKind kind);

  Future<void> setEnabled(String id, bool enabled);

  /// Takes an alarm as the account's backup has it, keeping its
  /// [ClockAlarm.updatedAt]. [ClockAlarm.enabled] is this phone's own
  /// switch. False while that alarm rings (nothing changed; try later).
  Future<bool> importSynced(ClockAlarm alarm);

  /// Each linked alarm's first ZT Calendar event per day:
  /// `{alarmId: {"through": "yyyy-MM-dd", "days": {"yyyy-MM-dd": minutes}}}`.
  /// Not an edit: nothing syncs because of it.
  Future<void> setCalendarPlans(Map<String, Object?> plans);

  /// The morning screen's data (see `morningBrief`), or null to forget it.
  Future<void> setMorningBrief(String? json);

  /// "Turn off once": skips the next ring; the alarm stays on.
  Future<void> skipOnce(String id);

  /// "Turn back on": undoes [skipOnce].
  Future<void> undoSkip(String id);

  /// Ends a snooze without ringing again.
  Future<void> cancelSnooze(String id);
  Future<void> delete(String id);

  /// A real alarm in [seconds], for the Alarm check screen.
  Future<void> testAlarm(int seconds);

  /// Snoozes or dismisses the alarm ringing right now.
  Future<void> ringSnooze();
  Future<void> ringDismiss();

  /// The language of the ring screen and notifications: `en`, `he`, or
  /// null to follow the phone.
  Future<void> setLanguage(String? code);
  Future<AlarmCheck> check();

  /// Asks for the notification permission. True when it is granted.
  Future<bool> requestNotifications();

  /// Opens the system screen that fixes one check (`notifications`,
  /// `ringChannel`, `fullScreen`, `exactAlarms`, `sound`, `doNotDisturb`).
  Future<void> openSettings(String which);

  /// Fires when the alarms changed outside the screens (one rang, was
  /// dismissed, was missed).
  Stream<void> get changes;

  // Timers: run and rung by the engine, also with the app closed.

  Future<List<ClockTimer>> timers();

  /// A new timer, started unless [start] is false. Returns its id.
  Future<String> addTimer(
    Duration length, {
    String label = '',
    bool start = true,
  });
  Future<void> startTimer(String id);
  Future<void> pauseTimer(String id);

  /// "+1:00" (also on a ringing timer: it runs one more minute).
  Future<void> addTimerMinute(String id);

  /// Back to its length, not running. Stops it ringing too.
  Future<void> resetTimer(String id);
  Future<void> setTimerLabel(String id, String label);
  Future<void> deleteTimer(String id);

  /// "Stop" for every finished timer that rings.
  Future<void> stopRingingTimers();

  // The stopwatch, kept by the engine with its notification.

  Future<StopwatchState> stopwatch();
  Future<void> stopwatchStart();
  Future<void> stopwatchPause();
  Future<void> stopwatchLap();
  Future<void> stopwatchReset();

  /// The tab a notification or shortcut opened the app on (taken once).
  Future<String?> launchTab();

  // Public holidays.

  /// The days alarms with "Skip public holidays" stay silent on.
  Future<List<String>> holidays();
  Future<void> setHolidays(List<String> days);

  // Screensaver.

  /// The night clock screensaver is dim red (true) or soft white.
  Future<bool> screensaverNight();
  Future<void> setScreensaverNight(bool on);

  // Bedtime.

  Future<BedtimeSchedule> bedtime();
  Future<void> setBedtime(BedtimeSchedule schedule);

  /// Whether the app may turn Do Not Disturb on (Android's setting).
  Future<bool> dndAccess();

  /// Whether sleep can be saved to Health Connect here, and is allowed.
  Future<SleepAccess> sleepAccess();

  /// Asks to write sleep to Health Connect. True when allowed.
  Future<bool> requestSleepAccess();

  /// Sleep sounds playing now, or null.
  Future<SleepSoundState?> sleepSound();
  Future<void> playSleepSound(SleepSound sound, int minutes);
  Future<void> stopSleepSound();

  // World clock.

  /// Every city Android knows, named in the app's language.
  Future<List<WorldZone>> zones();

  /// The phone's own time zone ("Asia/Jerusalem"), or null.
  Future<String?> localZone();

  /// The offsets from UTC right now of [ids].
  Future<Map<String, Duration>> zoneOffsets(List<String> ids);

  /// The cities picked, in order, for the world clock widget.
  Future<void> setWorldCities(List<String> ids);

  /// A tab asked for while the app is already open.
  Stream<String> get openTab;
}

class MethodChannelClockEngine implements ClockEngine {
  MethodChannelClockEngine() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') _changes.add(null);
      if (call.method == 'openTab' && call.arguments is String) {
        // Locked (the home screen isn't there): it waits for launchTab.
        if (_tabs.hasListener) {
          _tabs.add(call.arguments as String);
        } else {
          _waitingTab = call.arguments as String;
        }
      }
    });
  }

  static const _channel = MethodChannel('dev.sagron.zerotrustclock/engine');
  final _changes = StreamController<void>.broadcast();
  final _tabs = StreamController<String>.broadcast();

  @override
  Stream<String> get openTab => _tabs.stream;

  String? _waitingTab;

  @override
  Future<String?> launchTab() async {
    final waiting = _waitingTab;
    _waitingTab = null;
    return waiting ?? await _channel.invokeMethod<String>('launchTab');
  }

  @override
  Future<List<String>> holidays() async => [
    ...?(await _channel.invokeMethod<List<Object?>>(
      'holidays',
    ))?.whereType<String>(),
  ];

  @override
  Future<void> setHolidays(List<String> days) =>
      _channel.invokeMethod('setHolidays', {'days': days});

  @override
  Future<bool> screensaverNight() async =>
      await _channel.invokeMethod<bool>('screensaverNight') ?? true;

  @override
  Future<void> setScreensaverNight(bool on) =>
      _channel.invokeMethod('setScreensaverNight', {'on': on});

  @override
  Future<BedtimeSchedule> bedtime() async => BedtimeSchedule.fromJson(
    await _channel.invokeMethod<String>('bedtime') ?? '{}',
  );

  @override
  Future<void> setBedtime(BedtimeSchedule schedule) =>
      _channel.invokeMethod('setBedtime', {'json': schedule.toJson()});

  @override
  Future<bool> dndAccess() async =>
      await _channel.invokeMethod<bool>('dndAccess') ?? false;

  @override
  Future<SleepAccess> sleepAccess() async {
    final m = await _channel.invokeMapMethod<String, Object?>('sleepAccess');
    return SleepAccess(
      available: m?['available'] == true,
      allowed: m?['allowed'] == true,
    );
  }

  @override
  Future<bool> requestSleepAccess() async =>
      await _channel.invokeMethod<bool>('requestSleepAccess') ?? false;

  @override
  Future<SleepSoundState?> sleepSound() async {
    final m = await _channel.invokeMethod<Map<Object?, Object?>>('sleepSound');
    if (m == null) return null;
    final sound = SleepSound.values.firstWhere(
      (s) => s.name == m['kind'],
      orElse: () => SleepSound.white,
    );
    return SleepSoundState(
      sound,
      DateTime.fromMillisecondsSinceEpoch((m['endsAt'] as num).toInt()),
    );
  }

  @override
  Future<void> playSleepSound(SleepSound sound, int minutes) => _channel
      .invokeMethod('playSleepSound', {'kind': sound.name, 'minutes': minutes});

  @override
  Future<void> stopSleepSound() => _channel.invokeMethod('stopSleepSound');

  @override
  Future<String?> localZone() => _channel.invokeMethod<String>('localZone');

  @override
  Future<List<WorldZone>> zones() async => WorldZone.listFromJson(
    await _channel.invokeMethod<String>('zones') ?? '[]',
  );

  @override
  Future<Map<String, Duration>> zoneOffsets(List<String> ids) async {
    final m = await _channel.invokeMethod<Map<Object?, Object?>>(
      'zoneOffsets',
      {'ids': ids},
    );
    return {
      for (final e in (m ?? const {}).entries)
        if (e.key is String && e.value is num)
          e.key as String: Duration(minutes: (e.value as num).toInt()),
    };
  }

  @override
  Future<void> setWorldCities(List<String> ids) =>
      _channel.invokeMethod('setWorldCities', {'ids': ids});

  @override
  Future<List<ClockTimer>> timers() async => ClockTimer.listFromJson(
    await _channel.invokeMethod<String>('timers') ?? '[]',
  );

  @override
  Future<String> addTimer(
    Duration length, {
    String label = '',
    bool start = true,
  }) async =>
      await _channel.invokeMethod<String>('timerAdd', {
        'lengthMs': length.inMilliseconds,
        'label': label,
        'start': start,
      }) ??
      '';

  @override
  Future<void> startTimer(String id) =>
      _channel.invokeMethod('timerStart', {'id': id});

  @override
  Future<void> pauseTimer(String id) =>
      _channel.invokeMethod('timerPause', {'id': id});

  @override
  Future<void> addTimerMinute(String id) =>
      _channel.invokeMethod('timerAddMinute', {'id': id});

  @override
  Future<void> resetTimer(String id) =>
      _channel.invokeMethod('timerReset', {'id': id});

  @override
  Future<void> setTimerLabel(String id, String label) =>
      _channel.invokeMethod('timerLabel', {'id': id, 'label': label});

  @override
  Future<void> deleteTimer(String id) =>
      _channel.invokeMethod('timerDelete', {'id': id});

  @override
  Future<void> stopRingingTimers() => _channel.invokeMethod('timerStopRinging');

  @override
  Future<StopwatchState> stopwatch() async => StopwatchState.fromJson(
    await _channel.invokeMethod<String>('stopwatch') ?? '{}',
  );

  @override
  Future<void> stopwatchStart() => _channel.invokeMethod('stopwatchStart');

  @override
  Future<void> stopwatchPause() => _channel.invokeMethod('stopwatchPause');

  @override
  Future<void> stopwatchLap() => _channel.invokeMethod('stopwatchLap');

  @override
  Future<void> stopwatchReset() => _channel.invokeMethod('stopwatchReset');

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<ClockAlarm>> list() async => ClockAlarm.listFromJson(
    await _channel.invokeMethod<String>('list') ?? '[]',
  );

  @override
  Future<String> save({
    String? id,
    required int hour,
    required int minute,
    Set<int> days = const {},
    String label = '',
    bool vibrate = true,
    int snoozeMinutes = 10,
    String? sound,
    String? soundName,
    bool gradual = false,
    int ringMinutes = ClockAlarm.defaultRingMinutes,
    WakeTask? task,
    String? taskCode,
    bool skipHolidays = false,
    DateTime? date,
    ShiftPattern? shift,
    CalendarLink? calendar,
    int smartWake = 0,
  }) async =>
      await _channel.invokeMethod<String>('save', {
        'id': id,
        'hour': hour,
        'minute': minute,
        'days': days.toList()..sort(),
        'label': label,
        'vibrate': vibrate,
        'snoozeMinutes': snoozeMinutes,
        'sound': sound,
        'soundName': soundName,
        'gradual': gradual,
        'ringMinutes': ringMinutes,
        'task': task?.name,
        'taskCode': taskCode,
        'skipHolidays': skipHolidays,
        'date': date == null ? null : dayKey(date),
        'cycle': shift?.days,
        'cycleStart': shift?.start,
        'calendar': calendar?.toJson(),
        'smartWake': smartWake,
      }) ??
      '';

  @override
  Future<String?> scanCode() => _channel.invokeMethod<String>('scanCode');

  @override
  Future<void> previewSound(String? sound) =>
      _channel.invokeMethod('previewSound', {'sound': sound});

  @override
  Future<void> stopPreview() => _channel.invokeMethod('stopPreview');

  @override
  Future<RingSettings> ringSettings() async => RingSettings.fromMap(
    await _channel.invokeMethod<Map<Object?, Object?>>('ringSettings') ??
        const {},
  );

  @override
  Future<void> setRingSettings(RingSettings settings) =>
      _channel.invokeMethod('setRingSettings', settings.toMap());

  @override
  Future<void> pause(String id, DateTime until) =>
      _channel.invokeMethod('pause', {'id': id, 'until': dayKey(until)});

  @override
  Future<void> resume(String id) => _channel.invokeMethod('resume', {'id': id});

  @override
  Future<DateTime?> pauseAllUntil() async =>
      parseDay(await _channel.invokeMethod<String>('pauseAllUntil'));

  @override
  Future<void> setPauseAll(DateTime? until) => _channel.invokeMethod(
    'setPauseAll',
    {'until': until == null ? null : dayKey(until)},
  );

  @override
  Future<PickedSound?> pickSound(SoundKind kind) async {
    final m = await _channel.invokeMethod<Map<Object?, Object?>>('pickSound', {
      'kind': kind.name,
    });
    final sound = m?['sound'] as String?;
    if (sound == null) return null;
    return PickedSound(sound, m?['name'] as String? ?? '');
  }

  @override
  Future<bool> importSynced(ClockAlarm a) async =>
      await _channel.invokeMethod<bool>('importSynced', {
        'id': a.id,
        'hour': a.hour,
        'minute': a.minute,
        'days': a.days.toList()..sort(),
        'date': a.date,
        'skipDate': a.skipDate,
        'label': a.label,
        'vibrate': a.vibrate,
        'snoozeMinutes': a.snoozeMinutes,
        'enabled': a.enabled,
        'updatedAt': a.updatedAt,
        'pauseUntil': a.pauseUntil,
        'gradual': a.gradual,
        'ringMinutes': a.ringMinutes,
        'task': a.task?.name,
        'taskCode': a.taskCode,
        'skipHolidays': a.skipHolidays,
        'cycle': a.shift?.days,
        'cycleStart': a.shift?.start,
        'calendar': a.calendar?.toJson(),
        'smartWake': a.smartWake,
      }) ??
      false;

  @override
  Future<void> setCalendarPlans(Map<String, Object?> plans) =>
      _channel.invokeMethod('setCalendarPlans', {'json': jsonEncode(plans)});

  @override
  Future<void> setMorningBrief(String? json) =>
      _channel.invokeMethod('setMorningBrief', {'json': json});

  @override
  Future<void> setEnabled(String id, bool enabled) =>
      _channel.invokeMethod('setEnabled', {'id': id, 'enabled': enabled});

  @override
  Future<void> skipOnce(String id) =>
      _channel.invokeMethod('skipOnce', {'id': id});

  @override
  Future<void> undoSkip(String id) =>
      _channel.invokeMethod('undoSkip', {'id': id});

  @override
  Future<void> cancelSnooze(String id) =>
      _channel.invokeMethod('cancelSnooze', {'id': id});

  @override
  Future<void> delete(String id) => _channel.invokeMethod('delete', {'id': id});

  @override
  Future<void> testAlarm(int seconds) =>
      _channel.invokeMethod('testAlarm', {'seconds': seconds});

  @override
  Future<void> ringSnooze() => _channel.invokeMethod('ringSnooze');

  @override
  Future<void> ringDismiss() => _channel.invokeMethod('ringDismiss');

  @override
  Future<void> setLanguage(String? code) =>
      _channel.invokeMethod('setLanguage', {'code': code});

  @override
  Future<AlarmCheck> check() async => AlarmCheck.fromMap(
    await _channel.invokeMethod<Map<Object?, Object?>>('check') ?? const {},
  );

  @override
  Future<bool> requestNotifications() async =>
      await _channel.invokeMethod<bool>('requestNotifications') ?? false;

  @override
  Future<void> openSettings(String which) =>
      _channel.invokeMethod('openSettings', {'which': which});
}

enum SoundKind { ringtone, file }

/// The app's own alarm sounds besides the chime, as [ClockAlarm.sound]
/// values. They are part of the app, so they play before the first unlock.
const builtInSounds = [
  'builtin:bells',
  'builtin:beeps',
  'builtin:sunrise',
  'builtin:buzzer',
];

/// What the volume buttons do while an alarm rings on its screen.
enum VolumeButtons {
  /// Change the alarm volume, as everywhere else.
  volume,
  snooze,

  /// Dismiss. An alarm with a wake-up task still asks for it.
  dismiss;

  static VolumeButtons parse(Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return volume;
  }
}

/// Settings of every ring on this phone.
class RingSettings {
  const RingSettings({
    this.volumeButtons = VolumeButtons.volume,
    this.minVolume = 0,
    this.morning = MorningScreen.counts,
  });

  final VolumeButtons volumeButtons;

  /// "Ring at least this loud": percent of the phone's loudest alarm
  /// volume, one of [minVolumeChoices]. 0: off.
  final int minVolume;

  static const minVolumeChoices = [0, 30, 50, 70, 100];

  /// The day ahead after an alarm is dismissed.
  final MorningScreen morning;

  factory RingSettings.fromMap(Map<Object?, Object?> m) {
    final percent = switch (m['minVolume']) {
      final num n => n.toInt(),
      _ => 0,
    };
    return RingSettings(
      volumeButtons: VolumeButtons.parse(m['volumeButtons']),
      minVolume: minVolumeChoices.contains(percent) ? percent : 0,
      morning: MorningScreen.parse(m['morning']),
    );
  }

  Map<String, Object?> toMap() => {
    'volumeButtons': volumeButtons.name,
    'minVolume': minVolume,
    'morning': morning.name,
  };

  RingSettings copyWith({
    VolumeButtons? volumeButtons,
    int? minVolume,
    MorningScreen? morning,
  }) => RingSettings(
    volumeButtons: volumeButtons ?? this.volumeButtons,
    minVolume: minVolume ?? this.minVolume,
    morning: morning ?? this.morning,
  );
}

/// The morning screen after an alarm is dismissed: off, how many events,
/// tasks and quests today has, or with their names too (also over the
/// lock screen).
enum MorningScreen {
  off,
  counts,
  details;

  static MorningScreen parse(Object? v) => switch (v) {
    'off' => off,
    'details' => details,
    _ => counts,
  };
}

class PickedSound {
  const PickedSound(this.sound, this.name);
  final String sound;
  final String name;
}

/// A calendar day as the engine writes it: yyyy-MM-dd.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDay(String? key) {
  if (key == null) return null;
  final d = DateTime.tryParse(key);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// Tests override this with a fake engine.
final clockEngineProvider = Provider<ClockEngine>(
  (ref) => MethodChannelClockEngine(),
);

/// The alarms, earliest time of day first. Reloads when the engine says
/// they changed, and on [AlarmsController.refresh].
class AlarmsController extends AsyncNotifier<List<ClockAlarm>> {
  @override
  Future<List<ClockAlarm>> build() {
    final engine = ref.watch(clockEngineProvider);
    final sub = engine.changes.listen((_) => refresh());
    ref.onDispose(sub.cancel);
    return engine.list();
  }

  Future<void> refresh() async {
    try {
      final list = await ref.read(clockEngineProvider).list();
      if (ref.mounted) state = AsyncData(list);
    } on Object {
      // Keeps the last list; the next change or resume tries again.
    }
  }
}

final alarmsProvider =
    AsyncNotifierProvider<AlarmsController, List<ClockAlarm>>(
      AlarmsController.new,
    );

/// The Alarm check results. Invalidate to read them again (on resume,
/// after coming back from a system settings screen).
final alarmCheckProvider = FutureProvider<AlarmCheck>(
  (ref) => ref.watch(clockEngineProvider).check(),
);

/// "Pause all alarms until", or null. Invalidate after changing it.
final pauseAllProvider = FutureProvider<DateTime?>(
  (ref) => ref.watch(clockEngineProvider).pauseAllUntil(),
);

/// The timers, oldest first. Reloads when the engine says something
/// changed (a timer finished, a notification button was pressed).
class TimersController extends AsyncNotifier<List<ClockTimer>> {
  @override
  Future<List<ClockTimer>> build() {
    final engine = ref.watch(clockEngineProvider);
    final sub = engine.changes.listen((_) => refresh());
    ref.onDispose(sub.cancel);
    return engine.timers();
  }

  Future<void> refresh() async {
    try {
      final list = await ref.read(clockEngineProvider).timers();
      if (ref.mounted) state = AsyncData(list);
    } on Object {
      // Keeps the last list.
    }
  }
}

final timersProvider =
    AsyncNotifierProvider<TimersController, List<ClockTimer>>(
      TimersController.new,
    );

/// The stopwatch as the engine has it.
class StopwatchController extends AsyncNotifier<StopwatchState> {
  @override
  Future<StopwatchState> build() {
    final engine = ref.watch(clockEngineProvider);
    final sub = engine.changes.listen((_) => refresh());
    ref.onDispose(sub.cancel);
    return engine.stopwatch();
  }

  Future<void> refresh() async {
    try {
      final s = await ref.read(clockEngineProvider).stopwatch();
      if (ref.mounted) state = AsyncData(s);
    } on Object {
      // Keeps the last state.
    }
  }
}

final stopwatchProvider =
    AsyncNotifierProvider<StopwatchController, StopwatchState>(
      StopwatchController.new,
    );

/// Saves the bedtime's wake-up alarm: it rings at the schedule's wake-up
/// time on the mornings after its nights. Everything else about [alarm]
/// (sound, snooze, wake-up task and its code) stays as it is; with no
/// [alarm] a new one is made, named [label]. Returns its id.
Future<String> saveWakeAlarm(
  ClockEngine engine,
  BedtimeSchedule s,
  ClockAlarm? alarm, {
  required String label,
}) => engine.save(
  id: alarm?.id,
  hour: s.wakeHour,
  minute: s.wakeMinute,
  days: s.wakeDays,
  label: alarm?.label ?? label,
  vibrate: alarm?.vibrate ?? true,
  snoozeMinutes: alarm?.snoozeMinutes ?? 10,
  sound: alarm?.sound,
  soundName: alarm?.soundName,
  gradual: alarm?.gradual ?? false,
  ringMinutes: alarm?.ringMinutes ?? ClockAlarm.defaultRingMinutes,
  task: alarm?.task,
  taskCode: alarm?.taskCode,
  skipHolidays: alarm?.skipHolidays ?? false,
);

/// The bedtime schedule. [save] writes it to the engine, which sets the
/// reminder and Do Not Disturb.
class BedtimeController extends AsyncNotifier<BedtimeSchedule> {
  @override
  Future<BedtimeSchedule> build() => ref.watch(clockEngineProvider).bedtime();

  Future<void> save(BedtimeSchedule schedule) async {
    final before = state.value;
    state = AsyncData(schedule);
    await ref.read(clockEngineProvider).setBedtime(schedule);
    // A change to the part that is backed up (not this phone's switches).
    if (before == null ||
        jsonEncode(before.backup) != jsonEncode(schedule.backup)) {
      await ref.read(settingsEditsProvider).touch(settingsName);
    }
  }

  /// The group's name in the account's backup.
  static const settingsName = 'bedtime';

  /// Puts the account's schedule here. Whether it is on, Do Not Disturb,
  /// the sunrise and saving sleep stay this phone's own.
  ///
  /// A phone that has its own wake-up alarm switched on keeps it as the
  /// one Bedtime controls, moved to the account's times: the other
  /// phone's alarm arrives switched off here, and taking its id would
  /// leave this phone's own ringing with the Bedtime switch showing off.
  Future<void> restore(Map<String, Object?> backup) async {
    final before = await future;
    var schedule = before.withBackup(backup);
    final own = before.wakeAlarmId;
    if (own != null && own != schedule.wakeAlarmId) {
      final engine = ref.read(clockEngineProvider);
      try {
        final mine = (await engine.list())
            .where((a) => a.id == own && a.enabled)
            .firstOrNull;
        if (mine != null) {
          schedule = schedule.copyWith(wakeAlarmId: own);
          final days = schedule.wakeDays;
          if (mine.hour != schedule.wakeHour ||
              mine.minute != schedule.wakeMinute ||
              mine.days.length != days.length ||
              !mine.days.containsAll(days)) {
            await saveWakeAlarm(engine, schedule, mine, label: mine.label);
          }
        }
      } on Object {
        // The alarms can't be read: the account's schedule as it is.
      }
    }
    state = AsyncData(schedule);
    await ref.read(clockEngineProvider).setBedtime(schedule);
  }
}

final bedtimeProvider =
    AsyncNotifierProvider<BedtimeController, BedtimeSchedule>(
      BedtimeController.new,
    );

/// Whether the app has Do Not Disturb access. Invalidate after coming back
/// from Android's settings.
final dndAccessProvider = FutureProvider<bool>(
  (ref) => ref.watch(clockEngineProvider).dndAccess(),
);

/// Whether sleep can be saved to Health Connect, and is allowed.
/// Invalidate after coming back from Health Connect.
final sleepAccessProvider = FutureProvider<SleepAccess>(
  (ref) => ref.watch(clockEngineProvider).sleepAccess(),
);

/// Sleep sounds playing now. Reloads when the engine says something changed.
class SleepSoundController extends AsyncNotifier<SleepSoundState?> {
  @override
  Future<SleepSoundState?> build() {
    final engine = ref.watch(clockEngineProvider);
    final sub = engine.changes.listen((_) => refresh());
    ref.onDispose(sub.cancel);
    return engine.sleepSound();
  }

  Future<void> refresh() async {
    try {
      final s = await ref.read(clockEngineProvider).sleepSound();
      if (ref.mounted) state = AsyncData(s);
    } on Object {
      // Keeps the last state.
    }
  }
}

final sleepSoundProvider =
    AsyncNotifierProvider<SleepSoundController, SleepSoundState?>(
      SleepSoundController.new,
    );

/// Whether the night clock screensaver is dim red.
class ScreensaverNightController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(clockEngineProvider).screensaverNight();

  Future<void> set(bool on, {bool byHand = true}) async {
    state = AsyncData(on);
    await ref.read(clockEngineProvider).setScreensaverNight(on);
    if (byHand) await ref.read(settingsEditsProvider).touch(settingsName);
  }

  /// The group's name in the account's backup.
  static const settingsName = 'night-clock';
}

final screensaverNightProvider =
    AsyncNotifierProvider<ScreensaverNightController, bool>(
      ScreensaverNightController.new,
    );

/// What the volume buttons do while an alarm rings, and the least a ring
/// is loud.
class RingSettingsController extends AsyncNotifier<RingSettings> {
  @override
  Future<RingSettings> build() => ref.watch(clockEngineProvider).ringSettings();

  Future<void> set(RingSettings settings, {bool byHand = true}) async {
    state = AsyncData(settings);
    await ref.read(clockEngineProvider).setRingSettings(settings);
    if (byHand) await ref.read(settingsEditsProvider).touch(settingsName);
  }

  /// The group's name in the account's backup.
  static const settingsName = 'ring';
}

final ringSettingsProvider =
    AsyncNotifierProvider<RingSettingsController, RingSettings>(
      RingSettingsController.new,
    );
