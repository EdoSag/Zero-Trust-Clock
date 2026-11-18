import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_clock/l10n/l10n.dart';
import 'package:zerotrust_clock/ui/alarm_text.dart';

import 'support/app.dart';
import 'support/fake_engine.dart';

Future<BuildContext> contextFor(WidgetTester tester, Locale locale) async {
  late BuildContext found;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: ZtLanguages.supported,
      localizationsDelegates: const [
        AppL10n.delegate,
        ...ZtLanguages.delegates,
      ],
      home: Builder(
        builder: (context) {
          found = context;
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return found;
}

void main() {
  test('"rings in" rounds up to the minute', () {
    final l = lookupAppL10n(const Locale('en'));
    String say(Duration d) => ringsInText(l, d);
    expect(say(const Duration(seconds: 20)), 'Rings in less than a minute');
    expect(say(const Duration(seconds: 61)), 'Rings in 2 min');
    expect(say(const Duration(minutes: 59)), 'Rings in 59 min');
    expect(say(const Duration(minutes: 60)), 'Rings in 1 h 0 min');
    expect(
      say(const Duration(hours: 7, minutes: 29, seconds: 30)),
      'Rings in 7 h 30 min',
    );
    expect(
      say(const Duration(hours: 23, minutes: 59, seconds: 59)),
      'Rings in 1 d 0 h',
    );
    expect(say(const Duration(days: 6, hours: 5)), 'Rings in 6 d 5 h');

    final he = lookupAppL10n(const Locale('he'));
    expect(
      ringsInText(he, const Duration(hours: 2, minutes: 5)),
      'יצלצל בעוד 2 שעות ו-5 דקות',
    );
  });

  testWidgets('English: days, dates and times', (tester) async {
    final context = await contextFor(tester, const Locale('en'));
    final now = DateTime(2026, 11, 18, 22); // a Wednesday
    expect(weekOrder(context), [7, 1, 2, 3, 4, 5, 6]);
    expect(shortDayName(context, 7), 'Sun');
    expect(fullDayName(context, 1), 'Monday');
    expect(timeOfDayText(context, 7, 5), '7:05 AM');
    expect(timeOfDayText(context, 0, 0), '12:00 AM');

    expect(dayText(context, DateTime(2026, 11, 18, 23), now: now), 'Today');
    // An hour later on the clock, but the next day.
    expect(
      dayText(context, DateTime(2026, 11, 19, 0, 30), now: now),
      'Tomorrow',
    );
    expect(
      dayText(context, DateTime(2026, 11, 20, 7), now: now),
      'Fri, Nov 20',
    );

    expect(
      repeatText(context, alarm('a', days: {6, 7, 1}), now: now),
      'Sun, Mon, Sat',
    );
    expect(
      repeatText(context, alarm('a', days: {1, 2, 3, 4, 5, 6, 7}), now: now),
      'Every day',
    );
    expect(
      repeatText(
        context,
        alarm('a', nextRing: DateTime(2026, 11, 19, 7)),
        now: now,
      ),
      'Tomorrow',
    );
    expect(repeatText(context, alarm('a', enabled: false), now: now), 'Once');
  });

  testWidgets('Hebrew: day letters, the week from Sunday, 24-hour time', (
    tester,
  ) async {
    final context = await contextFor(tester, hebrew);
    final now = DateTime(2026, 11, 18, 22);
    expect(weekOrder(context), [7, 1, 2, 3, 4, 5, 6]);
    expect(shortDayName(context, 7), 'א׳');
    expect(shortDayName(context, 6), 'ש׳');
    expect(fullDayName(context, 7), 'יום ראשון');
    expect(timeOfDayText(context, 7, 5), '7:05');
    expect(timeOfDayText(context, 19, 30), '19:30');
    expect(dayText(context, DateTime(2026, 11, 19, 7), now: now), 'מחר');
    expect(
      repeatText(context, alarm('a', days: {7, 1, 2, 3, 4}), now: now),
      'א׳, ב׳, ג׳, ד׳, ה׳',
    );
    expect(
      repeatText(context, alarm('a', days: {1, 2, 3, 4, 5, 6, 7}), now: now),
      'כל יום',
    );
  });
}
