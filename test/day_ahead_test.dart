import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_clock/app/account.dart';
import 'package:zerotrust_clock/app/clock_gate.dart';
import 'package:zerotrust_clock/engine/alarm.dart';
import 'package:zerotrust_clock/engine/clock_engine.dart';
import 'package:zerotrust_clock/linked/day_ahead.dart';
import 'package:zerotrust_clock/l10n/generated/app_l10n.dart';
import 'package:zerotrust_clock/linked/linked_apps.dart';
import 'package:zerotrust_clock/sync/alarm_sync.dart';
import 'package:zerotrust_clock/ui/settings_page.dart';

import 'alarms_page_test.dart' show editorScroll, inCard;
import 'support/app.dart';
import 'support/fake_engine.dart';

// 2026-11-18 is a Wednesday.
final today = DateTime(2026, 11, 18, 21, 0);

Map<String, Object?> event(
  String start, {
  String? end,
  bool allDay = false,
  String? rrule,
  List<String> exdates = const [],
  String title = 'Meeting',
  String calendarId = 'default',
  String? tz,
}) => {
  'kind': 'event',
  'title': title,
  'start': start,
  'end': ?end,
  'allDay': allDay,
  'calendarId': calendarId,
  'rrule': rrule,
  'exdates': exdates,
  'tz': tz,
};

String utc(DateTime local) => local.toUtc().toIso8601String();

/// Answers each app with the items given.
class FakeLinkedItems implements LinkedItems {
  FakeLinkedItems(this.items);
  final Map<LinkedApp, List<LinkedItem>> items;
  final List<LinkedApp> reads = [];

  @override
  Future<List<LinkedItem>?> read(LinkedApp app) async {
    reads.add(app);
    return items[app];
  }
}

void main() {
  group('ZT Calendar events by day', () {
    test('timed events count, all-day and day-long ones do not', () {
      final read = readCalendar([
        (
          id: 'e1',
          json: event(
            utc(DateTime(2026, 11, 19, 9)),
            end: utc(DateTime(2026, 11, 19, 10)),
          ),
        ),
        (id: 'e2', json: event('2026-11-19', end: '2026-11-20', allDay: true)),
        (
          id: 'e3',
          json: event(
            utc(DateTime(2026, 11, 19, 6)),
            end: utc(DateTime(2026, 11, 20, 6)),
            title: 'Conference',
          ),
        ),
        (
          id: 'e4',
          json: event(
            utc(DateTime(2026, 11, 19, 8, 15)),
            end: utc(DateTime(2026, 11, 19, 8, 45)),
            title: 'Gym',
          ),
        ),
      ]);
      final byDay = timedEventsByDay(read.events, today: today);
      expect(byDay.keys, ['2026-11-19']);
      expect(
        [for (final e in byDay['2026-11-19']!) e.title],
        ['Gym', 'Meeting'],
      );
      expect(firstEventPlan(byDay, earliest: 300), {'2026-11-19': 8 * 60 + 15});
    });

    test('repeating events, with a day taken out, within two weeks', () {
      final start = DateTime(2026, 11, 2, 7, 30); // A Monday.
      final read = readCalendar([
        (
          id: 'standup',
          json: event(
            utc(start),
            end: utc(start.add(const Duration(minutes: 15))),
            rrule: 'FREQ=WEEKLY;BYDAY=MO,WE',
            exdates: [utc(DateTime(2026, 11, 23, 7, 30))],
          ),
        ),
      ]);
      final plan = firstEventPlan(
        timedEventsByDay(read.events, today: today),
        earliest: 300,
      );
      // Today (Wed 18th) through Tue 1 Dec; Mon 23rd was taken out.
      expect(plan.keys.toList()..sort(), [
        '2026-11-18',
        '2026-11-25',
        '2026-11-30',
      ]);
      expect(plan.values.toSet(), {7 * 60 + 30});
    });

    test('events before the earliest time do not count', () {
      final read = readCalendar([
        (
          id: 'night',
          json: event(
            utc(DateTime(2026, 11, 19, 4)),
            end: utc(DateTime(2026, 11, 19, 6)),
          ),
        ),
        (
          id: 'day',
          json: event(
            utc(DateTime(2026, 11, 19, 10)),
            end: utc(DateTime(2026, 11, 19, 11)),
          ),
        ),
      ]);
      final byDay = timedEventsByDay(read.events, today: today);
      expect(firstEventPlan(byDay, earliest: 300), {'2026-11-19': 600});
      expect(firstEventPlan(byDay, earliest: 0), {'2026-11-19': 240});
    });

    test('a repeating event in another zone ends where it says', () {
      // Daily at 09:00 in Tokyo, the last one on 19 November (00:00 UTC).
      final e = LinkedEvent.fromJson(
        event(
          '2026-11-17T00:00:00.000Z',
          end: '2026-11-17T01:00:00.000Z',
          rrule: 'FREQ=DAILY;UNTIL=20261119T000000Z',
          tz: 'Asia/Tokyo',
        ),
      )!;
      final starts = e.startsBetween(
        DateTime.utc(2026, 11, 16).toLocal(),
        DateTime.utc(2026, 11, 25).toLocal(),
      );
      expect(starts, [
        for (final d in [17, 18, 19]) DateTime.utc(2026, 11, d).toLocal(),
      ]);
    });

    test('hidden calendars are left out; subscribed ones count', () {
      final read = readCalendar([
        (
          id: 'work',
          json: {'kind': 'calendar', 'name': 'Work', 'hidden': true},
        ),
        (
          id: 'e1',
          json: event(
            utc(DateTime(2026, 11, 19, 8)),
            end: utc(DateTime(2026, 11, 19, 9)),
            calendarId: 'work',
          ),
        ),
        (
          id: 'feed1',
          json: {
            'kind': 'feed',
            'calendarId': 'team',
            'events': [
              event(
                utc(DateTime(2026, 11, 20, 9)),
                end: utc(DateTime(2026, 11, 20, 10)),
                title: 'Team call',
              ),
            ],
          },
        ),
        // Written by a newer ZT Calendar: left alone.
        (
          id: 'e2',
          json: {
            ...event(
              utc(DateTime(2026, 11, 21, 8)),
              end: utc(DateTime(2026, 11, 21, 9)),
            ),
            '_v': 2,
          },
        ),
      ]);
      expect(read.hidden, {'work'});
      final byDay = timedEventsByDay(
        read.events,
        today: today,
        hiddenCalendars: read.hidden,
      );
      expect(byDay.keys, ['2026-11-20']);
      expect(byDay['2026-11-20']!.single.title, 'Team call');
    });
  });

  group('morning brief', () {
    test('events, tasks due and overdue, and daily quests by day', () {
      final events = {
        '2026-11-19': [
          (start: DateTime(2026, 11, 19, 9), title: 'Team'),
          (start: DateTime(2026, 11, 19, 13), title: 'Lunch'),
        ],
      };
      final brief = morningBrief(
        today: today,
        events: events,
        tasks: [
          LinkedTask('Pay rent', DateTime(2026, 11, 19)),
          LinkedTask('Old one', DateTime(2026, 11, 17)),
          LinkedTask('Done', DateTime(2026, 11, 19), completed: true),
        ],
        goals: const [LinkedGoal('', 'fitness')],
        goalName: (g) => 'Fitness',
        days: 3,
      );
      expect(brief['through'], '2026-11-20');
      final days = brief['days']! as Map<String, Object?>;
      expect(days['2026-11-19'], {
        'events': 2,
        'first': 540,
        'eventList': [
          {'t': 540, 'title': 'Team'},
          {'t': 780, 'title': 'Lunch'},
        ],
        'tasks': 1,
        'overdue': 1,
        'taskList': ['Pay rent', 'Old one'],
        'quests': 1,
        'questList': ['Fitness'],
      });
      // Today: the overdue task and the quest.
      final now = days['2026-11-18']! as Map<String, Object?>;
      expect(now['events'], 0);
      expect(now['overdue'], 1);
      expect(now.containsKey('first'), isFalse);
    });

    test('a day with nothing is left out', () {
      final brief = morningBrief(
        today: today,
        events: const {},
        tasks: const [],
        goals: const [],
        goalName: (_) => '',
        days: 2,
      );
      expect(brief, {'through': '2026-11-19', 'days': <String, Object?>{}});
    });

    test('tasks and goals as the other apps write them', () {
      expect(LinkedTask.fromJson({'title': 'x'}), isNull);
      expect(
        LinkedTask.fromJson({
          'title': 'x',
          'dueDate': '2026-11-19T00:00:00.000',
          'isArchived': true,
        }),
        isNull,
      );
      expect(
        LinkedTask.fromJson({
          'title': ' x ',
          'dueDate': '2026-11-19T00:00:00.000',
        })!.title,
        'x',
      );
      // Items of another kind (Tasks' lists) are not tasks.
      expect(
        LinkedTask.fromJson({'kind': 'list', 'dueDate': '2026-11-19'}),
        isNull,
      );
      expect(LinkedGoal.fromJson({'kind': 'goal', 'archived': true}), isNull);
      expect(
        LinkedGoal.fromJson({'kind': 'goal', 'category': 'sleep'})!.category,
        'sleep',
      );
    });
  });

  group('DayAhead', () {
    testWidgets('gives linked alarms their first events and the morning '
        'screen its day', (tester) async {
      final engine = FakeClockEngine(
        alarms: [
          alarm(
            'linked',
            days: {1, 2, 3, 4, 7},
            calendar: const CalendarLink(earliest: 6 * 60),
          ),
          alarm('plain', days: {1}),
        ],
      );
      final now = DateTime.now();
      final tomorrow8 = DateTime(now.year, now.month, now.day + 1, 8);
      final tomorrow5 = DateTime(now.year, now.month, now.day + 1, 5);
      final items = FakeLinkedItems({
        LinkedApp.calendar: [
          (
            id: 'e1',
            json: event(
              utc(tomorrow8),
              end: utc(tomorrow8.add(const Duration(hours: 1))),
            ),
          ),
          (
            id: 'e0',
            json: event(
              utc(tomorrow5),
              end: utc(tomorrow5.add(const Duration(minutes: 30))),
            ),
          ),
        ],
        LinkedApp.tasks: [
          (
            id: 't1',
            json: {
              'title': 'Call the bank',
              'dueDate': DateTime(
                now.year,
                now.month,
                now.day + 1,
              ).toIso8601String(),
            },
          ),
        ],
        LinkedApp.quests: [
          (id: 'g1', json: {'kind': 'goal', 'category': 'sleep', 'name': ''}),
        ],
      });
      late DayAhead dayAhead;
      late AppL10n l;
      await tester.pumpWidget(
        testApp(
          engine,
          home: Consumer(
            builder: (context, ref, _) {
              dayAhead = ref.read(dayAheadProvider);
              l = AppL10n.of(context);
              return const SizedBox();
            },
          ),
          overrides: [
            linkedItemsProvider.overrideWithValue(items),
            linkedKeysProvider.overrideWith(_Unlocked.new),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => dayAhead.refresh(l));

      final key = dayKey(DateTime(now.year, now.month, now.day + 1));
      final plans = engine.calendarPlans!;
      // Only the linked alarm, and 05:00 is before its earliest 06:00.
      expect(plans.keys, ['linked']);
      final plan = plans['linked']! as Map<String, Object?>;
      expect(plan['days'], {key: 8 * 60});
      expect(
        plan['through'],
        dayKey(DateTime(now.year, now.month, now.day + dayAheadDays - 1)),
      );

      final brief = jsonDecode(engine.morningBrief!) as Map<String, Object?>;
      final day = (brief['days']! as Map)[key] as Map;
      expect(day['events'], 2);
      expect(day['tasks'], 1);
      expect(day['questList'], ['Sleep']);

      // Within a few minutes it doesn't read again, unless asked to.
      items.reads.clear();
      await tester.runAsync(() => dayAhead.refresh(l));
      expect(items.reads, isEmpty);
      await tester.runAsync(() => dayAhead.refresh(l, force: true));
      expect(items.reads, isNotEmpty);
    });

    testWidgets('an alarm linked while a refresh runs gets its plan', (
      tester,
    ) async {
      final engine = FakeClockEngine(
        alarms: [
          alarm('old', days: {1}),
        ],
      );
      final items = _GatedItems({LinkedApp.calendar: const []});
      late DayAhead dayAhead;
      late AppL10n l;
      await tester.pumpWidget(
        testApp(
          engine,
          home: Consumer(
            builder: (context, ref, _) {
              dayAhead = ref.read(dayAheadProvider);
              l = AppL10n.of(context);
              return const SizedBox();
            },
          ),
          overrides: [
            linkedItemsProvider.overrideWithValue(items),
            linkedKeysProvider.overrideWith(_Unlocked.new),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final gate = items.gate = Completer<void>();
        final first = dayAhead.refresh(l, force: true);
        // The first run has read the alarms and waits on ZT Tasks.
        while (!items.reads.contains(LinkedApp.tasks)) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(engine.calendarPlans, isNull);
        engine.alarms.add(
          alarm('new', days: {1}, calendar: const CalendarLink()),
        );
        final second = dayAhead.refresh(l, force: true);
        gate.complete();
        await Future.wait([first, second]);
      });
      expect(engine.calendarPlans!.keys, ['new']);
    });

    testWidgets('locked or signed out: nothing is read', (tester) async {
      final engine = FakeClockEngine();
      final items = FakeLinkedItems(const {});
      late DayAhead dayAhead;
      late AppL10n l;
      await tester.pumpWidget(
        testApp(
          engine,
          home: Consumer(
            builder: (context, ref, _) {
              dayAhead = ref.read(dayAheadProvider);
              l = AppL10n.of(context);
              return const SizedBox();
            },
          ),
          overrides: [linkedItemsProvider.overrideWithValue(items)],
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => dayAhead.refresh(l, force: true));
      expect(items.reads, isEmpty);
      expect(engine.morningBrief, isNull);
    });
  });

  group('sync', () {
    test('a shift pattern, the calendar link and smart wake go to the '
        'account and back', () {
      final a = alarm(
        's',
        hour: 6,
        shift: const ShiftPattern('11000000', '2026-11-18'),
        calendar: const CalendarLink(lead: 45, follow: true),
        smartWake: 20,
        updatedAt: 5,
      );
      final synced = SyncedAlarm.fromEngine(a, device: 'p1');
      final back = SyncedAlarm.fromJson(
        's',
        jsonDecode(jsonEncode(synced.toJson())) as Map<String, Object?>,
      ).toEngine('p1');
      expect(back.shift, a.shift);
      expect(back.calendar, a.calendar);
      expect(back.smartWake, 20);
      expect(back.repeats, isTrue);
      expect(back.date, isNull);
    });

    test('an alarm that rings once has no calendar link', () {
      final a = alarm('o', calendar: const CalendarLink());
      expect(SyncedAlarm.fromEngine(a, device: 'p1').calendar, isNull);
    });
  });

  group('editor', () {
    Future<void> openEditor(WidgetTester tester) async {
      await tester.tap(find.text('7:00 AM'));
      await tester.pumpAndSettle();
    }

    Future<void> scrollTo(WidgetTester tester, Finder f) async {
      await tester.scrollUntilVisible(f, 200, scrollable: editorScroll);
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) async {
      final save = find.widgetWithText(FilledButton, 'Save');
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
    }

    testWidgets('a shift pattern from a preset', (tester) async {
      final engine = FakeClockEngine(
        alarms: [
          alarm('a', days: {1, 2}),
        ],
      );
      await tester.pumpWidget(testApp(engine));
      await tester.pumpAndSettle();
      await openEditor(tester);
      await tester.tap(find.text('Shift pattern'));
      await tester.pumpAndSettle();
      // Weekdays make way for the cycle's days.
      expect(find.byTooltip('Monday'), findsNothing);
      await tester.tap(find.text('4 on, 4 off'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Day 8'), findsOneWidget);
      // Day 2 off: three of every eight days.
      await tester.tap(find.byTooltip('Day 2'));
      await tester.pumpAndSettle();
      await save(tester);

      final shift = engine.lastSave['shift']! as ShiftPattern;
      expect(shift.days, '10110000');
      expect(shift.start, dayKey(DateTime.now()));
      expect(engine.calls.last, startsWith('save a 7:0 [] '));
      expect(
        inCard(find.textContaining('Shifts: 3 of every 8 days')),
        findsOneWidget,
      );
    });

    testWidgets('smart wake window', (tester) async {
      final engine = FakeClockEngine(
        alarms: [
          alarm('a', days: {1, 2}),
        ],
      );
      await tester.pumpWidget(testApp(engine));
      await tester.pumpAndSettle();
      await openEditor(tester);
      final twenty = find.descendant(
        of: find.byKey(const ValueKey('smartWake')),
        matching: find.text('20 min'),
      );
      await scrollTo(tester, twenty);
      await tester.tap(twenty);
      await tester.pumpAndSettle();
      await save(tester);
      expect(engine.lastSave['smartWake'], 20);
    });

    testWidgets('Follow ZT Calendar needs an account', (tester) async {
      final engine = FakeClockEngine(
        alarms: [
          alarm('a', days: {1, 2}),
        ],
      );
      await tester.pumpWidget(testApp(engine));
      await tester.pumpAndSettle();
      await openEditor(tester);
      final link = find.byKey(const ValueKey('calendarLink'));
      await scrollTo(tester, link);
      expect(find.text('Sign in to follow ZT Calendar.'), findsOneWidget);
      await tester.tap(link);
      await tester.pumpAndSettle();
      await save(tester);
      expect(engine.lastSave['calendar'], isNull);
    });

    testWidgets('Follow ZT Calendar, signed in', (tester) async {
      final engine = FakeClockEngine(
        alarms: [
          alarm('a', days: {1, 2}),
        ],
      );
      await tester.pumpWidget(
        testApp(
          engine,
          overrides: [
            signedInProvider.overrideWithValue(true),
            linkedItemsProvider.overrideWithValue(FakeLinkedItems(const {})),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await openEditor(tester);
      final link = find.byKey(const ValueKey('calendarLink'));
      await scrollTo(tester, link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      final ninety = find.descendant(
        of: find.byKey(const ValueKey('calendarLead')),
        matching: find.text('90 min'),
      );
      await scrollTo(tester, ninety);
      await tester.tap(ninety);
      await tester.pumpAndSettle();
      final follow = find.byKey(const ValueKey('calendarFollow'));
      await scrollTo(tester, follow);
      await tester.tap(follow);
      await tester.pumpAndSettle();
      final other = find.byKey(const ValueKey('calendarOtherDays'));
      await scrollTo(tester, other);
      await tester.tap(other);
      await tester.pumpAndSettle();
      await save(tester);
      expect(
        engine.lastSave['calendar'],
        const CalendarLink(lead: 90, follow: true, otherDays: true),
      );
      expect(
        inCard(find.textContaining('Follows ZT Calendar')),
        findsOneWidget,
      );
    });

    testWidgets('an alarm without repeat days cannot follow the calendar', (
      tester,
    ) async {
      final engine = FakeClockEngine(alarms: [alarm('a')]);
      await tester.pumpWidget(
        testApp(engine, overrides: [signedInProvider.overrideWithValue(true)]),
      );
      await tester.pumpAndSettle();
      await openEditor(tester);
      final link = find.byKey(const ValueKey('calendarLink'));
      await scrollTo(tester, link);
      expect(
        find.text('Pick repeat days or a shift pattern first.'),
        findsOneWidget,
      );
      expect(tester.widget<SwitchListTile>(link).onChanged, isNull);
    });
  });

  testWidgets('signing out from the unlock screen forgets the morning '
      'screen', (tester) async {
    final engine = FakeClockEngine()..morningBrief = '{}';
    await tester.pumpWidget(
      testApp(
        engine,
        home: const ClockGate(),
        overrides: [
          signedInProvider.overrideWith((ref) => ref.watch(_signedIn)),
        ],
      ),
    );
    await tester.pumpAndSettle();
    // Signed in and locked: the unlock screen, no day-ahead host.
    expect(find.byType(DayAheadHost), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ClockGate)),
    );
    container.read(_signedIn.notifier).set(false);
    await tester.pumpAndSettle();
    expect(engine.calls, contains('setMorningBrief null'));
    expect(engine.morningBrief, isNull);
  });

  testWidgets('morning screen setting', (tester) async {
    final engine = FakeClockEngine();
    await tester.pumpWidget(testApp(engine, home: const ClockSettingsPage()));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('morningScreen'));
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('The day ahead, counts only'), findsOneWidget);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('The day ahead, with names').last);
    await tester.pumpAndSettle();
    expect(engine.ring.morning, MorningScreen.details);
    expect(
      RingSettings.fromMap(engine.ring.toMap()).morning,
      MorningScreen.details,
    );
  });
}

/// Keys present, as after an unlock.
class _Unlocked extends LinkedKeys {
  @override
  Map<LinkedApp, Uint8List> build() => {
    for (final app in LinkedApp.values) app: Uint8List(32),
  };
}

/// Holds ZT Tasks' read until [gate] completes.
class _GatedItems extends FakeLinkedItems {
  _GatedItems(super.items);
  Completer<void>? gate;

  @override
  Future<List<LinkedItem>?> read(LinkedApp app) async {
    final result = await super.read(app);
    final g = gate;
    if (app == LinkedApp.tasks && g != null) {
      gate = null;
      await g.future;
    }
    return result;
  }
}

/// Signed in until a test signs out.
final _signedIn = NotifierProvider<_SignedIn, bool>(_SignedIn.new);

class _SignedIn extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}
