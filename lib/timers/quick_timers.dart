import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../sync/settings_sync.dart';

/// Quick timers everyone gets.
const defaultQuickTimers = [
  Duration(minutes: 1),
  Duration(minutes: 3),
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 15),
  Duration(minutes: 30),
];

/// The quick timers the user saved, on this phone and backed up with the
/// account.
class QuickTimersController extends AsyncNotifier<List<Duration>> {
  static const _key = 'clock_quick_timers';
  static const limit = 12;

  PreferencesStore get _prefs => ref.read(ztPreferencesStoreProvider);

  @override
  Future<List<Duration>> build() async {
    try {
      final raw = await _prefs.read(_key);
      if (raw == null) return const [];
      return [
        for (final s in jsonDecode(raw) as List)
          if (s is int && s > 0) Duration(seconds: s),
      ];
    } on Object {
      return const [];
    }
  }

  Future<void> _write(List<Duration> list, {bool byHand = true}) async {
    state = AsyncData(list);
    await _prefs.write(_key, jsonEncode([for (final d in list) d.inSeconds]));
    // A change made here is backed up (sync/settings_sections.dart).
    if (byHand) await ref.read(settingsEditsProvider).touch(settingsName);
  }

  /// The group's name in the account's backup.
  static const settingsName = 'quick-timers';

  /// Puts the account's quick timers here.
  Future<void> restore(List<Duration> list) async {
    await future;
    final kept = {
      for (final d in list)
        if (d > Duration.zero && !defaultQuickTimers.contains(d)) d,
    }.toList()..sort();
    await _write(kept.take(limit).toList(), byHand: false);
  }

  Future<void> add(Duration d) async {
    final now = [...await future];
    if (now.contains(d) || defaultQuickTimers.contains(d)) return;
    await _write(([...now, d]..sort()).take(limit).toList());
  }

  Future<void> remove(Duration d) async => _write([...await future]..remove(d));
}

final quickTimersProvider =
    AsyncNotifierProvider<QuickTimersController, List<Duration>>(
      QuickTimersController.new,
    );
