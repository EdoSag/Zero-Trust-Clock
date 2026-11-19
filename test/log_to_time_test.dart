import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_clock/engine/clock_timer.dart';
import 'package:zerotrust_clock/time_log/time_log.dart';
import 'package:zerotrust_clock/ui/log_time_sheet.dart';
import 'package:zerotrust_clock/ui/stopwatch_page.dart';
import 'package:zerotrust_clock/ui/timers_page.dart';

import 'support/app.dart';
import 'support/fake_engine.dart';
import 'timers_test.dart' show frames, tallPhone;

class FakeTimeLog implements TimeLog {
  FakeTimeLog({this.available = true, this.fail = false});

  @override
  final bool available;
  bool fail;
  final logged = <Map<String, Object?>>[];

  int flushes = 0;

  @override
  Future<void> flush() async => flushes++;

  @override
  Future<List<TimeProject>> projects() async => const [
    TimeProject('p1', 'Website', client: 'Acme'),
    TimeProject('p2', 'Writing'),
  ];

  @override
  Future<void> log({
    required DateTime start,
    required DateTime end,
    required String description,
    String? projectId,
  }) async {
    if (fail) throw StateError('offline');
    logged.add({
      'length': end.difference(start),
      'description': description,
      'projectId': projectId,
    });
  }
}

Widget app(FakeClockEngine engine, Widget home, TimeLog log) => testApp(
  engine,
  home: home,
  overrides: [timeLogProvider.overrideWithValue(log)],
);

ProviderContainer keyContainer(FakeTimeLog log) => ProviderContainer(
  overrides: [
    timeLogProvider.overrideWithValue(log),
    ztPreferencesStoreProvider.overrideWithValue(InMemoryPreferencesStore()),
    accountServiceProvider.overrideWithValue(
      AccountService(SignedOutBackend()),
    ),
  ],
);

void main() {
  test('the Time key comes at unlock, and offline entries go up', () async {
    final log = FakeTimeLog();
    final c = keyContainer(log);
    addTearDown(c.dispose);
    await c.read(timeKeyProvider.notifier).deriveFrom(Uint8List(32));
    expect(c.read(timeKeyProvider), hasLength(32));
    expect(log.flushes, 1);
  });

  test('a key derived after the vault locked is dropped', () async {
    final log = FakeTimeLog();
    final c = keyContainer(log);
    addTearDown(c.dispose);
    final key = c.read(timeKeyProvider.notifier);
    final deriving = key.deriveFrom(Uint8List(32));
    key.clear(); // Locked while it worked.
    await deriving;
    expect(c.read(timeKeyProvider), isNull);
    expect(log.flushes, 0);
  });

  test('an entry is written the way ZT Time writes one', () {
    final start = DateTime.utc(2026, 11, 19, 9);
    final j = timeEntryJson(
      start: start,
      end: start.add(const Duration(minutes: 25)),
      description: 'Focus',
      projectId: 'p1',
      now: start,
    );
    expect(j, {
      'description': 'Focus',
      'projectId': 'p1',
      'tags': <String>[],
      'start': '2026-11-19T09:00:00.000Z',
      'end': '2026-11-19T09:25:00.000Z',
      'billable': false,
      'createdAt': '2026-11-19T09:00:00.000Z',
      'kind': 'entry',
      '_v': 1,
    });
    final id = newTimeItemId(Random(1));
    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        ),
      ),
    );
  });

  testWidgets('a paused stopwatch logs its time to a project', (tester) async {
    tallPhone(tester);
    final engine = FakeClockEngine()
      ..stopwatchState = const StopwatchState(
        banked: Duration(minutes: 42),
        laps: [Duration(minutes: 20)],
      );
    final log = FakeTimeLog();
    await tester.pumpWidget(app(engine, const StopwatchPage(), log));
    await frames(tester);
    final button = find.byTooltip('Log to ZT Time');
    expect(button, findsOneWidget);
    // Before Copy laps.
    expect(
      tester.getRect(button).right,
      lessThanOrEqualTo(tester.getRect(find.byTooltip('Copy laps')).left),
    );

    await tester.tap(button);
    await frames(tester);
    expect(find.byType(LogTimeSheet), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('logSpan'))).data,
      endsWith('(42:00)'),
    );
    // Title, span, text, project, then Log, top to bottom.
    final title = tester.getRect(find.text('Log to ZT Time').last);
    final span = tester.getRect(find.byKey(const ValueKey('logSpan')));
    final text = tester.getRect(find.byType(TextField));
    final project = tester.getRect(find.byKey(const ValueKey('logProject')));
    final logIt = tester.getRect(find.widgetWithText(FilledButton, 'Log'));
    expect(title.bottom, lessThanOrEqualTo(span.top));
    expect(span.bottom, lessThanOrEqualTo(text.top));
    expect(text.bottom, lessThanOrEqualTo(project.top));
    expect(project.bottom, lessThanOrEqualTo(logIt.top));

    await tester.enterText(find.byType(TextField), 'Homepage copy');
    await tester.tap(find.byKey(const ValueKey('logProject')));
    await frames(tester);
    await tester.tap(find.text('Website · Acme').last);
    await frames(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Log'));
    await frames(tester);
    expect(log.logged.single, {
      'length': const Duration(minutes: 42),
      'description': 'Homepage copy',
      'projectId': 'p1',
    });
    expect(find.byType(LogTimeSheet), findsNothing);
    expect(find.text('Logged in ZT Time'), findsOneWidget);
  });

  testWidgets('no Log button while it runs, or without the account', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine()
      ..stopwatchState = StopwatchState(startedAt: DateTime.now());
    await tester.pumpWidget(app(engine, const StopwatchPage(), FakeTimeLog()));
    await frames(tester);
    expect(find.byTooltip('Log to ZT Time'), findsNothing);

    final paused = FakeClockEngine()
      ..stopwatchState = const StopwatchState(banked: Duration(minutes: 5));
    await tester.pumpWidget(
      app(paused, const StopwatchPage(), FakeTimeLog(available: false)),
    );
    await frames(tester);
    expect(find.byTooltip('Log to ZT Time'), findsNothing);
  });

  testWidgets('a timer that rang logs its length with its label', (
    tester,
  ) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    engine.timerList.add(
      ClockTimer(
        id: 'focus',
        length: const Duration(minutes: 25),
        label: 'Focus',
        endsAt: DateTime.now().subtract(const Duration(seconds: 3)),
        ringing: true,
      ),
    );
    final log = FakeTimeLog()..fail = true;
    await tester.pumpWidget(app(engine, const TimersPage(), log));
    await frames(tester);
    final button = find.byKey(const ValueKey('logTimer-focus'));
    // In the timer's top row, before Delete.
    expect(
      tester.getRect(button).right,
      lessThanOrEqualTo(tester.getRect(find.byTooltip('Delete timer')).left),
    );
    expect(
      tester.getRect(button).top,
      lessThan(tester.getRect(find.byKey(const ValueKey('left-focus'))).top),
    );

    await tester.tap(button);
    await frames(tester);
    // The ringing stops; the sheet has the label.
    expect(engine.calls, contains('stopRingingTimers'));
    expect(find.widgetWithText(TextField, 'Focus'), findsOneWidget);

    // Offline: it says so and stays open.
    await tester.tap(find.widgetWithText(FilledButton, 'Log'));
    await frames(tester);
    expect(find.textContaining("Couldn't log it"), findsOneWidget);
    expect(find.byType(LogTimeSheet), findsOneWidget);
    log.fail = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Log'));
    await frames(tester);
    expect(log.logged.single['length'], const Duration(minutes: 25));
    expect(log.logged.single['description'], 'Focus');
    expect(log.logged.single['projectId'], isNull);
  });

  testWidgets('no Log button on a timer without the account', (tester) async {
    tallPhone(tester);
    final engine = FakeClockEngine();
    engine.timerList.add(
      ClockTimer(
        id: 'focus',
        length: const Duration(minutes: 25),
        endsAt: DateTime.now(),
        ringing: true,
      ),
    );
    await tester.pumpWidget(
      app(engine, const TimersPage(), FakeTimeLog(available: false)),
    );
    await frames(tester);
    expect(find.byKey(const ValueKey('logTimer-focus')), findsNothing);
  });
}
