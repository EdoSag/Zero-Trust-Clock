import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_clock/app/clock_gate.dart';
import 'package:zerotrust_clock/engine/bedtime.dart';
import 'package:zerotrust_clock/engine/clock_engine.dart';
import 'package:zerotrust_clock/holidays/holiday_feed.dart';
import 'package:zerotrust_clock/holidays/holidays.dart';
import 'package:zerotrust_clock/sync/settings_sections.dart';
import 'package:zerotrust_clock/sync/settings_sync.dart';
import 'package:zerotrust_clock/timers/quick_timers.dart';
import 'package:zerotrust_clock/ui/clock_home.dart';
import 'package:zerotrust_clock/ui/world_clock_page.dart';
import 'package:zerotrust_clock/world/world_cities.dart';

import 'account_sync_test.dart' show openAccount, settleSync;
import 'alarm_sync_test.dart' show FakeVault;
import 'holidays_test.dart' show feed, fetcher, inDays;
import 'support/app.dart';
import 'support/fake_engine.dart';
import 'timers_test.dart' show frames, tallPhone;

/// The account's copy of the settings, in memory.
class FakeSettingsVault implements SettingsVault {
  final Map<String, SyncedSettings?> items = {};
  final _changes = StreamController<void>.broadcast();
  int writes = 0;

  /// Runs while a save is under way, once (something done meanwhile).
  Future<void> Function()? duringSave;

  @override
  Future<Map<String, SyncedSettings?>> read() async => {...items};

  @override
  Future<void> save(SyncedSettings settings) async {
    final meanwhile = duringSave;
    duringSave = null;
    if (meanwhile != null) await meanwhile();
    writes++;
    expect(settings.id, startsWith('settings-'));
    items[settings.id.substring('settings-'.length)] = settings;
    _changes.add(null);
  }

  @override
  Stream<void> get changes => _changes.stream;

  void put(String name, int at, Map<String, Object?> data) => items[name] =
      SyncedSettings(id: 'settings-$name', editedAt: at, data: data);
}

/// A group of settings held in memory: a list of words.
class WordsSection implements SettingsSection {
  WordsSection({this.merges = false});

  final bool merges;
  List<String> words = [];
  int applied = 0;

  @override
  String get name => 'words';

  @override
  Map<String, Object?> get fresh => const {'words': <String>[]};

  @override
  Future<Map<String, Object?>> read() async => {
    'words': [...words],
  };

  @override
  Future<void> apply(Map<String, Object?> data) async {
    applied++;
    words = [...(data['words'] as List).cast<String>()];
  }

  @override
  Map<String, Object?>? merge(
    Map<String, Object?> here,
    Map<String, Object?> account,
  ) => merges
      ? {
          'words': <String>{
            ...(here['words'] as List).cast<String>(),
            ...(account['words'] as List).cast<String>(),
          }.toList(),
        }
      : null;
}

/// One phone with the in-memory group.
class WordsPhone {
  WordsPhone(
    this.vault, {
    bool merges = false,
    int Function()? clock,
    PreferencesStore? store,
    String accountId = '',
  }) : section = WordsSection(merges: merges),
       prefs = store ?? InMemoryPreferencesStore() {
    edits = SettingsEdits(
      prefs,
      now: () => DateTime.fromMillisecondsSinceEpoch((clock ?? () => 9000)()),
    );
    sync = SettingsSync(
      sections: [section],
      vault: vault,
      edits: edits,
      accountId: accountId,
    );
  }

  final FakeSettingsVault vault;
  final WordsSection section;
  final PreferencesStore prefs;
  late final SettingsEdits edits;
  late final SettingsSync sync;

  /// A change made by hand at [at].
  Future<void> edit(List<String> words, int at) async {
    section.words = words;
    await edits.setEditedAt('words', at);
  }
}

/// One phone with the real settings groups on a fake engine.
class Phone {
  Phone(this.vault, {this.holidayFeed}) {
    container = ProviderContainer(
      overrides: [
        clockEngineProvider.overrideWithValue(engine),
        ztPreferencesStoreProvider.overrideWithValue(prefs),
        settingsVaultProvider.overrideWith((ref) async => vault),
        if (holidayFeed != null)
          holidayFetcherProvider.overrideWithValue(fetcher(holidayFeed!)),
      ],
    );
    addTearDown(container.dispose);
  }

  final FakeSettingsVault vault;
  final String? holidayFeed;
  final engine = FakeClockEngine();
  final prefs = InMemoryPreferencesStore();
  late final ProviderContainer container;

  Future<bool> sync() async =>
      (await container.read(settingsSyncProvider.future))!.run();
}

void main() {
  group('SettingsSync', () {
    test('a new phone takes the account\'s copy', () async {
      final vault = FakeSettingsVault()
        ..put('words', 500, {
          'words': ['a', 'b'],
        });
      final phone = WordsPhone(vault);
      expect(await phone.sync.run(), isTrue);
      expect(phone.section.words, ['a', 'b']);
      expect(vault.writes, 0);
      // Settled: a second round does nothing.
      expect(await phone.sync.run(), isFalse);
      expect(phone.section.applied, 1);
    });

    test('changes made here are sent, and a phone left as it came '
        'sends nothing', () async {
      final vault = FakeSettingsVault();
      final phone = WordsPhone(vault);
      await phone.sync.run();
      expect(vault.items, isEmpty);

      await phone.edit(['a'], 700);
      expect(await phone.sync.run(), isFalse);
      expect(vault.items['words']!.data, {
        'words': ['a'],
      });
      expect(vault.items['words']!.editedAt, 700);
    });

    test('the newer change wins, both ways', () async {
      final vault = FakeSettingsVault();
      final a = WordsPhone(vault);
      final b = WordsPhone(vault);
      await a.edit(['a'], 100);
      await a.sync.run();
      await b.sync.run();
      expect(b.section.words, ['a']);

      // B changes it later; A takes it.
      await b.edit(['a', 'b'], 200);
      await b.sync.run();
      await a.sync.run();
      expect(a.section.words, ['a', 'b']);

      // A removes one after that: it does not come back from B's copy.
      await a.edit(['b'], 300);
      await a.sync.run();
      await b.sync.run();
      expect(b.section.words, ['b']);
      expect(vault.items['words']!.editedAt, 300);

      // An older change still on a phone loses to the account's.
      await b.edit(['old'], 250);
      await b.sync.run();
      expect(b.section.words, ['b']);
    });

    test('a lost account copy never empties the phone', () async {
      final vault = FakeSettingsVault();
      final phone = WordsPhone(vault);
      await phone.edit(['a', 'b'], 100);
      await phone.sync.run();
      vault.items.clear();
      expect(await phone.sync.run(), isFalse);
      expect(phone.section.words, ['a', 'b']);
      expect(vault.items['words']!.data, {
        'words': ['a', 'b'],
      });
    });

    test('first meeting: this phone\'s and the account\'s are both kept, '
        'after that the newer wins', () async {
      var now = 1000;
      final vault = FakeSettingsVault()
        ..put('words', 900, {
          'words': ['tokyo', 'paris'],
        });
      final phone = WordsPhone(vault, merges: true, clock: () => now);
      await phone.edit(['london', 'paris'], 50);
      expect(await phone.sync.run(), isTrue);
      expect(phone.section.words, ['london', 'paris', 'tokyo']);
      expect(vault.items['words']!.data, {
        'words': ['london', 'paris', 'tokyo'],
      });
      expect(vault.items['words']!.editedAt, 1000);

      // Another phone removes Tokyo later. It stays removed here.
      now = 3000;
      vault.put('words', 2000, {
        'words': ['london', 'paris'],
      });
      await phone.sync.run();
      expect(phone.section.words, ['london', 'paris']);
    });

    test('set up before the app kept times: still this phone\'s own', () async {
      // No time recorded, but not as a new install has it.
      final vault = FakeSettingsVault();
      final phone = WordsPhone(vault)..section.words = ['a'];
      await phone.sync.run();
      expect(vault.items['words']!.data, {
        'words': ['a'],
      });
      expect(vault.items['words']!.editedAt, 1);

      // Against an account that has others, with a group that can't keep
      // both, the account's dated change wins.
      final other = FakeSettingsVault()
        ..put('words', 500, {
          'words': ['z'],
        });
      final second = WordsPhone(other)..section.words = ['a'];
      await second.sync.run();
      expect(second.section.words, ['z']);
    });

    test('a group written by a newer app version is left alone', () async {
      final vault = FakeSettingsVault()..items['words'] = null;
      final phone = WordsPhone(vault);
      await phone.edit(['a'], 100);
      expect(await phone.sync.run(), isFalse);
      expect(vault.writes, 0);
      expect(phone.section.words, ['a']);
    });

    test('the same time but different: not sent back', () async {
      final vault = FakeSettingsVault()
        ..put('words', 500, {
          'words': ['a', 'unknown'],
        });
      final phone = WordsPhone(vault);
      await phone.sync.run();
      // This phone keeps only what it knows.
      phone.section.words = ['a'];
      await phone.sync.run();
      await phone.sync.run();
      expect(vault.writes, 0);
      expect(phone.section.applied, 1);
    });

    test('a call during a round runs one more round after it', () async {
      final vault = FakeSettingsVault();
      final phone = WordsPhone(vault);
      await phone.edit(['a'], 100);
      final first = phone.sync.run();
      await phone.edit(['a', 'b'], 200);
      final second = phone.sync.run();
      await Future.wait([first, second]);
      expect(vault.items['words']!.data, {
        'words': ['a', 'b'],
      });
    });
  });

  group('the settings groups between two phones', () {
    test(
      'cities and quick timers arrive in order, also at the widget',
      () async {
        final vault = FakeSettingsVault();
        final a = Phone(vault);
        final b = Phone(vault);
        final cities = a.container.read(worldCitiesProvider.notifier);
        await cities.add('Asia/Tokyo');
        await cities.add('Europe/London');
        await a.container
            .read(quickTimersProvider.notifier)
            .add(const Duration(minutes: 45));
        await a.sync();
        expect(vault.items.keys, containsAll(['cities', 'quick-timers']));
        // Only what was changed is sent.
        expect(vault.items.keys, isNot(contains('bedtime')));
        expect(vault.items.keys, isNot(contains('night-clock')));

        expect(await b.sync(), isTrue);
        expect(await b.container.read(worldCitiesProvider.future), [
          'Asia/Tokyo',
          'Europe/London',
        ]);
        expect(b.engine.widgetCities, ['Asia/Tokyo', 'Europe/London']);
        expect(await b.prefs.read('clock_world_cities'), isNotNull);
        expect(await b.container.read(quickTimersProvider.future), [
          const Duration(minutes: 45),
        ]);

        // Reordered on B: A follows.
        await b.container.read(worldCitiesProvider.notifier).move(1, 0);
        await b.sync();
        await a.sync();
        expect(await a.container.read(worldCitiesProvider.future), [
          'Europe/London',
          'Asia/Tokyo',
        ]);
      },
    );

    test(
      'a phone with its own cities keeps them next to the account\'s',
      () async {
        final vault = FakeSettingsVault();
        final a = Phone(vault);
        final b = Phone(vault);
        await a.container.read(worldCitiesProvider.notifier).add('Asia/Tokyo');
        await a.sync();
        await b.container
            .read(worldCitiesProvider.notifier)
            .add('America/New_York');
        await b.sync();
        expect(await b.container.read(worldCitiesProvider.future), [
          'America/New_York',
          'Asia/Tokyo',
        ]);
        await a.sync();
        expect(await a.container.read(worldCitiesProvider.future), [
          'America/New_York',
          'Asia/Tokyo',
        ]);
      },
    );

    test(
      'bedtime: the times arrive, the switches stay each phone\'s own',
      () async {
        final vault = FakeSettingsVault();
        final a = Phone(vault);
        final b = Phone(vault);
        await a.container.read(bedtimeProvider.future);
        await a.container
            .read(bedtimeProvider.notifier)
            .save(
              const BedtimeSchedule(
                enabled: true,
                doNotDisturb: true,
                bedHour: 22,
                bedMinute: 30,
                wakeHour: 6,
                wakeMinute: 15,
                nights: {7, 1, 2, 3, 4},
                reminderMinutes: 30,
                wakeAlarmId: 'wake',
              ),
            );
        await a.sync();
        expect(vault.items['bedtime']!.data.keys, isNot(contains('enabled')));
        expect(
          vault.items['bedtime']!.data.keys,
          isNot(contains('doNotDisturb')),
        );

        await b.sync();
        final s = b.engine.schedule;
        expect(
          [s.bedHour, s.bedMinute, s.wakeHour, s.wakeMinute],
          [22, 30, 6, 15],
        );
        expect(s.nights, {7, 1, 2, 3, 4});
        expect(s.reminderMinutes, 30);
        expect(s.wakeAlarmId, 'wake');
        // Off, and no Do Not Disturb, until switched on here.
        expect(s.enabled, isFalse);
        expect(s.doNotDisturb, isFalse);
        expect((await b.container.read(bedtimeProvider.future)).bedHour, 22);

        // Switching it on here is this phone's own: nothing to send.
        final writes = vault.writes;
        await b.container
            .read(bedtimeProvider.notifier)
            .save(s.copyWith(enabled: true));
        await b.sync();
        expect(vault.writes, writes);
        await a.sync();
        expect(a.engine.schedule.enabled, isTrue);
        expect(a.engine.schedule.doNotDisturb, isTrue);
      },
    );

    test('the holiday calendar and its ticks arrive, and it is downloaded '
        'there', () async {
      final vault = FakeSettingsVault();
      final a = Phone(vault, holidayFeed: feed());
      final b = Phone(vault, holidayFeed: feed());
      final holidays = a.container.read(holidaysProvider.notifier);
      await holidays.choose('en.jewish');
      final first = (await a.container.read(
        holidaysProvider.future,
      )).items.firstWhere((h) => h.day == dayString(inDays(11)));
      await holidays.setSkip(first, false);
      await a.sync();
      expect(vault.items['holidays']!.data, {
        'feed': 'en.jewish',
        'choices': {dayString(inDays(11)): false},
      });

      await b.sync();
      final there = await b.container.read(holidaysProvider.future);
      expect(there.feedId, 'en.jewish');
      expect(there.items, isNotEmpty);
      expect(there.choices, {dayString(inDays(11)): false});
      expect(b.engine.holidayDays, [dayString(inDays(10))]);

      // "None" on B reaches A.
      await b.container.read(holidaysProvider.notifier).choose(null);
      await b.sync();
      await a.sync();
      expect((await a.container.read(holidaysProvider.future)).feedId, isNull);
      expect(a.engine.holidayDays, isEmpty);
    });

    test('the night clock\'s dim red arrives', () async {
      final vault = FakeSettingsVault();
      final a = Phone(vault);
      final b = Phone(vault);
      await a.container.read(screensaverNightProvider.future);
      await a.container.read(screensaverNightProvider.notifier).set(false);
      await a.sync();
      await b.sync();
      expect(b.engine.night, isFalse);
      expect(await b.container.read(screensaverNightProvider.future), isFalse);
    });

    test('a broken copy in the account does no harm', () async {
      final vault = FakeSettingsVault()
        ..put('cities', 100, {'zones': 'Tokyo'})
        ..put('quick-timers', 100, {
          'seconds': [-5, 'x', 60, 2700],
        })
        ..put('bedtime', 100, {'bedHour': 99, 'nights': 'all'})
        ..put('holidays', 100, {'feed': 'no.such.calendar', 'choices': 3})
        ..put('night-clock', 100, {'dimRed': 'yes'});
      final phone = Phone(vault);
      await phone.sync();
      expect(await phone.container.read(worldCitiesProvider.future), isEmpty);
      // A minute is a quick timer everyone has already.
      expect(await phone.container.read(quickTimersProvider.future), [
        const Duration(minutes: 45),
      ]);
      expect(phone.engine.schedule.bedHour, 23);
      expect(phone.engine.schedule.nights, hasLength(7));
      expect(
        (await phone.container.read(holidaysProvider.future)).feedId,
        isNull,
      );
      expect(phone.engine.night, isTrue);
    });
  });

  testWidgets('signed in: the account\'s cities show on the Clock tab, and a '
      'city added here is backed up', (tester) async {
    tallPhone(tester);
    final settings = FakeSettingsVault()
      ..put('cities', 100, {
        'zones': ['Europe/London', 'Asia/Tokyo'],
      });
    final engine = FakeClockEngine();
    await tester.pumpWidget(
      testApp(
        engine,
        home: const ClockGate(home: ClockHome()),
        overrides: [
          ...openAccount(FakeVault()),
          settingsVaultProvider.overrideWith((ref) async => settings),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await settleSync(tester);
    await tester.tap(find.text('Clock'));
    await frames(tester);

    // In the account's order.
    final london = tester.getRect(
      find.ancestor(of: find.text('London'), matching: find.byType(CityRow)),
    );
    final tokyo = tester.getRect(
      find.ancestor(of: find.text('Tokyo'), matching: find.byType(CityRow)),
    );
    expect(london.bottom, lessThanOrEqualTo(tokyo.top));

    await tester.tap(find.byTooltip('Add city'));
    await frames(tester);
    await tester.enterText(find.byType(TextField), 'kol');
    await frames(tester);
    await tester.tap(find.text('Kolkata'));
    await frames(tester);
    await tester.pump(const Duration(seconds: 1));
    await frames(tester);
    expect(settings.items['cities']!.data, {
      'zones': ['Europe/London', 'Asia/Tokyo', 'Asia/Kolkata'],
    });
  });
}
