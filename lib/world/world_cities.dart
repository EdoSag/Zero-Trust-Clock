import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../engine/clock_engine.dart';
import '../sync/settings_sync.dart';
import 'world_zone.dart';

/// The world clock's cities (time zone ids), in the user's order. Kept on
/// this phone, handed to the engine for the widget, and backed up with
/// the account.
class WorldCitiesController extends AsyncNotifier<List<String>> {
  static const _key = 'clock_world_cities';
  static const limit = 50;

  PreferencesStore get _prefs => ref.read(ztPreferencesStoreProvider);

  @override
  Future<List<String>> build() async {
    try {
      final raw = await _prefs.read(_key);
      if (raw == null) return const [];
      return [
        for (final id in jsonDecode(raw) as List)
          if (id is String) id,
      ];
    } on Object {
      return const [];
    }
  }

  Future<void> _write(List<String> ids, {bool byHand = true}) async {
    state = AsyncData(ids);
    await _prefs.write(_key, jsonEncode(ids));
    try {
      await ref.read(clockEngineProvider).setWorldCities(ids);
    } on Object {
      // Only the widget; it reads them again next time.
    }
    // A change made here is backed up (sync/settings_sections.dart).
    if (byHand) await ref.read(settingsEditsProvider).touch(settingsName);
  }

  /// The group's name in the account's backup.
  static const settingsName = 'cities';

  /// Puts the account's cities here.
  Future<void> restore(List<String> ids) async {
    await future;
    await _write(ids.take(limit).toList(), byHand: false);
  }

  Future<void> add(String id) async {
    final now = [...await future];
    if (now.contains(id) || now.length >= limit) return;
    await _write([...now, id]);
  }

  Future<void> insert(int index, String id) async {
    final now = [...await future]..remove(id);
    await _write(now..insert(index.clamp(0, now.length), id));
  }

  Future<void> remove(String id) async => _write([...await future]..remove(id));

  /// Moves the city at [from] so it ends up at [to].
  Future<void> move(int from, int to) async {
    final now = [...await future];
    if (from < 0 || from >= now.length) return;
    final id = now.removeAt(from);
    now.insert(to.clamp(0, now.length), id);
    await _write(now);
  }
}

final worldCitiesProvider =
    AsyncNotifierProvider<WorldCitiesController, List<String>>(
      WorldCitiesController.new,
    );

/// Every city, named in the app's language. Read again when the language
/// changes.
final allZonesProvider = FutureProvider<List<WorldZone>>((ref) {
  ref.watch(ztLanguageProvider);
  return ref.watch(clockEngineProvider).zones();
});

/// The picked cities with their offsets as they are now. The world clock
/// invalidates it every few minutes, so a change of daylight saving time
/// shows up.
final savedZonesProvider = FutureProvider<List<WorldZone>>((ref) async {
  final ids = await ref.watch(worldCitiesProvider.future);
  final all = await ref.watch(allZonesProvider.future);
  final byId = {for (final z in all) z.id: z};
  final offsets = await ref.read(clockEngineProvider).zoneOffsets(ids);
  return [
    for (final id in ids)
      if (byId[id] case final z?) z.withOffset(offsets[id] ?? z.offset),
  ];
});
