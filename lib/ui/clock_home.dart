import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/clock_engine.dart';
import '../l10n/l10n.dart';
import 'alarms_page.dart';
import 'stopwatch_page.dart';
import 'timers_page.dart';
import 'world_clock_page.dart';

/// The app's tabs, as the engine names them in notifications.
enum ClockTab { alarms, clock, timers, stopwatch }

/// Something a shortcut asked for, done by its tab once it is on screen.
enum HomeAction { newAlarm, newTimer, startStopwatch }

final homeActionProvider = NotifierProvider<HomeActionController, HomeAction?>(
  HomeActionController.new,
);

class HomeActionController extends Notifier<HomeAction?> {
  @override
  HomeAction? build() => null;

  void ask(HomeAction action) => state = action;

  /// True (and cleared) when [action] is waiting: the tab does it.
  bool take(HomeAction action) {
    if (state != action) return false;
    state = null;
    return true;
  }
}

/// Runs [run] once [action] is asked for, also when it was asked before
/// this tab was built (the shortcut opened the app on it).
void onHomeAction(WidgetRef ref, HomeAction action, VoidCallback run) {
  if (ref.watch(homeActionProvider) != action) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (ref.read(homeActionProvider.notifier).take(action)) run();
  });
}

/// The tab on screen.
final clockTabProvider = NotifierProvider<ClockTabController, ClockTab>(
  ClockTabController.new,
);

class ClockTabController extends Notifier<ClockTab> {
  @override
  ClockTab build() => ClockTab.alarms;

  void show(ClockTab tab) => state = tab;

  /// "timers" from a notification, or a shortcut ("newAlarm"); unknown
  /// names are ignored.
  void showNamed(String? name) {
    for (final tab in ClockTab.values) {
      if (tab.name == name) state = tab;
    }
    final (tab, action) = switch (name) {
      'newAlarm' => (ClockTab.alarms, HomeAction.newAlarm),
      'newTimer' => (ClockTab.timers, HomeAction.newTimer),
      'startStopwatch' => (ClockTab.stopwatch, HomeAction.startStopwatch),
      _ => (null, null),
    };
    if (tab == null || action == null) return;
    state = tab;
    ref.read(homeActionProvider.notifier).ask(action);
  }
}

/// Alarms, Clock, Timers and Stopwatch, with the bar to switch between them.
class ClockHome extends ConsumerStatefulWidget {
  const ClockHome({super.key});

  @override
  ConsumerState<ClockHome> createState() => _ClockHomeState();
}

class _ClockHomeState extends ConsumerState<ClockHome> {
  StreamSubscription<String>? _tabs;

  @override
  void initState() {
    super.initState();
    final engine = ref.read(clockEngineProvider);
    // Opened from a timer's or the stopwatch's notification.
    engine
        .launchTab()
        .then((tab) {
          if (mounted) ref.read(clockTabProvider.notifier).showNamed(tab);
        })
        .catchError((Object _) {});
    _tabs = engine.openTab.listen((tab) {
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      ref.read(clockTabProvider.notifier).showNamed(tab);
    });
  }

  @override
  void dispose() {
    _tabs?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tab = ref.watch(clockTabProvider);
    return Scaffold(
      body: switch (tab) {
        ClockTab.alarms => const AlarmsPage(),
        ClockTab.clock => const WorldClockPage(),
        ClockTab.timers => const TimersPage(),
        ClockTab.stopwatch => const StopwatchPage(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab.index,
        onDestinationSelected: (i) =>
            ref.read(clockTabProvider.notifier).show(ClockTab.values[i]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.alarm_outlined),
            selectedIcon: const Icon(Icons.alarm),
            label: l.alarms,
          ),
          NavigationDestination(
            icon: const Icon(Icons.schedule_outlined),
            selectedIcon: const Icon(Icons.schedule),
            label: l.clock,
          ),
          NavigationDestination(
            icon: const Icon(Icons.hourglass_empty),
            selectedIcon: const Icon(Icons.hourglass_bottom),
            label: l.timers,
          ),
          NavigationDestination(
            icon: const Icon(Icons.timer_outlined),
            selectedIcon: const Icon(Icons.timer),
            label: l.stopwatch,
          ),
        ],
      ),
    );
  }
}
