import 'dart:convert';

/// One alarm, as the engine on the phone reports it. The engine (Kotlin,
/// `android/.../engine`) owns the alarms and decides when they ring; the
/// screens only show what it says, so the time on screen is the time it
/// rings.
class ClockAlarm {
  const ClockAlarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.days = const {},
    this.enabled = true,
    this.label = '',
    this.vibrate = true,
    this.snoozeMinutes = 10,
    this.snoozeUntil,
    this.nextRing,
    this.skipActive = false,
    this.ringing = false,
  });

  final String id;
  final int hour;
  final int minute;

  /// Repeat days, ISO numbers: 1 = Monday .. 7 = Sunday. Empty: rings once.
  final Set<int> days;
  final bool enabled;
  final String label;
  final bool vibrate;
  final int snoozeMinutes;

  /// While snoozed: when it rings again.
  final DateTime? snoozeUntil;

  /// The next regular ring, already after any "Turn off once". Null when
  /// the alarm is off.
  final DateTime? nextRing;

  /// "Turn off once" is waiting: the next ring is skipped, the alarm is on.
  final bool skipActive;

  /// Ringing right now.
  final bool ringing;

  bool get repeats => days.isNotEmpty;

  factory ClockAlarm.fromJson(Map<String, dynamic> j) {
    DateTime? time(Object? ms) =>
        ms is num ? DateTime.fromMillisecondsSinceEpoch(ms.toInt()) : null;
    return ClockAlarm(
      id: j['id'] as String,
      hour: (j['hour'] as num).toInt(),
      minute: (j['minute'] as num).toInt(),
      days: {
        for (final d in (j['days'] as List? ?? const []))
          if (d is num && d >= 1 && d <= 7) d.toInt(),
      },
      enabled: j['enabled'] as bool? ?? true,
      label: j['label'] as String? ?? '',
      vibrate: j['vibrate'] as bool? ?? true,
      snoozeMinutes: (j['snoozeMinutes'] as num?)?.toInt() ?? 10,
      snoozeUntil: time(j['snoozeUntil']),
      nextRing: time(j['nextRing']),
      skipActive: j['skipActive'] as bool? ?? false,
      ringing: j['ringing'] as bool? ?? false,
    );
  }

  /// The engine's list, earliest time of day first.
  static List<ClockAlarm> listFromJson(String json) {
    final list = [
      for (final e in jsonDecode(json) as List)
        ClockAlarm.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
    list.sort((a, b) {
      final byTime = (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return list;
  }
}

/// What can stop an alarm from ringing properly on this phone, as the
/// Alarm check screen shows it.
class AlarmCheck {
  const AlarmCheck({
    this.notifications = true,
    this.ringChannel = true,
    this.fullScreen = true,
    this.exactAlarms = true,
    this.alarmVolume = 1,
    this.alarmVolumeMax = 1,
    this.totalSilence = false,
    this.ownerProfile = true,
    this.bootAt,
    this.bootLocked = false,
  });

  /// Notifications are on for the app.
  final bool notifications;

  /// The "Ringing alarms" notification kind is at its normal level.
  final bool ringChannel;

  /// The alarm screen may open over the lock screen.
  final bool fullScreen;

  /// Alarms may be set to the exact minute.
  final bool exactAlarms;
  final int alarmVolume;
  final int alarmVolumeMax;

  /// Do Not Disturb's "total silence", which mutes alarms too.
  final bool totalSilence;

  /// The phone's main profile. Android stops a secondary profile's apps
  /// when it is ended, alarms included.
  final bool ownerProfile;

  /// When alarms were last set again after a restart, if ever.
  final DateTime? bootAt;

  /// That happened before the phone's first unlock.
  final bool bootLocked;

  factory AlarmCheck.fromMap(Map<Object?, Object?> m) {
    final boot = (m['bootAt'] as num?)?.toInt() ?? 0;
    return AlarmCheck(
      notifications: m['notifications'] as bool? ?? true,
      ringChannel: m['ringChannel'] as bool? ?? true,
      fullScreen: m['fullScreen'] as bool? ?? true,
      exactAlarms: m['exactAlarms'] as bool? ?? true,
      alarmVolume: (m['alarmVolume'] as num?)?.toInt() ?? 1,
      alarmVolumeMax: (m['alarmVolumeMax'] as num?)?.toInt() ?? 1,
      totalSilence: m['totalSilence'] as bool? ?? false,
      ownerProfile: m['ownerProfile'] as bool? ?? true,
      bootAt: boot > 0 ? DateTime.fromMillisecondsSinceEpoch(boot) : null,
      bootLocked: m['bootLocked'] as bool? ?? false,
    );
  }

  bool get volumeZero => alarmVolume <= 0;

  /// How many things need attention.
  int get problems => [
    !notifications,
    notifications && !ringChannel,
    !fullScreen,
    !exactAlarms,
    volumeZero,
    totalSilence,
    !ownerProfile,
  ].where((bad) => bad).length;
}
