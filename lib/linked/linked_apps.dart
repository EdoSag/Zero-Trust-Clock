import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../engine/alarm.dart';
import '../engine/clock_engine.dart';
import '../l10n/l10n.dart';
import 'day_ahead.dart';

/// The apps Clock reads for the day ahead. It never writes to them.
enum LinkedApp {
  calendar('calendar'),
  tasks('tasks'),
  quests('quests');

  const LinkedApp(this.appId);

  /// The app's id: its key label and `vault_items.app` value.
  final String appId;
}

/// The other apps' keys for the unlocked account, derived from the account
/// key at unlock (as ZT Calendar derives Notes', Tasks' and Contacts') and
/// zeroed when the vault locks.
final linkedKeysProvider =
    NotifierProvider<LinkedKeys, Map<LinkedApp, Uint8List>>(LinkedKeys.new);

class LinkedKeys extends Notifier<Map<LinkedApp, Uint8List>> {
  /// Bumped by every derive and clear: a derive that finishes after the
  /// vault locked is dropped.
  int _generation = 0;

  /// The same keys as [state], for zeroing on dispose (when [state] can't
  /// be read).
  Map<LinkedApp, Uint8List> _keys = const {};

  @override
  Map<LinkedApp, Uint8List> build() {
    ref.listen(vaultControllerProvider, (_, VaultState next) {
      if (next is VaultLocked) clear();
    });
    ref.onDispose(() {
      _generation++;
      _zero(_keys);
      _keys = const {};
    });
    return _keys;
  }

  /// Doesn't take ownership of [dek].
  Future<void> deriveFrom(Uint8List dek) async {
    final mine = ++_generation;
    final keys = <LinkedApp, Uint8List>{
      for (final app in LinkedApp.values)
        app: await KeyHierarchy.appKey(dek, app.appId),
    };
    if (mine != _generation) {
      _zero(keys);
      return;
    }
    _zero(_keys);
    state = _keys = keys;
  }

  void clear() {
    _generation++;
    _zero(_keys);
    state = _keys = const {};
  }

  static void _zero(Map<LinkedApp, Uint8List> keys) {
    for (final key in keys.values) {
      key.fillRange(0, key.length, 0);
    }
  }
}

/// Lets the sync engine pull another app's items but never upload.
class ReadOnlySyncBackend implements SyncBackend {
  ReadOnlySyncBackend(this.inner);
  final SyncBackend inner;

  @override
  Future<List<RemoteItem>> pull(String app, {DateTime? since}) =>
      inner.pull(app, since: since);

  @override
  Future<List<RemoteItem>> fetch(String app, Set<String> itemIds) =>
      inner.fetch(app, itemIds);

  @override
  Future<Set<String>> pushAll(String app, List<RemoteItem> items) async {
    if (items.isNotEmpty) throw StateError('Clock never writes $app items');
    return <String>{};
  }

  @override
  Future<void> Function() subscribe(
    String app,
    void Function(RemoteItem) onChange,
  ) => inner.subscribe(app, onChange);
}

/// One item of another app: its id and JSON.
typedef LinkedItem = ({String id, Map<String, Object?> json});

/// Reads another app's items. Tests replace it.
abstract class LinkedItems {
  /// The app's live items (item id and JSON), after pulling the account's
  /// latest; the copy kept on this phone when offline. Null when it can't
  /// be reached (signed out or locked).
  Future<List<LinkedItem>?> read(LinkedApp app);
}

final linkedItemsProvider = Provider<LinkedItems>((ref) {
  ref.watch(linkedKeysProvider);
  return VaultLinkedItems(ref);
});

/// Keeps a small encrypted copy of each app's items on this phone (opened
/// with that app's key, like ZT Calendar's mirrors), separate from the
/// app's own file: deleting it loses nothing.
class VaultLinkedItems implements LinkedItems {
  VaultLinkedItems(this.ref);
  final Ref ref;

  @override
  Future<List<LinkedItem>?> read(LinkedApp app) async {
    final unlocked = ref.read(linkedKeysProvider)[app];
    if (unlocked == null) return null;
    final key = Uint8List.fromList(unlocked);
    try {
      final userId = ref.read(accountServiceProvider).currentUserId;
      if (userId == null) return null;
      final path = await ZtLocalStore.pathFor(
        appId: 'clock_${app.appId}',
        userId: userId,
      );
      ZtLocalStore store;
      try {
        store = await ZtLocalStore.open(appKey: key, path: path);
      } on LocalStoreUnreadable {
        await ZtLocalStore.moveAside(path);
        store = await ZtLocalStore.open(appKey: key, path: path);
      }
      final engine = await ItemSyncEngine.fromVault(
        appId: app.appId,
        appKey: key,
        deviceId: await ref.read(ztDeviceIdProvider.future),
        store: store,
        backend: ReadOnlySyncBackend(ref.read(ztSyncBackendProvider)),
      );
      try {
        try {
          await engine.sync();
        } on Object {
          // Offline: the copy from the last read is used.
        }
        return [
          for (final item in await store.all())
            if (!item.deleted && item.json != null)
              (id: item.itemId, json: item.json!),
        ];
      } finally {
        await engine.close();
        await store.close();
      }
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }
}

/// ZT Calendar's events (its own, and subscribed calendars' last copy),
/// without hidden calendars.
({List<LinkedEvent> events, Set<String> hidden}) readCalendar(
  List<LinkedItem> items,
) {
  final events = <LinkedEvent>[];
  final hidden = <String>{};
  for (final (:id, json: j) in items) {
    if (ZtCollection.versionOf(j) > 1) continue;
    switch (j[ZtCollection.kindKey]) {
      case 'event':
        if (LinkedEvent.fromJson(j) case final LinkedEvent e) events.add(e);
      case 'calendar':
        // A calendar's item id is the calendar's id.
        if (j['hidden'] == true) hidden.add(id);
      case 'feed':
        final calendarId = j['calendarId'] as String? ?? '';
        if (j['events'] case final List list) {
          for (final e in list) {
            if (e is Map) {
              final event = LinkedEvent.fromJson(
                Map<String, Object?>.from(e),
                calendarId: calendarId,
              );
              if (event != null) events.add(event);
            }
          }
        }
    }
  }
  return (events: events, hidden: hidden);
}

/// Works out the day ahead from ZT Calendar, ZT Tasks and ZT Quests and
/// hands it to the engine: each linked alarm's first events, and the
/// morning screen. Runs when the vault opens, when the app comes back to
/// the screen (at most every few minutes) and right after an alarm is
/// linked or changed.
class DayAhead {
  DayAhead(this.ref);
  final Ref ref;

  DateTime? _lastRun;
  Future<void>? _running;

  /// A forced refresh asked for while a run was going: that run may have
  /// read the alarms before the change, so it runs once more.
  bool _again = false;

  static const minGap = Duration(minutes: 5);

  /// [l10n] names goals without a name of their own.
  Future<void> refresh(AppL10n l10n, {bool force = false}) {
    final now = DateTime.now();
    if (!force && _lastRun != null && now.difference(_lastRun!) < minGap) {
      return Future.value();
    }
    final running = _running;
    if (running != null) {
      if (force) _again = true;
      return running;
    }
    return _running = _runUntilDone(l10n).whenComplete(() => _running = null);
  }

  Future<void> _runUntilDone(AppL10n l10n) async {
    do {
      _again = false;
      final now = DateTime.now();
      _lastRun = now;
      await _run(now, l10n);
    } while (_again);
  }

  Future<void> _run(DateTime now, AppL10n l) async {
    if (ref.read(linkedKeysProvider).isEmpty) return;
    final items = ref.read(linkedItemsProvider);
    final engine = ref.read(clockEngineProvider);
    final calendar = await _tryRead(items, LinkedApp.calendar);
    final read = calendar == null ? null : readCalendar(calendar);
    final byDay = read == null
        ? const <String, List<DayEvent>>{}
        : timedEventsByDay(
            read.events,
            today: now,
            hiddenCalendars: read.hidden,
          );
    if (read != null) {
      final alarms = await engine.list();
      final through = DateTime(now.year, now.month, now.day + dayAheadDays - 1);
      final plans = <String, Object?>{
        for (final a in alarms)
          if (a.calendar case final CalendarLink link)
            a.id: {
              'through': dayKey(through),
              'days': firstEventPlan(byDay, earliest: link.earliest),
            },
      };
      if (plans.isNotEmpty) await engine.setCalendarPlans(plans);
    }
    final tasks = await _tryRead(items, LinkedApp.tasks);
    final quests = await _tryRead(items, LinkedApp.quests);
    if (read == null && tasks == null && quests == null) return;
    final brief = morningBrief(
      today: now,
      events: byDay,
      tasks: [
        for (final i in tasks ?? const <LinkedItem>[])
          if (LinkedTask.fromJson(i.json) case final LinkedTask t) t,
      ],
      goals: [
        for (final i in quests ?? const <LinkedItem>[])
          if (LinkedGoal.fromJson(i.json) case final LinkedGoal g) g,
      ],
      goalName: (g) => g.name.isNotEmpty ? g.name : l.questGoal(g.category),
    );
    await engine.setMorningBrief(jsonEncode(brief));
  }

  static Future<List<LinkedItem>?> _tryRead(
    LinkedItems items,
    LinkedApp app,
  ) async {
    try {
      return await items.read(app);
    } on Object {
      return null;
    }
  }
}

final dayAheadProvider = Provider<DayAhead>((ref) => DayAhead(ref));

/// Refreshes the day ahead when the vault opens and when the app comes
/// back to the screen. Without an account it does nothing.
class DayAheadHost extends ConsumerStatefulWidget {
  const DayAheadHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DayAheadHost> createState() => _DayAheadHostState();
}

class _DayAheadHostState extends ConsumerState<DayAheadHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(linkedKeysProvider, (_, keys) {
      if (keys.isEmpty) return;
      // After the frame: the language is read from the widget tree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_refresh(force: true));
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh({bool force = false}) async {
    if (!mounted) return;
    try {
      await ref.read(dayAheadProvider).refresh(context.l10n, force: force);
    } on Object {
      // The engine keeps what it had; the next unlock tries again.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
