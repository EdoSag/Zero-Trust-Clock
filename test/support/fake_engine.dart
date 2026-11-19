import 'dart:async';

import 'package:zerotrust_clock/engine/alarm.dart';
import 'package:zerotrust_clock/engine/clock_engine.dart';

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
    DateTime? date,
  }) async {
    _mayFail();
    lastSave = {
      'sound': sound,
      'soundName': soundName,
      'gradual': gradual,
      'ringMinutes': ringMinutes,
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

  /// As when an alarm rings or is dismissed outside the app.
  void changedOutside() => _changes.add(null);
}
