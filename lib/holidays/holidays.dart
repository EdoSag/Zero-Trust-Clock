import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../engine/clock_engine.dart';
import 'holiday_feed.dart';

/// Downloads a holiday calendar; tests override it.
final holidayFetcherProvider = Provider<HolidayFetcher>(
  (_) => fetchHolidayFeed,
);

/// The public holidays of this phone: which calendar, its days as last
/// downloaded, and which of them alarms skip.
class HolidaysState {
  const HolidaysState({
    this.feedId,
    this.items = const [],
    this.fetchedAt,
    this.choices = const {},
    this.loading = false,
    this.failed = false,
  });

  /// The holiday calendar's feed id, or null when none is chosen.
  final String? feedId;
  final List<Holiday> items;
  final DateTime? fetchedAt;

  /// Days the user ticked (true) or unticked (false), by yyyy-MM-dd.
  final Map<String, bool> choices;
  final bool loading;

  /// The last download failed (no network); the old days still count.
  final bool failed;

  HolidayCalendar? get calendar => HolidayCalendar.byId(feedId);

  /// Whether the feed tells days off from observances. When it does, the
  /// days off are skipped unless unticked; when it doesn't, nothing is
  /// skipped until ticked, so an alarm never goes quiet by surprise.
  bool get marksPublic => items.any((h) => h.public);

  bool skips(Holiday h) => choices[h.day] ?? (marksPublic && h.public);

  /// From yesterday on (a ring just after midnight still counts).
  List<Holiday> upcoming(DateTime now) {
    final from = dayString(DateTime(now.year, now.month, now.day - 1));
    return [
      for (final h in items)
        if (h.day.compareTo(from) >= 0) h,
    ];
  }

  /// What the engine is given.
  List<String> skippedDays(DateTime now) => [
    for (final h in upcoming(now))
      if (skips(h)) h.day,
  ];

  HolidaysState copyWith({
    String? feedId,
    bool clearFeed = false,
    List<Holiday>? items,
    DateTime? fetchedAt,
    Map<String, bool>? choices,
    bool? loading,
    bool? failed,
  }) => HolidaysState(
    feedId: clearFeed ? null : feedId ?? this.feedId,
    items: items ?? this.items,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    choices: choices ?? this.choices,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
  );
}

class HolidaysController extends AsyncNotifier<HolidaysState> {
  static const _feedKey = 'clock_holiday_feed';
  static const _cacheKey = 'clock_holiday_cache';
  static const _choicesKey = 'clock_holiday_choices';

  /// Downloaded again after a week.
  static const maxAge = Duration(days: 7);

  PreferencesStore get _prefs => ref.read(ztPreferencesStoreProvider);

  @override
  Future<HolidaysState> build() async {
    var s = const HolidaysState();
    try {
      final storedFeed = await _prefs.read(_feedKey);
      final feed = (storedFeed?.isEmpty ?? true) ? null : storedFeed;
      final choices = <String, bool>{};
      final rawChoices = await _prefs.read(_choicesKey);
      if (rawChoices != null && rawChoices.isNotEmpty) {
        (jsonDecode(rawChoices) as Map).forEach((k, v) {
          if (k is String && v is bool) choices[k] = v;
        });
      }
      s = HolidaysState(feedId: feed, choices: choices);
      final rawCache = await _prefs.read(_cacheKey);
      if (feed != null && rawCache != null && rawCache.isNotEmpty) {
        final c = jsonDecode(rawCache) as Map;
        if (c['feed'] == feed) {
          s = s.copyWith(
            items: [
              for (final h in (c['items'] as List? ?? const []))
                if (Holiday.fromJson(h) case final Holiday holiday) holiday,
            ],
            fetchedAt: DateTime.tryParse(c['at'] as String? ?? ''),
          );
        }
      }
    } on Object {
      // Starts over; the next download fills it.
    }
    final at = s.fetchedAt;
    if (s.feedId != null &&
        (at == null || DateTime.now().difference(at) > maxAge)) {
      Future.microtask(refresh);
    }
    return s;
  }

  /// Picks a holiday calendar (null: none) and downloads it.
  Future<void> choose(String? feedId) async {
    final now = await future;
    if (feedId == now.feedId) return;
    if (feedId == null) {
      // The store has no delete: an empty value is "none".
      await _prefs.write(_feedKey, '');
      await _prefs.write(_cacheKey, '');
      await _prefs.write(_choicesKey, '');
      await _publish(const HolidaysState());
      return;
    }
    await _prefs.write(_feedKey, feedId);
    await _prefs.write(_choicesKey, '');
    await _publish(HolidaysState(feedId: feedId));
    await refresh();
  }

  /// Downloads the chosen calendar again.
  Future<void> refresh() async {
    final s = await future;
    final calendar = s.calendar;
    if (calendar == null || s.loading) return;
    state = AsyncData(s.copyWith(loading: true));
    try {
      final items = parseHolidays(
        await ref.read(holidayFetcherProvider)(calendar.url),
      );
      final at = DateTime.now();
      await _prefs.write(
        _cacheKey,
        jsonEncode({
          'feed': calendar.feedId,
          'at': at.toIso8601String(),
          'items': [for (final h in items) h.toJson()],
        }),
      );
      await _publish(
        (await future).copyWith(
          items: items,
          fetchedAt: at,
          loading: false,
          failed: false,
        ),
      );
    } on Object {
      state = AsyncData((await future).copyWith(loading: false, failed: true));
    }
  }

  /// Ticks or unticks one day.
  Future<void> setSkip(Holiday h, bool skip) async {
    final s = await future;
    final choices = {...s.choices, h.day: skip};
    await _prefs.write(_choicesKey, jsonEncode(choices));
    await _publish(s.copyWith(choices: choices));
  }

  Future<void> _publish(HolidaysState s) async {
    state = AsyncData(s);
    try {
      await ref
          .read(clockEngineProvider)
          .setHolidays(s.skippedDays(DateTime.now()));
    } on Object {
      // The engine keeps the last list; the next change sends it again.
    }
  }
}

final holidaysProvider =
    AsyncNotifierProvider<HolidaysController, HolidaysState>(
      HolidaysController.new,
    );
