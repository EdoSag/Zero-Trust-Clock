import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alarm.dart';

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
  });

  Future<void> setEnabled(String id, bool enabled);

  /// Takes an alarm as the account's backup has it, keeping its
  /// [ClockAlarm.updatedAt]. [ClockAlarm.enabled] is this phone's own
  /// switch. False while that alarm rings (nothing changed; try later).
  Future<bool> importSynced(ClockAlarm alarm);

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
}

class MethodChannelClockEngine implements ClockEngine {
  MethodChannelClockEngine() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') _changes.add(null);
    });
  }

  static const _channel = MethodChannel('dev.sagron.zerotrustclock/engine');
  final _changes = StreamController<void>.broadcast();

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
  }) async =>
      await _channel.invokeMethod<String>('save', {
        'id': id,
        'hour': hour,
        'minute': minute,
        'days': days.toList()..sort(),
        'label': label,
        'vibrate': vibrate,
        'snoozeMinutes': snoozeMinutes,
      }) ??
      '';

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
      }) ??
      false;

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
