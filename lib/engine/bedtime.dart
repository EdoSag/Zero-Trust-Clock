import 'dart:convert';

/// The bedtime schedule, as the engine keeps it. [nights] are the evenings
/// it starts on (ISO 1 = Monday .. 7 = Sunday).
class BedtimeSchedule {
  const BedtimeSchedule({
    this.enabled = false,
    this.bedHour = 23,
    this.bedMinute = 0,
    this.wakeHour = 7,
    this.wakeMinute = 0,
    this.nights = const {1, 2, 3, 4, 5, 6, 7},
    this.reminderMinutes = 15,
    this.doNotDisturb = false,
    this.wakeAlarmId,
  });

  final bool enabled;
  final int bedHour;
  final int bedMinute;
  final int wakeHour;
  final int wakeMinute;
  final Set<int> nights;

  /// 0: no reminder.
  final int reminderMinutes;
  final bool doNotDisturb;

  /// The alarm made from this schedule to wake up, if any.
  final String? wakeAlarmId;

  int get _bed => bedHour * 60 + bedMinute;
  int get _wake => wakeHour * 60 + wakeMinute;

  /// How long a night is: 23:00 to 07:00 is 8 hours.
  Duration get length {
    var m = _wake - _bed;
    if (m <= 0) m += 24 * 60;
    return Duration(minutes: m);
  }

  /// The mornings it ends on: the next day when the night crosses midnight.
  Set<int> get wakeDays =>
      _wake <= _bed ? {for (final d in nights) d % 7 + 1} : nights;

  BedtimeSchedule copyWith({
    bool? enabled,
    int? bedHour,
    int? bedMinute,
    int? wakeHour,
    int? wakeMinute,
    Set<int>? nights,
    int? reminderMinutes,
    bool? doNotDisturb,
    String? wakeAlarmId,
  }) => BedtimeSchedule(
    enabled: enabled ?? this.enabled,
    bedHour: bedHour ?? this.bedHour,
    bedMinute: bedMinute ?? this.bedMinute,
    wakeHour: wakeHour ?? this.wakeHour,
    wakeMinute: wakeMinute ?? this.wakeMinute,
    nights: nights ?? this.nights,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    doNotDisturb: doNotDisturb ?? this.doNotDisturb,
    wakeAlarmId: wakeAlarmId ?? this.wakeAlarmId,
  );

  String toJson() => jsonEncode({
    'enabled': enabled,
    'bedHour': bedHour,
    'bedMinute': bedMinute,
    'wakeHour': wakeHour,
    'wakeMinute': wakeMinute,
    'nights': nights.toList()..sort(),
    'reminderMinutes': reminderMinutes,
    'doNotDisturb': doNotDisturb,
    'wakeAlarmId': ?wakeAlarmId,
  });

  static BedtimeSchedule fromJson(String json) {
    final m = (jsonDecode(json) as Map).cast<String, Object?>();
    return BedtimeSchedule(
      enabled: m['enabled'] as bool? ?? false,
      bedHour: (m['bedHour'] as num?)?.toInt() ?? 23,
      bedMinute: (m['bedMinute'] as num?)?.toInt() ?? 0,
      wakeHour: (m['wakeHour'] as num?)?.toInt() ?? 7,
      wakeMinute: (m['wakeMinute'] as num?)?.toInt() ?? 0,
      nights: {
        for (final d in (m['nights'] as List?) ?? const [])
          if (d is num) d.toInt(),
      },
      reminderMinutes: (m['reminderMinutes'] as num?)?.toInt() ?? 15,
      doNotDisturb: m['doNotDisturb'] as bool? ?? false,
      wakeAlarmId: m['wakeAlarmId'] as String?,
    );
  }
}

enum SleepSound { white, pink, brown }

/// Sleep sounds playing now.
class SleepSoundState {
  const SleepSoundState(this.sound, this.endsAt);
  final SleepSound sound;
  final DateTime endsAt;
}
