import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../engine/bedtime.dart';
import '../engine/clock_engine.dart';
import '../holidays/holidays.dart';
import '../timers/quick_timers.dart';
import '../world/world_cities.dart';
import 'settings_sync.dart';

/// The world clock's cities, in order.
class CitiesSection implements SettingsSection {
  CitiesSection(this._ref);
  final Ref _ref;

  @override
  String get name => WorldCitiesController.settingsName;

  @override
  Map<String, Object?> get fresh => const {'zones': <String>[]};

  static List<String> _zones(Map<String, Object?> data) => [
    if (data['zones'] case final List zones)
      for (final id in zones)
        if (id is String) id,
  ];

  @override
  Future<Map<String, Object?>> read() async => {
    'zones': await _ref.read(worldCitiesProvider.future),
  };

  @override
  Future<void> apply(Map<String, Object?> data) =>
      _ref.read(worldCitiesProvider.notifier).restore(_zones(data));

  /// This phone's cities first, then the account's others.
  @override
  Map<String, Object?> merge(
    Map<String, Object?> here,
    Map<String, Object?> account,
  ) => {
    'zones': <String>{
      ..._zones(here),
      ..._zones(account),
    }.take(WorldCitiesController.limit).toList(),
  };
}

/// The quick timers the user saved, in seconds.
class QuickTimersSection implements SettingsSection {
  QuickTimersSection(this._ref);
  final Ref _ref;

  @override
  String get name => QuickTimersController.settingsName;

  @override
  Map<String, Object?> get fresh => const {'seconds': <int>[]};

  static List<int> _seconds(Map<String, Object?> data) => [
    if (data['seconds'] case final List seconds)
      for (final s in seconds)
        if (s is num && s > 0) s.toInt(),
  ];

  @override
  Future<Map<String, Object?>> read() async => {
    'seconds': [
      for (final d in await _ref.read(quickTimersProvider.future)) d.inSeconds,
    ],
  };

  @override
  Future<void> apply(Map<String, Object?> data) => _ref
      .read(quickTimersProvider.notifier)
      .restore([for (final s in _seconds(data)) Duration(seconds: s)]);

  @override
  Map<String, Object?> merge(
    Map<String, Object?> here,
    Map<String, Object?> account,
  ) => {
    'seconds': (<int>{
      ..._seconds(here),
      ..._seconds(account),
    }.toList()..sort()).take(QuickTimersController.limit).toList(),
  };
}

/// The bedtime schedule: its times, nights, reminder and wake-up alarm.
/// Whether it is on, and Do Not Disturb, stay each phone's own.
class BedtimeSection implements SettingsSection {
  BedtimeSection(this._ref);
  final Ref _ref;

  @override
  String get name => BedtimeController.settingsName;

  @override
  Map<String, Object?> get fresh => const BedtimeSchedule().backup;

  @override
  Future<Map<String, Object?>> read() async =>
      (await _ref.read(bedtimeProvider.future)).backup;

  @override
  Future<void> apply(Map<String, Object?> data) =>
      _ref.read(bedtimeProvider.notifier).restore(data);

  @override
  Map<String, Object?>? merge(
    Map<String, Object?> here,
    Map<String, Object?> account,
  ) => null;
}

/// The holiday calendar and the days ticked or unticked in it. Its days
/// are downloaded again on each phone.
class HolidaysSection implements SettingsSection {
  HolidaysSection(this._ref);
  final Ref _ref;

  @override
  String get name => HolidaysController.settingsName;

  @override
  Map<String, Object?> get fresh => const {
    'feed': null,
    'choices': <String, bool>{},
  };

  @override
  Future<Map<String, Object?>> read() async {
    final s = await _ref.read(holidaysProvider.future);
    return {
      'feed': s.feedId,
      'choices': {
        for (final day in s.choices.keys.toList()..sort()) day: s.choices[day],
      },
    };
  }

  @override
  Future<void> apply(Map<String, Object?> data) => _ref
      .read(holidaysProvider.notifier)
      .restore(
        switch (data['feed']) {
          final String feed => feed,
          _ => null,
        },
        {
          if (data['choices'] case final Map choices)
            for (final MapEntry(:key, :value) in choices.entries)
              if (key is String && value is bool) key: value,
        },
      );

  @override
  Map<String, Object?>? merge(
    Map<String, Object?> here,
    Map<String, Object?> account,
  ) => null;
}

/// Whether the night clock screensaver is dim red.
class NightClockSection implements SettingsSection {
  NightClockSection(this._ref);
  final Ref _ref;

  @override
  String get name => ScreensaverNightController.settingsName;

  @override
  Map<String, Object?> get fresh => const {'dimRed': true};

  @override
  Future<Map<String, Object?>> read() async => {
    'dimRed': await _ref.read(screensaverNightProvider.future),
  };

  @override
  Future<void> apply(Map<String, Object?> data) async {
    if (data['dimRed'] case final bool on) {
      await _ref.read(screensaverNightProvider.future);
      await _ref.read(screensaverNightProvider.notifier).set(on, byHand: false);
    }
  }

  @override
  Map<String, Object?>? merge(
    Map<String, Object?> here,
    Map<String, Object?> account,
  ) => null;
}

/// Every group of settings the account backs up.
final settingsSectionsProvider = Provider<List<SettingsSection>>(
  (ref) => [
    CitiesSection(ref),
    QuickTimersSection(ref),
    BedtimeSection(ref),
    HolidaysSection(ref),
    NightClockSection(ref),
  ],
);

/// The account's copy of the settings while the vault is open; null signed
/// out or locked. Tests override it.
final settingsVaultProvider = FutureProvider<SettingsVault?>((ref) async {
  final open = ref.watch(
    vaultControllerProvider.select((s) => s is VaultUnlocked),
  );
  if (!open) return null;
  final store = await ref.watch(ztLocalStoreProvider.future);
  return StoreSettingsVault(store, ref.read(ztSyncControllerProvider.notifier));
});

/// Backup of the settings; null when there is no open account.
final settingsSyncProvider = FutureProvider<SettingsSync?>((ref) async {
  final vault = await ref.watch(settingsVaultProvider.future);
  if (vault == null) return null;
  return SettingsSync(
    sections: ref.watch(settingsSectionsProvider),
    vault: vault,
    edits: ref.watch(settingsEditsProvider),
  );
});
