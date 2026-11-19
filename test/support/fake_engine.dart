import 'dart:async';

import 'package:zerotrust_clock/engine/alarm.dart';
import 'package:zerotrust_clock/engine/bedtime.dart';
import 'package:zerotrust_clock/engine/clock_engine.dart';
import 'package:zerotrust_clock/engine/clock_timer.dart';
import 'package:zerotrust_clock/world/world_zone.dart';

ClockAlarm alarm(
  String id, {
  int hour = 7,
  int minute = 0,
  Set<int> days = const {},
  bool enabled = true,
  String label = '',
  bool vibrate = true,
  int snoozeMinutes = 10,
  DateTime? snoozeUntil,
  DateTime? nextRing,
  bool skipActive = false,
  bool ringing = false,
  String? date,
  String? skipDate,
  int updatedAt = 0,
  String? pauseUntil,
  bool paused = false,
  String? sound,
  String? soundName,
  bool gradual = false,
  int ringMinutes = ClockAlarm.defaultRingMinutes,
  WakeTask? task,
  bool skipHolidays = false,
}) => ClockAlarm(
  id: id,
  hour: hour,
  minute: minute,
  days: days,
  enabled: enabled,
  label: label,
  vibrate: vibrate,
  snoozeMinutes: snoozeMinutes,
  snoozeUntil: snoozeUntil,
  nextRing: nextRing ?? (enabled ? DateTime.now().add(nextIn) : null),
  skipActive: skipActive,
  ringing: ringing,
  date: date,
  skipDate: skipDate,
  updatedAt: updatedAt,
  pauseUntil: pauseUntil,
  paused: paused,
  sound: sound,
  soundName: soundName,
  gradual: gradual,
  ringMinutes: ringMinutes,
  task: task,
  skipHolidays: skipHolidays,
);

/// When a switched-on alarm rings next in the fake engine.
const nextIn = Duration(hours: 8);

/// Stands in for the alarm engine on the phone. It keeps the alarms in
/// memory and notes every call.
class FakeClockEngine implements ClockEngine {
  FakeClockEngine({
    List<ClockAlarm> alarms = const [],
    this.checkResult = const AlarmCheck(),
  }) : alarms = [...alarms];

  final List<ClockAlarm> alarms;
  AlarmCheck checkResult;
  final List<String> calls = [];
  String? language = 'unset';
  bool grantNotifications = true;
  bool failNext = false;
  int _ids = 0;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  void _mayFail() {
    if (failNext) {
      failNext = false;
      throw StateError('engine refused');
    }
  }

  /// The fake's clock for edits: every change by hand is a later edit.
  int editTime = 1000;

  void _replace(String id, ClockAlarm Function(ClockAlarm) how) {
    final i = alarms.indexWhere((a) => a.id == id);
    if (i < 0) return;
    alarms[i] = how(alarms[i]).copyWith(updatedAt: _editTimeAfter(alarms[i]));
  }

  /// As the engine: an edit is always later than the alarm's last one.
  int _editTimeAfter(ClockAlarm? old) {
    editTime = old == null || editTime + 1 > old.updatedAt
        ? editTime + 1
        : old.updatedAt + 1;
    return editTime;
  }

  /// The options of the last save beyond those in [calls].
  Map<String, Object?> lastSave = {};

  DateTime? pausedAllUntil;

  /// What [pickSound] answers (null: cancelled).
  PickedSound? soundToPick;

  @override
  Future<void> pause(String id, DateTime until) async {
    _mayFail();
    calls.add('pause $id ${dayKey(until)}');
    _replace(
      id,
      (a) => alarm(
        a.id,
        hour: a.hour,
        minute: a.minute,
        days: a.days,
        label: a.label,
        pauseUntil: dayKey(until),
        paused: true,
        nextRing: DateTime(until.year, until.month, until.day + 1, a.hour),
      ),
    );
  }

  @override
  Future<void> resume(String id) async {
    _mayFail();
    calls.add('resume $id');
    _replace(
      id,
      (a) => alarm(
        a.id,
        hour: a.hour,
        minute: a.minute,
        days: a.days,
        label: a.label,
      ),
    );
  }

  @override
  Future<DateTime?> pauseAllUntil() async => pausedAllUntil;

  @override
  Future<void> setPauseAll(DateTime? until) async {
    _mayFail();
    calls.add('setPauseAll ${until == null ? 'off' : dayKey(until)}');
    pausedAllUntil = until;
  }

  @override
  Future<PickedSound?> pickSound(SoundKind kind) async {
    calls.add('pickSound ${kind.name}');
    return soundToPick;
  }

  /// Imports refused, as while that alarm rings.
  final Set<String> ringingIds = {};

  @override
  Future<bool> importSynced(ClockAlarm a) async {
    calls.add('importSynced ${a.id} ${a.enabled}');
    if (ringingIds.contains(a.id)) return false;
    final i = alarms.indexWhere((x) => x.id == a.id);
    final copy = alarm(
      a.id,
      hour: a.hour,
      minute: a.minute,
      days: a.days,
      enabled: a.enabled,
      label: a.label,
      vibrate: a.vibrate,
      snoozeMinutes: a.snoozeMinutes,
      date: a.date,
      skipDate: a.skipDate,
      updatedAt: a.updatedAt,
    );
    if (i >= 0) {
      alarms[i] = copy;
    } else {
      alarms.add(copy);
    }
    return true;
  }

  @override
  Future<List<ClockAlarm>> list() async => [
    ...alarms,
  ]..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

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
    bool skipHolidays = false,
    DateTime? date,
  }) async {
    _mayFail();
    lastSave = {
      'sound': sound,
      'soundName': soundName,
      'gradual': gradual,
      'ringMinutes': ringMinutes,
      'task': task?.name,
      'skipHolidays': skipHolidays,
      'date': date == null ? null : dayKey(date),
    };
    final days0 = (days.toList()..sort()).join('');
    calls.add(
      'save ${id ?? 'new'} $hour:$minute [$days0] "$label" '
      '$vibrate $snoozeMinutes',
    );
    final saved = alarm(
      id ?? 'new-${++_ids}',
      hour: hour,
      minute: minute,
      days: days,
      label: label,
      vibrate: vibrate,
      snoozeMinutes: snoozeMinutes,
      updatedAt: _editTimeAfter(alarms.where((a) => a.id == id).firstOrNull),
      sound: sound,
      soundName: sound == null ? null : soundName,
      gradual: gradual,
      ringMinutes: ringMinutes,
      task: task,
      skipHolidays: skipHolidays,
      date: days.isEmpty && date != null ? dayKey(date) : null,
    );
    final i = alarms.indexWhere((a) => a.id == saved.id);
    if (i >= 0) {
      alarms[i] = saved;
    } else {
      alarms.add(saved);
    }
    return saved.id;
  }

  @override
  Future<void> setEnabled(String id, bool enabled) async {
    _mayFail();
    calls.add('setEnabled $id $enabled');
    _replace(
      id,
      (a) => alarm(
        a.id,
        hour: a.hour,
        minute: a.minute,
        days: a.days,
        label: a.label,
        enabled: enabled,
      ),
    );
  }

  @override
  Future<void> skipOnce(String id) async {
    _mayFail();
    calls.add('skipOnce $id');
    _replace(
      id,
      (a) => alarm(
        a.id,
        hour: a.hour,
        minute: a.minute,
        days: a.days,
        label: a.label,
        skipActive: true,
        nextRing: a.nextRing?.add(const Duration(days: 1)),
      ),
    );
  }

  @override
  Future<void> undoSkip(String id) async {
    _mayFail();
    calls.add('undoSkip $id');
    _replace(
      id,
      (a) => alarm(
        a.id,
        hour: a.hour,
        minute: a.minute,
        days: a.days,
        label: a.label,
      ),
    );
  }

  @override
  Future<void> cancelSnooze(String id) async {
    calls.add('cancelSnooze $id');
    _replace(
      id,
      (a) => alarm(
        a.id,
        hour: a.hour,
        minute: a.minute,
        days: a.days,
        label: a.label,
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    _mayFail();
    calls.add('delete $id');
    alarms.removeWhere((a) => a.id == id);
  }

  @override
  Future<void> testAlarm(int seconds) async {
    _mayFail();
    calls.add('testAlarm $seconds');
  }

  void _endRing(String call) {
    calls.add(call);
    for (final a in [...alarms]) {
      if (a.ringing) {
        _replace(
          a.id,
          (a) => alarm(
            a.id,
            hour: a.hour,
            minute: a.minute,
            days: a.days,
            label: a.label,
          ),
        );
      }
    }
  }

  @override
  Future<void> ringSnooze() async => _endRing('ringSnooze');

  @override
  Future<void> ringDismiss() async => _endRing('ringDismiss');

  @override
  Future<void> setLanguage(String? code) async {
    calls.add('setLanguage $code');
    language = code;
  }

  @override
  Future<AlarmCheck> check() async => checkResult;

  @override
  Future<bool> requestNotifications() async {
    calls.add('requestNotifications');
    return grantNotifications;
  }

  @override
  Future<void> openSettings(String which) async {
    calls.add('openSettings $which');
  }

  // Timers and the stopwatch.

  final List<ClockTimer> timerList = [];
  StopwatchState stopwatchState = const StopwatchState();
  String? tabAtLaunch;
  final _tabs = StreamController<String>.broadcast();
  int _timerIds = 0;

  /// As when a notification opens a tab while the app is open.
  void openTabOutside(String tab) => _tabs.add(tab);

  @override
  Stream<String> get openTab => _tabs.stream;

  @override
  Future<String?> launchTab() async {
    final tab = tabAtLaunch;
    tabAtLaunch = null;
    return tab;
  }

  @override
  Future<List<ClockTimer>> timers() async => [...timerList];

  void _timer(String id, ClockTimer Function(ClockTimer) how) {
    final i = timerList.indexWhere((t) => t.id == id);
    if (i >= 0) timerList[i] = how(timerList[i]);
  }

  ClockTimer _copy(
    ClockTimer t, {
    DateTime? endsAt,
    Duration? left,
    bool ringing = false,
    String? label,
  }) => ClockTimer(
    id: t.id,
    length: t.length,
    label: label ?? t.label,
    endsAt: endsAt,
    left: left ?? t.length,
    ringing: ringing,
    createdAt: t.createdAt,
  );

  @override
  Future<String> addTimer(
    Duration length, {
    String label = '',
    bool start = true,
  }) async {
    _mayFail();
    calls.add('addTimer ${length.inSeconds}s');
    final t = ClockTimer(
      id: 'timer-${++_timerIds}',
      length: length,
      label: label,
      endsAt: start ? DateTime.now().add(length) : null,
      createdAt: DateTime.now(),
    );
    timerList.add(t);
    return t.id;
  }

  @override
  Future<void> startTimer(String id) async {
    calls.add('startTimer $id');
    _timer(id, (t) => _copy(t, endsAt: DateTime.now().add(t.left)));
  }

  @override
  Future<void> pauseTimer(String id) async {
    calls.add('pauseTimer $id');
    _timer(id, (t) => _copy(t, left: t.endsAt!.difference(DateTime.now())));
  }

  @override
  Future<void> addTimerMinute(String id) async {
    calls.add('addTimerMinute $id');
    const minute = Duration(minutes: 1);
    _timer(
      id,
      (t) => t.ringing
          ? _copy(t, endsAt: DateTime.now().add(minute))
          : t.endsAt != null
          ? _copy(t, endsAt: t.endsAt!.add(minute))
          : _copy(t, left: t.left + minute),
    );
  }

  @override
  Future<void> resetTimer(String id) async {
    calls.add('resetTimer $id');
    _timer(id, (t) => _copy(t));
  }

  @override
  Future<void> setTimerLabel(String id, String label) async {
    calls.add('setTimerLabel $id "$label"');
    _timer(
      id,
      (t) => _copy(
        t,
        label: label,
        endsAt: t.endsAt,
        left: t.left,
        ringing: t.ringing,
      ),
    );
  }

  @override
  Future<void> deleteTimer(String id) async {
    calls.add('deleteTimer $id');
    timerList.removeWhere((t) => t.id == id);
  }

  @override
  Future<void> stopRingingTimers() async {
    calls.add('stopRingingTimers');
    for (final t in [...timerList]) {
      if (t.ringing) _timer(t.id, (t) => _copy(t));
    }
  }

  @override
  Future<StopwatchState> stopwatch() async => stopwatchState;

  @override
  Future<void> stopwatchStart() async {
    calls.add('stopwatchStart');
    final s = stopwatchState;
    if (!s.running) {
      stopwatchState = StopwatchState(
        startedAt: DateTime.now(),
        banked: s.banked,
        laps: s.laps,
      );
    }
  }

  @override
  Future<void> stopwatchPause() async {
    calls.add('stopwatchPause');
    final s = stopwatchState;
    stopwatchState = StopwatchState(
      banked: s.elapsed(DateTime.now()),
      laps: s.laps,
    );
  }

  @override
  Future<void> stopwatchLap() async {
    calls.add('stopwatchLap');
    final s = stopwatchState;
    stopwatchState = StopwatchState(
      startedAt: s.startedAt,
      banked: s.banked,
      laps: [...s.laps, s.elapsed(DateTime.now())],
    );
  }

  @override
  Future<void> stopwatchReset() async {
    calls.add('stopwatchReset');
    stopwatchState = const StopwatchState();
  }

  // World clock.

  List<WorldZone> zoneList = const [
    WorldZone(
      id: 'Asia/Tokyo',
      city: 'Tokyo',
      country: 'Japan',
      offset: Duration(hours: 9),
    ),
    WorldZone(
      id: 'America/New_York',
      city: 'New York',
      country: 'United States',
      offset: Duration(hours: -5),
    ),
    WorldZone(
      id: 'Asia/Kolkata',
      city: 'Kolkata',
      country: 'India',
      offset: Duration(hours: 5, minutes: 30),
    ),
    WorldZone(
      id: 'Europe/London',
      city: 'London',
      country: 'United Kingdom',
      offset: Duration.zero,
    ),
  ];
  List<String>? widgetCities;

  @override
  Future<List<WorldZone>> zones() async => zoneList;

  @override
  Future<Map<String, Duration>> zoneOffsets(List<String> ids) async => {
    for (final z in zoneList)
      if (ids.contains(z.id)) z.id: z.offset,
  };

  @override
  Future<void> setWorldCities(List<String> ids) async {
    calls.add('setWorldCities ${ids.join(',')}');
    widgetCities = ids;
  }

  // Public holidays.

  List<String> holidayDays = [];

  @override
  Future<List<String>> holidays() async => holidayDays;

  @override
  Future<void> setHolidays(List<String> days) async {
    calls.add('setHolidays ${days.join(',')}');
    holidayDays = days;
  }

  // Screensaver.

  bool night = true;

  @override
  Future<bool> screensaverNight() async => night;

  @override
  Future<void> setScreensaverNight(bool on) async {
    calls.add('setScreensaverNight $on');
    night = on;
  }

  // Bedtime.

  BedtimeSchedule schedule = const BedtimeSchedule();
  bool hasDndAccess = true;
  SleepSoundState? playing;

  @override
  Future<BedtimeSchedule> bedtime() async => schedule;

  @override
  Future<void> setBedtime(BedtimeSchedule s) async {
    _mayFail();
    calls.add('setBedtime ${s.toJson()}');
    schedule = s;
  }

  @override
  Future<bool> dndAccess() async => hasDndAccess;

  @override
  Future<SleepSoundState?> sleepSound() async => playing;

  @override
  Future<void> playSleepSound(SleepSound sound, int minutes) async {
    _mayFail();
    calls.add('playSleepSound ${sound.name} $minutes');
    playing = SleepSoundState(
      sound,
      DateTime.now().add(Duration(minutes: minutes)),
    );
  }

  @override
  Future<void> stopSleepSound() async {
    calls.add('stopSleepSound');
    playing = null;
  }

  /// As when an alarm rings or is dismissed outside the app.
  void changedOutside() => _changes.add(null);
}
