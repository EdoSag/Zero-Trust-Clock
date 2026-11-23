import 'dart:convert';

/// Something to do before a ringing alarm can be dismissed, so it can't
/// be silenced half asleep. Snooze still works.
enum WakeTask {
  /// Solve three sums.
  math,

  /// Shake the phone 30 times.
  shake,

  /// Scan the code saved with the alarm (a QR code or a barcode), which
  /// is somewhere away from the bed. Needs [ClockAlarm.taskCode].
  scan;

  static WakeTask? parse(Object? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

/// "Ring in time for my first event": how an alarm follows ZT Calendar
/// (the engine's `CalendarLink`, which decides the times).
class CalendarLink {
  const CalendarLink({
    this.lead = 60,
    this.follow = false,
    this.earliest = 5 * 60,
    this.otherDays = false,
  });

  /// Minutes between the ring and the day's first event.
  final int lead;

  /// False: the alarm's own time, earlier when the first event needs it.
  /// True: [lead] minutes before the first event, later too; the alarm's
  /// own time on a day without events.
  final bool follow;

  /// Never earlier than this (minutes after midnight); events starting
  /// before it don't count.
  final int earliest;

  /// Also rings on days off, for an event before noon.
  final bool otherDays;

  static const leads = [15, 30, 45, 60, 75, 90, 120, 150, 180];

  Map<String, Object?> toJson() => {
    'lead': lead,
    'follow': follow,
    'earliest': earliest,
    'otherDays': otherDays,
  };

  static CalendarLink? fromJson(Object? j) {
    if (j is! Map) return null;
    return CalendarLink(
      lead: ((j['lead'] as num?)?.toInt() ?? 60).clamp(0, 360),
      follow: j['follow'] == true,
      earliest: ((j['earliest'] as num?)?.toInt() ?? 300).clamp(0, 1439),
      otherDays: j['otherDays'] == true,
    );
  }

  CalendarLink copyWith({
    int? lead,
    bool? follow,
    int? earliest,
    bool? otherDays,
  }) => CalendarLink(
    lead: lead ?? this.lead,
    follow: follow ?? this.follow,
    earliest: earliest ?? this.earliest,
    otherDays: otherDays ?? this.otherDays,
  );

  @override
  bool operator ==(Object other) =>
      other is CalendarLink &&
      other.lead == lead &&
      other.follow == follow &&
      other.earliest == earliest &&
      other.otherDays == otherDays;

  @override
  int get hashCode => Object.hash(lead, follow, earliest, otherDays);
}

/// A rotating shift pattern: [days] has one character per day of the
/// cycle, '1' rings and '0' is a day off; day 1 is [start] (yyyy-MM-dd).
class ShiftPattern {
  const ShiftPattern(this.days, this.start);

  final String days;
  final String start;

  static const minDays = 2;
  static const maxDays = 56;

  int get length => days.length;
  int get on => '1'.allMatches(days).length;

  /// Null unless it is a valid pattern (as the engine checks it).
  static ShiftPattern? of(String? days, String? start) {
    if (days == null || start == null) return null;
    if (days.length < minDays || days.length > maxDays) return null;
    if (!RegExp(r'^[01]+$').hasMatch(days) || !days.contains('1')) return null;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(start)) return null;
    return ShiftPattern(days, start);
  }

  /// Whether [day] is a day on, counting from [start] (before it too).
  bool ringsOn(DateTime day) {
    final p = start.split('-').map(int.parse).toList();
    final first = DateTime.utc(p[0], p[1], p[2]);
    final d = DateTime.utc(day.year, day.month, day.day);
    final diff = d.difference(first).inDays;
    return days[diff % length] == '1';
  }

  @override
  bool operator ==(Object other) =>
      other is ShiftPattern && other.days == days && other.start == start;

  @override
  int get hashCode => Object.hash(days, start);
}

/// The smart wake window's lengths in minutes (0: off).
const smartWakeChoices = [0, 10, 20, 30];

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
    this.date,
    this.skipDate,
    this.updatedAt = 0,
    this.pauseUntil,
    this.paused = false,
    this.sound,
    this.soundName,
    this.gradual = false,
    this.ringMinutes = defaultRingMinutes,
    this.task,
    this.taskCode,
    this.skipHolidays = false,
    this.shift,
    this.calendar,
    this.calendarThrough,
    this.smartWake = 0,
  });

  static const defaultRingMinutes = 10;

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

  /// Rings once: the day it rings (yyyy-MM-dd).
  final String? date;

  /// "Turn off once": the day of the skipped ring (yyyy-MM-dd).
  final String? skipDate;

  /// When it was last changed by hand, by the clock of the phone that
  /// changed it (epoch milliseconds). Sync keeps the newer side.
  final int updatedAt;

  /// "Pause until": silent through this day (yyyy-MM-dd), then on again.
  final String? pauseUntil;

  /// Silent now because of a pause (its own, or "Pause all").
  final bool paused;

  /// Null: the app's chime. "system": the phone's alarm sound. Else a sound
  /// picked on this phone (copied into the app). Not synced.
  final String? sound;

  /// What [sound] is called.
  final String? soundName;

  /// Starts quietly and gets louder over a minute.
  final bool gradual;

  /// An unanswered ring stops by itself after this many minutes.
  final int ringMinutes;

  /// Done before it can be dismissed; null: a slide dismisses it.
  final WakeTask? task;

  /// For [WakeTask.scan]: the saved code, as a hash (the engine never
  /// keeps what the code says).
  final String? taskCode;

  /// A repeating alarm stays silent on this phone's public holidays.
  final bool skipHolidays;

  /// Rings on a rotating shift pattern instead of weekdays ([days] empty).
  final ShiftPattern? shift;

  /// Linked to ZT Calendar: rings in time for the day's first event.
  final CalendarLink? calendar;

  /// The last day the engine knows ZT Calendar's events for (yyyy-MM-dd).
  final String? calendarThrough;

  /// Smart wake window: may ring up to this many minutes early when the
  /// phone feels movement. 0: off.
  final int smartWake;

  bool get repeats => days.isNotEmpty || shift != null;

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
      date: j['date'] as String?,
      skipDate: j['skipDate'] as String?,
      updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
      pauseUntil: j['pauseUntil'] as String?,
      paused: j['paused'] as bool? ?? false,
      sound: j['sound'] as String?,
      soundName: j['soundName'] as String?,
      gradual: j['gradual'] as bool? ?? false,
      ringMinutes: (j['ringMinutes'] as num?)?.toInt() ?? defaultRingMinutes,
      task: WakeTask.parse(j['task']),
      taskCode: j['taskCode'] as String?,
      skipHolidays: j['skipHolidays'] as bool? ?? false,
      shift: ShiftPattern.of(j['cycle'] as String?, j['cycleStart'] as String?),
      calendar: CalendarLink.fromJson(j['calendar']),
      calendarThrough: j['calendarThrough'] as String?,
      smartWake: smartWakeChoices.contains(j['smartWake'])
          ? (j['smartWake'] as num).toInt()
          : 0,
    );
  }

  ClockAlarm copyWith({bool? enabled, String? label, int? updatedAt}) =>
      ClockAlarm(
        id: id,
        hour: hour,
        minute: minute,
        days: days,
        enabled: enabled ?? this.enabled,
        label: label ?? this.label,
        vibrate: vibrate,
        snoozeMinutes: snoozeMinutes,
        snoozeUntil: snoozeUntil,
        nextRing: nextRing,
        skipActive: skipActive,
        ringing: ringing,
        date: date,
        skipDate: skipDate,
        updatedAt: updatedAt ?? this.updatedAt,
        pauseUntil: pauseUntil,
        paused: paused,
        sound: sound,
        soundName: soundName,
        gradual: gradual,
        ringMinutes: ringMinutes,
        task: task,
        taskCode: taskCode,
        skipHolidays: skipHolidays,
        shift: shift,
        calendar: calendar,
        calendarThrough: calendarThrough,
        smartWake: smartWake,
      );

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

/// Phone makers whose own battery saving can stop a closed app.
enum BatteryBrand { xiaomi, huawei, samsung }

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
    this.maker = '',
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

  /// The phone's maker and brand, lower case ("xiaomi redmi").
  final String maker;

  /// The maker's own battery saving that can stop a closed app, if this
  /// phone is from one of them. Advice only: Android can't tell the app
  /// how it is set, so it is not counted in [problems].
  BatteryBrand? get batteryBrand {
    bool any(List<String> names) => names.any(maker.contains);
    if (any(const ['xiaomi', 'redmi', 'poco'])) return BatteryBrand.xiaomi;
    if (any(const ['huawei', 'honor'])) return BatteryBrand.huawei;
    if (any(const ['samsung'])) return BatteryBrand.samsung;
    return null;
  }

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
      maker: m['maker'] as String? ?? '',
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
