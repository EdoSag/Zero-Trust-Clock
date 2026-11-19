import 'dart:convert';
import 'dart:io';

/// A public holiday calendar to take days off from. The same public
/// Google Calendar holiday feeds ZT Calendar offers: downloaded like any
/// web file, with no Google account and nothing about the user sent.
class HolidayCalendar {
  const HolidayCalendar(this.name, this.feedId);
  final String name;
  final String feedId;

  Uri get url => Uri.parse(
    'https://calendar.google.com/calendar/ical/'
    '${Uri.encodeComponent('$feedId#holiday@group.v.calendar.google.com')}'
    '/public/basic.ics',
  );

  static HolidayCalendar? byId(String? id) {
    for (final c in all) {
      if (c.feedId == id) return c;
    }
    return null;
  }

  static const all = [
    HolidayCalendar('Israel (Jewish holidays)', 'en.jewish'),
    HolidayCalendar('Israel (Jewish holidays, Hebrew)', 'iw.jewish'),
    HolidayCalendar('United States', 'en.usa'),
    HolidayCalendar('United Kingdom', 'en.uk'),
    HolidayCalendar('Canada', 'en.canadian'),
    HolidayCalendar('Australia', 'en.australian'),
    HolidayCalendar('Ireland', 'en.irish'),
    HolidayCalendar('Germany', 'en.german'),
    HolidayCalendar('France', 'en.french'),
    HolidayCalendar('Italy', 'en.italian'),
    HolidayCalendar('Spain', 'en.spain'),
    HolidayCalendar('Netherlands', 'en.dutch'),
    HolidayCalendar('Portugal', 'en.portuguese'),
    HolidayCalendar('Poland', 'en.polish'),
    HolidayCalendar('Sweden', 'en.swedish'),
    HolidayCalendar('Russia', 'en.russian'),
    HolidayCalendar('India', 'en.indian'),
    HolidayCalendar('Japan', 'en.japanese'),
    HolidayCalendar('China', 'en.china'),
    HolidayCalendar('Brazil', 'en.brazilian'),
    HolidayCalendar('Mexico', 'en.mexican'),
    HolidayCalendar('South Africa', 'en.sa'),
    HolidayCalendar('Christian holidays', 'en.christian'),
    HolidayCalendar('Islamic holidays', 'en.islamic'),
  ];
}

/// One day of a holiday. A holiday over several days is one per day.
class Holiday {
  const Holiday(this.day, this.name, {this.public = false});

  /// yyyy-MM-dd.
  final String day;
  final String name;

  /// The feed marks it a public holiday (a day off), not an observance.
  final bool public;

  Map<String, Object?> toJson() => {'d': day, 'n': name, 'p': public};

  static Holiday? fromJson(Object? j) {
    if (j is! Map) return null;
    final d = j['d'];
    if (d is! String) return null;
    return Holiday(d, j['n'] as String? ?? '', public: j['p'] == true);
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

String dayString(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// The all-day events of an .ics file, one [Holiday] per day, by date.
/// Timed events are left out: a holiday is a whole day.
List<Holiday> parseHolidays(String ics) {
  // Long lines are folded: a line starting with a space continues the last.
  final lines = <String>[];
  for (final raw in const LineSplitter().convert(ics)) {
    if ((raw.startsWith(' ') || raw.startsWith('\t')) && lines.isNotEmpty) {
      lines[lines.length - 1] += raw.substring(1);
    } else {
      lines.add(raw);
    }
  }
  String unescape(String v) => v
      .replaceAll(r'\n', ' ')
      .replaceAll(r'\N', ' ')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\\', r'\')
      .trim();
  DateTime? date(String v) {
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(v.trim());
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  final out = <String, Holiday>{};
  Map<String, String>? event;
  for (final line in lines) {
    if (line == 'BEGIN:VEVENT') {
      event = {};
      continue;
    }
    if (line == 'END:VEVENT') {
      final e = event;
      event = null;
      if (e == null) continue;
      final start = date(e['DTSTART'] ?? '');
      if (start == null) continue;
      var end = date(e['DTEND'] ?? '') ?? start.add(const Duration(days: 1));
      if (!end.isAfter(start)) end = start.add(const Duration(days: 1));
      final name = unescape(e['SUMMARY'] ?? '');
      final public = unescape(
        e['DESCRIPTION'] ?? '',
      ).toLowerCase().startsWith('public holiday');
      for (
        var d = start;
        d.isBefore(end) && d.difference(start).inDays < 14;
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        final key = dayString(d);
        final old = out[key];
        out[key] = Holiday(
          key,
          old == null ? name : '${old.name}, $name',
          public: public || (old?.public ?? false),
        );
      }
      continue;
    }
    final e = event;
    if (e == null) continue;
    final colon = line.indexOf(':');
    if (colon < 0) continue;
    final name = line.substring(0, colon).split(';').first.toUpperCase();
    // Only an all-day start counts (VALUE=DATE, no time).
    if (name == 'DTSTART' || name == 'DTEND') {
      final value = line.substring(colon + 1);
      if (value.contains('T')) {
        if (name == 'DTSTART') e['DTSTART'] = '';
        continue;
      }
      e[name] = value;
    } else if (name == 'SUMMARY' || name == 'DESCRIPTION') {
      e[name] = line.substring(colon + 1);
    }
  }
  return out.values.toList()..sort((a, b) => a.day.compareTo(b.day));
}

/// Downloads a holiday calendar. Tests replace it.
typedef HolidayFetcher = Future<String> Function(Uri url);

Future<String> fetchHolidayFeed(Uri url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.getUrl(url);
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }
    return await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 30));
  } finally {
    client.close(force: true);
  }
}
