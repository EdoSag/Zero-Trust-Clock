import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_clock/engine/clock_timer.dart';
import 'package:zerotrust_clock/l10n/l10n.dart';
import 'package:zerotrust_clock/ui/alarms_page.dart';
import 'package:zerotrust_clock/ui/clock_home.dart';
import 'package:zerotrust_clock/ui/stopwatch_page.dart';
import 'package:zerotrust_clock/ui/timer_keypad.dart';
import 'package:zerotrust_clock/ui/timers_page.dart';
import 'package:zerotrust_clock/ui/world_clock_page.dart';
import 'package:zerotrust_clock/world/world_cities.dart';
import 'package:zerotrust_clock/world/world_zone.dart';

import 'support/app.dart';
import 'support/fake_engine.dart';
import 'timers_test.dart' show frames, tallPhone;

/// A zone [diff] away from this test machine's own time zone.
WorldZone away(Duration diff, {String city = 'There'}) => WorldZone(
  id: 'Test/$city',
  city: city,
  offset: DateTime.now().timeZoneOffset + diff,
);

Future<void> addCity(WidgetTester tester, String search, String city) async {
  await tester.tap(find.byTooltip('Add city'));
  await frames(tester);
  expect(find.byType(CityPickerPage), findsOneWidget);
  await tester.enterText(find.byType(TextField), search);
  await frames(tester);
  await tester.tap(find.text(city));
  await frames(tester);
}

void main() {
  testWidgets('a city says how far it is from here', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppL10n.delegate,
          ...ZtLanguages.delegates,
        ],
        supportedLocales: ZtLanguages.supported,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Noon here, so no city in these lies on another day.
    final noon = DateTime(2026, 6, 10, 12);
    String text(Duration diff) => zoneDifferenceText(
      context,
      WorldZone(id: 'x', city: 'x', offset: noon.timeZoneOffset + diff),
      noon,
    );
    expect(text(Duration.zero), 'Today, Same time');
    expect(text(const Duration(hours: 7)), 'Today, 7 h ahead');
    expect(
      text(const Duration(hours: -3, minutes: -30)),
      'Today, 3 h 30 min behind',
    );
    expect(text(const Duration(minutes: 45)), 'Today, 45 min ahead');
    // Late evening here: 7 hours ahead is tomorrow there.
    final late = DateTime(2026, 6, 10, 22);
    expect(
      zoneDifferenceText(
        context,
        WorldZone(
          id: 'x',
          city: 'x',
          offset: late.timeZoneOffset + const Duration(hours: 7),
        ),
        late,
      ),
      'Tomorrow, 7 h ahead',
    );
  });

  testWidgets('add a city: search, pick, and it shows its time', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine()
      ..zoneList = [
        ...FakeClockEngine().zoneList,
        away(const Duration(hours: 7), city: 'Faraway'),
      ];
    final prefs = InMemoryPreferencesStore();
    await tester.pumpWidget(
      testApp(engine, home: const WorldClockPage(), prefs: prefs),
    );
    await frames(tester);
    expect(find.text('No cities yet'), findsOneWidget);

    await addCity(tester, 'far', 'Faraway');
    expect(find.byType(CityPickerPage), findsNothing);
    expect(find.text('No cities yet'), findsNothing);
    final row = find.byType(CityRow);
    expect(row, findsOneWidget);
    expect(find.textContaining('7 h ahead'), findsOneWidget);
    expect(engine.calls, contains('setWorldCities Test/Faraway'));
    expect(await prefs.read('clock_world_cities'), '["Test/Faraway"]');

    // The time here on top, the city below it; its time at the end.
    final here = tester.getRect(find.byKey(const ValueKey('hereNow')));
    final name = tester.getRect(find.text('Faraway'));
    expect(here.bottom, lessThanOrEqualTo(tester.getRect(row).top));
    final time = tester.getRect(
      find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').contains(':'),
        ),
      ),
    );
    expect(time.left, greaterThan(name.right));
  });

  testWidgets('the search finds cities by country, and marks picked ones', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    await tester.pumpWidget(testApp(engine, home: const WorldClockPage()));
    await frames(tester);
    await addCity(tester, 'japan', 'Tokyo');

    await tester.tap(find.byTooltip('Add city'));
    await frames(tester);
    // All cities, by name; Tokyo already picked.
    final cities = ['Kolkata', 'London', 'New York', 'Tokyo'];
    final ys = [for (final c in cities) tester.getTopLeft(find.text(c)).dy];
    expect(ys, [...ys]..sort());
    final tokyo = tester.widget<ListTile>(
      find.ancestor(of: find.text('Tokyo'), matching: find.byType(ListTile)),
    );
    expect(tokyo.enabled, isFalse);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await frames(tester);
    expect(find.text('No city found'), findsOneWidget);
  });

  testWidgets('cities keep their order; a removed one comes back with Undo', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    final prefs = InMemoryPreferencesStore();
    await prefs.write(
      'clock_world_cities',
      '["Asia/Tokyo","Europe/London","America/New_York"]',
    );
    await tester.pumpWidget(
      testApp(engine, home: const WorldClockPage(), prefs: prefs),
    );
    await frames(tester);
    double y(String city) => tester.getTopLeft(find.text(city)).dy;
    expect(y('Tokyo'), lessThan(y('London')));
    expect(y('London'), lessThan(y('New York')));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(WorldClockPage)),
    );
    await container.read(worldCitiesProvider.notifier).move(0, 2);
    await frames(tester);
    expect(y('London'), lessThan(y('New York')));
    expect(y('New York'), lessThan(y('Tokyo')));

    await tester.drag(find.text('New York'), const Offset(-600, 0));
    await frames(tester);
    expect(find.text('New York'), findsNothing);
    expect(find.text('New York removed'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await frames(tester);
    expect(y('London'), lessThan(y('New York')));
    expect(y('New York'), lessThan(y('Tokyo')));
  });

  testWidgets('in Hebrew a city name is on the right, its time on the left', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    final prefs = InMemoryPreferencesStore();
    await prefs.write('clock_world_cities', '["Asia/Tokyo"]');
    await tester.pumpWidget(
      testApp(
        engine,
        home: const WorldClockPage(),
        prefs: prefs,
        locale: hebrew,
      ),
    );
    await frames(tester);
    expect(find.text('שעון'), findsOneWidget);
    final row = find.byType(CityRow);
    final name = tester.getRect(find.text('Tokyo'));
    final time = tester.getRect(
      find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').contains(':'),
        ),
      ),
    );
    expect(time.right, lessThan(name.left));
  });

  group('shortcuts', () {
    testWidgets('New alarm opens the alarms and asks for a time', (
      tester,
    ) async {
      tallPhone(tester);
      final engine = FakeClockEngine()..tabAtLaunch = 'newAlarm';
      await tester.pumpWidget(testApp(engine, home: const ClockHome()));
      await frames(tester);
      expect(find.byType(AlarmsPage), findsOneWidget);
      expect(find.byType(TimePickerDialog), findsOneWidget);
    });

    testWidgets('New timer opens the keypad', (tester) async {
      tallPhone(tester);
      final engine = FakeClockEngine()..tabAtLaunch = 'newTimer';
      await tester.pumpWidget(testApp(engine, home: const ClockHome()));
      await frames(tester);
      // No timers yet: the keypad is the tab itself.
      expect(find.byType(TimerKeypad), findsOneWidget);
      expect(find.byType(NewTimerPage), findsNothing);

      // With a timer, the keypad opens on its own screen.
      engine.timerList.add(
        const ClockTimer(id: 't', length: Duration(minutes: 3)),
      );
      engine.changedOutside();
      engine.openTabOutside('alarms');
      await frames(tester);
      engine.openTabOutside('newTimer');
      await frames(tester);
      expect(find.byType(NewTimerPage), findsOneWidget);
      expect(find.byType(TimersPage), findsOneWidget);
    });

    testWidgets('Start stopwatch starts it, once', (tester) async {
      tallPhone(tester);
      final engine = FakeClockEngine()..tabAtLaunch = 'startStopwatch';
      await tester.pumpWidget(testApp(engine, home: const ClockHome()));
      await frames(tester);
      expect(find.byType(StopwatchPage), findsOneWidget);
      expect(engine.calls.where((c) => c == 'stopwatchStart'), hasLength(1));
      expect(find.widgetWithText(FilledButton, 'Pause'), findsOneWidget);
    });
  });
}
