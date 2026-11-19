import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_clock/holidays/holiday_feed.dart';
import 'package:zerotrust_clock/holidays/holidays.dart';
import 'package:zerotrust_clock/sync/alarm_sync.dart';
import 'package:zerotrust_clock/ui/alarm_card.dart';
import 'package:zerotrust_clock/ui/holidays_page.dart';

import 'alarm_options_test.dart' show scrollTo;
import 'support/app.dart';
import 'support/fake_engine.dart';
import 'timers_test.dart' show tallPhone;

String _ics(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

DateTime inDays(int n) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + n);
}

/// A feed like Google's: a two-day public holiday, an observance, and a
/// timed event that is not a holiday.
String feed({bool marked = true}) =>
    '''
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART;VALUE=DATE:${_ics(inDays(10))}
DTEND;VALUE=DATE:${_ics(inDays(12))}
SUMMARY:Rosh Hashana
${marked ? 'DESCRIPTION:Public holiday' : ''}
END:VEVENT
BEGIN:VEVENT
DTSTART;VALUE=DATE:${_ics(inDays(20))}
DTEND;VALUE=DATE:${_ics(inDays(21))}
SUMMARY:Tu BiShvat
${marked ? 'DESCRIPTION:Observance\\nTo hide observances\\, go to settings' : ''}
END:VEVENT
BEGIN:VEVENT
DTSTART:${_ics(inDays(5))}T090000Z
DTEND:${_ics(inDays(5))}T100000Z
SUMMARY:A meeting
END:VEVENT
END:VCALENDAR
'''
        .replaceAll('\n\n', '\n');

List<Uri> fetched = [];

Future<String> Function(Uri) fetcher(String body) => (url) async {
  fetched.add(url);
  return body;
};

Future<void> chooseIsrael(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('holidayCalendar')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Israel (Jewish holidays)'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => fetched = []);

  test('an .ics file gives one holiday per day, all-day events only', () {
    const ics =
        'BEGIN:VCALENDAR\r\n'
        'BEGIN:VEVENT\r\n'
        'DTSTART;VALUE=DATE:20270101\r\n'
        'DTEND;VALUE=DATE:20270103\r\n'
        'SUMMARY:New Year\\, long\r\n'
        '  weekend\r\n'
        'DESCRIPTION:Public holiday\r\n'
        'END:VEVENT\r\n'
        'BEGIN:VEVENT\r\n'
        'DTSTART;VALUE=DATE:20270101\r\n'
        'SUMMARY:Another\r\n'
        'END:VEVENT\r\n'
        'BEGIN:VEVENT\r\n'
        'DTSTART:20270105T080000Z\r\n'
        'SUMMARY:Timed\r\n'
        'END:VEVENT\r\n'
        'END:VCALENDAR\r\n';
    final days = parseHolidays(ics);
    expect([for (final h in days) h.day], ['2027-01-01', '2027-01-02']);
    expect(days.first.name, 'New Year, long weekend, Another');
    expect(days.first.public, isTrue);
    expect(days.last.name, 'New Year, long weekend');
  });

  testWidgets('pick a calendar: days off are ticked and go to the engine', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    final prefs = InMemoryPreferencesStore();
    await tester.pumpWidget(
      testApp(
        engine,
        home: const HolidaysPage(),
        prefs: prefs,
        overrides: [holidayFetcherProvider.overrideWithValue(fetcher(feed()))],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('None'), findsOneWidget);
    await chooseIsrael(tester);
    expect(fetched.single.toString(), contains('en.jewish'));

    // Calendar, then when it was updated, then the days by date.
    final calendar = tester.getRect(
      find.byKey(const ValueKey('holidayCalendar')),
    );
    final status = tester.getRect(find.byKey(const ValueKey('holidayStatus')));
    final first = tester.getRect(
      find.byKey(ValueKey('holiday-${dayString(inDays(10))}')),
    );
    final second = tester.getRect(
      find.byKey(ValueKey('holiday-${dayString(inDays(11))}')),
    );
    final observance = find.byKey(ValueKey('holiday-${dayString(inDays(20))}'));
    expect(calendar.bottom, lessThanOrEqualTo(status.top));
    expect(status.bottom, lessThanOrEqualTo(first.top));
    expect(first.bottom, lessThanOrEqualTo(second.top));
    expect(find.text('A meeting'), findsNothing);
    expect(find.text('Rosh Hashana'), findsNWidgets(2));
    expect(tester.widget<CheckboxListTile>(observance).value, isFalse);
    expect(
      find.text(
        'Days off are ticked. Untick any day your alarms should ring on.',
      ),
      findsOneWidget,
    );
    expect(engine.holidayDays, [dayString(inDays(10)), dayString(inDays(11))]);

    // Untick the second day: alarms ring on it.
    await tester.tap(find.byKey(ValueKey('holiday-${dayString(inDays(11))}')));
    await tester.pumpAndSettle();
    expect(engine.holidayDays, [dayString(inDays(10))]);
    expect(await prefs.read('clock_holiday_feed'), 'en.jewish');
  });

  testWidgets('a calendar without days off marked skips nothing until ticked', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    await tester.pumpWidget(
      testApp(
        engine,
        home: const HolidaysPage(),
        overrides: [
          holidayFetcherProvider.overrideWithValue(
            fetcher(feed(marked: false)),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await chooseIsrael(tester);
    expect(engine.holidayDays, isEmpty);
    expect(find.textContaining("doesn't say which days"), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('holiday-${dayString(inDays(20))}')));
    await tester.pumpAndSettle();
    expect(engine.holidayDays, [dayString(inDays(20))]);
  });

  testWidgets('a failed download keeps the last days', (tester) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    var fail = false;
    await tester.pumpWidget(
      testApp(
        engine,
        home: const HolidaysPage(),
        overrides: [
          holidayFetcherProvider.overrideWithValue((url) async {
            if (fail) throw StateError('offline');
            return feed();
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await chooseIsrael(tester);
    fail = true;
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't download. The last list still counts."),
      findsOneWidget,
    );
    expect(find.text('Rosh Hashana'), findsNWidgets(2));
    expect(engine.holidayDays, hasLength(2));
  });

  testWidgets('editor: Skip public holidays asks for a calendar first', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine(
      alarms: [
        alarm('a', days: {1, 2}),
      ],
    );
    await tester.pumpWidget(
      testApp(
        engine,
        overrides: [holidayFetcherProvider.overrideWithValue(fetcher(feed()))],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AlarmCard));
    await tester.pumpAndSettle();
    final skip = find.byKey(const ValueKey('skipHolidays'));
    await scrollTo(tester, skip);
    expect(find.text('Choose a holiday calendar first'), findsOneWidget);
    // With the repeat days, above the label.
    expect(
      tester.getRect(skip).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(TextField)).top),
    );
    await tester.tap(skip);
    await tester.pumpAndSettle();
    expect(find.byType(HolidaysPage), findsOneWidget);
    await chooseIsrael(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(skip).value, isTrue);
    expect(find.text('Israel (Jewish holidays)'), findsOneWidget);

    final save = find.widgetWithText(FilledButton, 'Save');
    await scrollTo(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(engine.lastSave['skipHolidays'], isTrue);
    expect(engine.alarms.single.skipHolidays, isTrue);
  });

  test('Skip public holidays syncs; the calendar stays on the phone', () {
    final s = SyncedAlarm.fromEngine(
      alarm('a', days: {1}, skipHolidays: true),
      device: 'A',
    );
    expect(s.toJson()['skipHolidays'], isTrue);
    expect(
      SyncedAlarm.fromJson('a', s.toJson()).toEngine('B').skipHolidays,
      isTrue,
    );
    expect(
      s.toJson().keys.where(
        (k) => k.contains('holiday') && k != 'skipHolidays',
      ),
      isEmpty,
    );
  });
}
