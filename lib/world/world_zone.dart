import 'dart:convert';

/// One city of the world clock: an Android time zone, named by its main
/// city in the app's language.
class WorldZone {
  const WorldZone({
    required this.id,
    required this.city,
    this.country = '',
    required this.offset,
  });

  /// The time zone, e.g. `Asia/Tokyo`.
  final String id;
  final String city;
  final String country;

  /// Its offset from UTC right now.
  final Duration offset;

  /// The time there at [now].
  DateTime timeAt(DateTime now) {
    final utc = now.toUtc().add(offset);
    // A plain local DateTime with those fields, for formatting.
    return DateTime(utc.year, utc.month, utc.day, utc.hour, utc.minute);
  }

  WorldZone withOffset(Duration offset) =>
      WorldZone(id: id, city: city, country: country, offset: offset);

  static List<WorldZone> listFromJson(String json) => [
    for (final m in jsonDecode(json) as List)
      WorldZone(
        id: m['id'] as String,
        city: m['city'] as String? ?? m['id'] as String,
        country: m['country'] as String? ?? '',
        offset: Duration(minutes: (m['offset'] as num?)?.toInt() ?? 0),
      ),
  ];
}
