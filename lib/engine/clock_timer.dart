import 'dart:convert';

/// One countdown timer, as the engine on the phone reports it. The engine
/// runs and rings it (also with the app closed); the screens show it.
class ClockTimer {
  const ClockTimer({
    required this.id,
    required this.length,
    this.label = '',
    this.endsAt,
    Duration? left,
    this.ringing = false,
    this.createdAt,
  }) : left = left ?? length;

  final String id;

  /// What it was set to; Reset goes back to it.
  final Duration length;
  final String label;

  /// Running: when it reaches zero. Ringing: when it did.
  final DateTime? endsAt;

  /// Paused or not started: the time left.
  final Duration left;
  final bool ringing;
  final DateTime? createdAt;

  bool get running => endsAt != null && !ringing;
  bool get paused => endsAt == null && !ringing && left != length;

  /// Set and not started (or reset).
  bool get idle => endsAt == null && !ringing && left == length;

  /// Time left at [now]; negative while ringing (time since it ended).
  Duration leftAt(DateTime now) => endsAt?.difference(now) ?? left;

  /// How far along it is, 0 (just set) to 1 (done).
  double progress(DateTime now) {
    if (ringing) return 1;
    final total = length.inMilliseconds;
    final l = leftAt(now).inMilliseconds;
    // "+1:00" can leave more than the length.
    final whole = l > total ? l : total;
    if (whole <= 0) return 1;
    return (1 - l / whole).clamp(0.0, 1.0);
  }

  static ClockTimer fromJson(Map<String, Object?> m) {
    final length = Duration(
      milliseconds: (m['lengthMs'] as num?)?.toInt() ?? 0,
    );
    final endsAt = (m['endsAt'] as num?)?.toInt();
    final created = (m['createdAt'] as num?)?.toInt();
    return ClockTimer(
      id: m['id'] as String,
      length: length,
      label: m['label'] as String? ?? '',
      endsAt: endsAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endsAt),
      left: Duration(
        milliseconds: (m['leftMs'] as num?)?.toInt() ?? length.inMilliseconds,
      ),
      ringing: m['ringing'] as bool? ?? false,
      createdAt: created == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(created),
    );
  }

  static List<ClockTimer> listFromJson(String json) => [
    for (final m in jsonDecode(json) as List)
      fromJson((m as Map).cast<String, Object?>()),
  ];
}

/// The stopwatch. Laps are the total time at each lap press, oldest first.
class StopwatchState {
  const StopwatchState({
    this.startedAt,
    this.banked = Duration.zero,
    this.laps = const [],
  });

  final DateTime? startedAt;

  /// Counted before the last start.
  final Duration banked;
  final List<Duration> laps;

  bool get running => startedAt != null;
  bool get zero => !running && banked == Duration.zero && laps.isEmpty;

  Duration elapsed(DateTime now) {
    final since = startedAt == null
        ? Duration.zero
        : now.difference(startedAt!);
    return banked + (since.isNegative ? Duration.zero : since);
  }

  /// The time of each lap on its own, oldest first.
  List<Duration> get lapTimes => [
    for (var i = 0; i < laps.length; i++)
      laps[i] - (i == 0 ? Duration.zero : laps[i - 1]),
  ];

  static StopwatchState fromJson(String json) {
    final m = (jsonDecode(json) as Map).cast<String, Object?>();
    final started = (m['startedAt'] as num?)?.toInt();
    return StopwatchState(
      startedAt: started == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(started),
      banked: Duration(milliseconds: (m['banked'] as num?)?.toInt() ?? 0),
      laps: [
        for (final l in (m['laps'] as List?) ?? const [])
          Duration(milliseconds: (l as num).toInt()),
      ],
    );
  }
}
