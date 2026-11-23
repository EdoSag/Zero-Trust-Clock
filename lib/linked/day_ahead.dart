import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'recurrence.dart';

/// What Clock reads from the other Zero-Trust apps for the day ahead: the
/// first ZT Calendar event of each day (for alarms linked to the
/// calendar) and the morning screen's events, tasks and quests.
///
/// Everything here is plain data and pure functions, so it is tested
/// without a phone or an account. The items come from the account,
/// opened with each app's own key (see `linked_apps.dart`); only what is
/// worked out here goes to the engine.

/// How many days ahead Clock reads (from today). An alarm further ahead
/// than this rings at its own time until the app is opened again.
const dayAheadDays = 14;

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

bool _tzReady = false;

/// The IANA zone [id] ("Europe/Berlin"), or null when unknown.
tz.Location? zoneFor(String? id) {
  if (id == null || id.isEmpty) return null;
  if (!_tzReady) {
    tzdata.initializeTimeZones();
    _tzReady = true;
  }
  try {
    return tz.getLocation(id);
  } on Object {
    return null;
  }
}

DateTime _wallClockIn(tz.Location zone, DateTime t) {
  final z = tz.TZDateTime.from(t, zone);
  return DateTime(z.year, z.month, z.day, z.hour, z.minute, z.second);
}

DateTime _instantFromWall(tz.Location zone, DateTime wall) {
  final z = tz.TZDateTime(
    zone,
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
  );
  return DateTime.fromMillisecondsSinceEpoch(z.millisecondsSinceEpoch);
}

/// A ZT Calendar event, as much of it as Clock needs (ZT Calendar's
/// `CalendarEvent`, JSON version 1). Times are local; all-day events
/// keep plain dates.
class LinkedEvent {
  const LinkedEvent({
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.calendarId = 'default',
    this.rrule,
    this.exceptions = const {},
    this.timeZone,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String calendarId;
  final String? rrule;
  final Set<DateTime> exceptions;
  final String? timeZone;

  static DateTime? _parseDate(Object? v) {
    if (v is! String) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(v);
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }
    return DateTime.tryParse(v)?.toLocal();
  }

  /// An event item's JSON; null when its dates can't be read.
  static LinkedEvent? fromJson(Map<String, Object?> j, {String? calendarId}) {
    final start = _parseDate(j['start']);
    if (start == null) return null;
    final allDay = j['allDay'] == true;
    var end = _parseDate(j['end']);
    if (end == null || end.isBefore(start)) {
      end = allDay
          ? DateTime(start.year, start.month, start.day + 1)
          : start.add(const Duration(hours: 1));
    }
    return LinkedEvent(
      title: ((j['title'] as String?) ?? '').trim(),
      start: start,
      end: end,
      allDay: allDay,
      calendarId: calendarId ?? (j['calendarId'] as String?) ?? 'default',
      rrule: j['rrule'] as String?,
      exceptions: {
        if (j['exdates'] case final List list)
          for (final e in list)
            if (_parseDate(e) case final DateTime d) d,
      },
      timeZone: j['tz'] as String?,
    );
  }

  /// Starts of this event's occurrences in `[from, to)`, as ZT Calendar
  /// works them out (`CalendarEvent.occurrenceStarts`).
  List<DateTime> startsBetween(DateTime from, DateTime to) {
    final rule = RecurrenceRule.tryParse(rrule);
    if (rule == null) {
      return !start.isBefore(from) && start.isBefore(to) ? [start] : [];
    }
    final zone = allDay ? null : zoneFor(timeZone);
    if (zone == null) return rule.between(start, from, to, exclude: exceptions);
    // The rule runs on the zone's wall clock, so its end (an instant, read
    // as phone time) is moved onto that clock too.
    final until = rule.until;
    final wallRule = until == null
        ? rule
        : rule.copyWith(until: _wallClockIn(zone, until));
    const slack = Duration(days: 2);
    return [
      for (final w in wallRule.between(
        _wallClockIn(zone, start),
        _wallClockIn(zone, from).subtract(slack),
        _wallClockIn(zone, to).add(slack),
      ))
        if (_instantFromWall(zone, w) case final t
            when !t.isBefore(from) && t.isBefore(to) && !exceptions.contains(t))
          t,
    ];
  }
}

/// A calendar of the account: hidden ones are left out.
class LinkedCalendar {
  const LinkedCalendar(this.id, {this.hidden = false});
  final String id;
  final bool hidden;
}

/// One timed event on a day: its start and title.
typedef DayEvent = ({DateTime start, String title});

/// Every timed event starting in the [days] days from [today], by day
/// (yyyy-MM-dd), each day's sorted by start. All-day events don't count:
/// nobody is woken for a holiday or a birthday.
Map<String, List<DayEvent>> timedEventsByDay(
  Iterable<LinkedEvent> events, {
  required DateTime today,
  int days = dayAheadDays,
  Set<String> hiddenCalendars = const {},
}) {
  final from = _midnight(today);
  final to = DateTime(from.year, from.month, from.day + days);
  final out = <String, List<DayEvent>>{};
  for (final e in events) {
    if (e.allDay || hiddenCalendars.contains(e.calendarId)) continue;
    // A timed event of a day or longer ("Conference") is not a morning
    // appointment.
    if (e.end.difference(e.start) >= const Duration(hours: 20)) continue;
    for (final s in e.startsBetween(from, to)) {
      (out[_key(s)] ??= []).add((start: s, title: e.title));
    }
  }
  for (final list in out.values) {
    list.sort((a, b) => a.start.compareTo(b.start));
  }
  return out;
}

/// The plan an alarm linked to ZT Calendar is given: each day's first
/// event that starts at or after [earliest] (minutes after midnight), in
/// minutes after midnight.
Map<String, int> firstEventPlan(
  Map<String, List<DayEvent>> byDay, {
  required int earliest,
}) => {
  for (final MapEntry(:key, :value) in byDay.entries)
    if (value
            .map((e) => e.start.hour * 60 + e.start.minute)
            .where((m) => m >= earliest)
            .firstOrNull
        case final int first)
      key: first,
};

/// A ZT Tasks task with a due date (ZT Tasks' JSON, as ZT Calendar reads it).
class LinkedTask {
  const LinkedTask(this.title, this.due, {this.completed = false});
  final String title;
  final DateTime due;
  final bool completed;

  /// Tasks are ZT Tasks' default collection: items without a `kind`.
  static LinkedTask? fromJson(Map<String, Object?>? j) {
    if (j == null || j['kind'] != null) return null;
    if (j['deletedAt'] != null || j['isArchived'] == true) return null;
    final raw = j['dueDate'];
    if (raw is! String) return null;
    final due = DateTime.tryParse(raw)?.toLocal();
    if (due == null) return null;
    final title = ((j['title'] as String?) ?? '').trim();
    return LinkedTask(title, due, completed: j['isCompleted'] == true);
  }
}

/// An active ZT Quests goal: each one makes a daily quest every day.
class LinkedGoal {
  const LinkedGoal(this.name, this.category);
  final String name;
  final String category;

  static LinkedGoal? fromJson(Map<String, Object?>? j) {
    if (j == null || j['kind'] != 'goal' || j['archived'] == true) return null;
    return LinkedGoal(
      ((j['name'] as String?) ?? '').trim(),
      (j['category'] as String?) ?? 'custom',
    );
  }
}

/// The morning screen's data for the next [days] days, as the engine
/// keeps it (`MorningDay` in the engine). Days with nothing are left out.
/// [goalName] names a goal without a name of its own (by its category).
Map<String, Object?> morningBrief({
  required DateTime today,
  required Map<String, List<DayEvent>> events,
  required List<LinkedTask> tasks,
  required List<LinkedGoal> goals,
  required String Function(LinkedGoal) goalName,
  int days = dayAheadDays,
  int listMax = 4,
}) {
  final first = _midnight(today);
  final open = [
    for (final t in tasks)
      if (!t.completed) t,
  ]..sort((a, b) => a.due.compareTo(b.due));
  final out = <String, Object?>{};
  for (var i = 0; i < days; i++) {
    final day = DateTime(first.year, first.month, first.day + i);
    final key = _key(day);
    final dayEvents = events[key] ?? const <DayEvent>[];
    final due = [
      for (final t in open)
        if (_midnight(t.due) == day) t,
    ];
    final overdue = [
      for (final t in open)
        if (_midnight(t.due).isBefore(day)) t,
    ];
    if (dayEvents.isEmpty && due.isEmpty && overdue.isEmpty && goals.isEmpty) {
      continue;
    }
    int minutes(DateTime t) => t.hour * 60 + t.minute;
    out[key] = {
      'events': dayEvents.length,
      if (dayEvents.isNotEmpty) 'first': minutes(dayEvents.first.start),
      'eventList': [
        for (final e in dayEvents.take(listMax))
          {'t': minutes(e.start), 'title': e.title},
      ],
      'tasks': due.length,
      'overdue': overdue.length,
      'taskList': [
        for (final t in [...due, ...overdue].take(listMax)) t.title,
      ],
      'quests': goals.length,
      'questList': [for (final g in goals.take(listMax)) goalName(g)],
    };
  }
  final last = DateTime(first.year, first.month, first.day + days - 1);
  return {'through': _key(last), 'days': out};
}
