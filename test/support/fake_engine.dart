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

  void _replace(String id, ClockAlarm Function(ClockAlarm) how) {
    final i = alarms.indexWhere((a) => a.id == id);
    if (i >= 0) alarms[i] = how(alarms[i]);
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
  }) async {
    _mayFail();
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
