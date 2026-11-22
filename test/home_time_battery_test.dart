import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_clock/engine/alarm.dart';
import 'package:zerotrust_clock/engine/clock_engine.dart';
import 'package:zerotrust_clock/sync/settings_sections.dart';
import 'package:zerotrust_clock/ui/alarm_check_page.dart';
import 'package:zerotrust_clock/ui/settings_page.dart';
import 'package:zerotrust_clock/ui/world_clock_page.dart';
import 'package:zerotrust_clock/world/world_cities.dart';

import 'settings_sync_test.dart' show FakeSettingsVault;
import 'support/app.dart';
import 'support/fake_engine.dart';
import 'timers_test.dart' show frames, tallPhone;
import 'world_clock_test.dart' show away;

/// A fake engine whose cities include home, [diff] from this machine's
/// own time zone, and one more city.
FakeClockEngine engineWith(Duration diff) => FakeClockEngine()
  ..zoneList = [
    ...FakeClockEngine().zoneList,
    away(diff, city: 'Hometown'),
    away(const Duration(hours: 3), city: 'Elsewhere'),
  ];

Future<InMemoryPreferencesStore> homeAt(String id) async {
  final prefs = InMemoryPreferencesStore();
  await prefs.write('clock_home_zone', id);
  return prefs;
}

void tallSettings(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('home time', () {
    testWidgets('away: home shows between the time here and the cities', (
      tester,
    ) async {
      tallPhone(tester);
      final engine = engineWith(const Duration(hours: -7));
      final prefs = await homeAt('Test/Hometown');
      await prefs.write('clock_world_cities', '["Test/Elsewhere"]');
      await tester.pumpWidget(
        testApp(engine, home: const WorldClockPage(), prefs: prefs),
      );
      await frames(tester);

      final home = find.byKey(const ValueKey('homeTime'));
      expect(home, findsOneWidget);
      expect(
        find.descendant(of: home, matching: find.text('Home: Hometown')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: home, matching: find.textContaining('7 h behind')),
        findsOneWidget,
      );
      // Under the time here, above the first city.
      final here = tester.getRect(find.byKey(const ValueKey('hereNow')));
      final city = tester.getRect(find.byType(CityRow));
      final box = tester.getRect(home);
      expect(box.top, greaterThanOrEqualTo(here.bottom));
      expect(box.bottom, lessThanOrEqualTo(city.top));
      // The house first, the name, and the time at the end of the row.
      final icon = tester.getRect(
        find.descendant(of: home, matching: find.byIcon(Icons.home_outlined)),
      );
      final name = tester.getRect(find.text('Home: Hometown'));
      final time = tester.getRect(
        find.descendant(
          of: home,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Text && RegExp(r'^\d{1,2}:\d{2}').hasMatch(w.data ?? ''),
          ),
        ),
      );
      expect(icon.right, lessThanOrEqualTo(name.left));
      expect(time.left, greaterThan(name.right));
      expect(time.right, lessThanOrEqualTo(box.right));
    });

    testWidgets('at home, or with no home picked, nothing is added', (
      tester,
    ) async {
      tallPhone(tester);
      // Home is the time zone the phone is in.
      final engine = engineWith(Duration.zero);
      await tester.pumpWidget(
        testApp(
          engine,
          home: const WorldClockPage(),
          prefs: await homeAt('Test/Hometown'),
        ),
      );
      await frames(tester);
      expect(find.byKey(const ValueKey('homeTime')), findsNothing);
      expect(find.text('No cities yet'), findsOneWidget);

      // Away, but no home picked.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        testApp(
          engineWith(const Duration(hours: 5)),
          home: const WorldClockPage(),
        ),
      );
      await frames(tester);
      expect(find.byKey(const ValueKey('homeTime')), findsNothing);
    });

    testWidgets('in Hebrew the house is on the right, the time on the left', (
      tester,
    ) async {
      tallPhone(tester);
      await tester.pumpWidget(
        testApp(
          engineWith(const Duration(hours: 2)),
          home: const WorldClockPage(),
          prefs: await homeAt('Test/Hometown'),
          locale: hebrew,
        ),
      );
      await frames(tester);
      final home = find.byKey(const ValueKey('homeTime'));
      final name = tester.getRect(find.text('בבית: Hometown'));
      final icon = tester.getRect(
        find.descendant(of: home, matching: find.byIcon(Icons.home_outlined)),
      );
      final time = tester.getRect(
        find.descendant(
          of: home,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Text && RegExp(r'^\d{1,2}:\d{2}').hasMatch(w.data ?? ''),
          ),
        ),
      );
      expect(icon.left, greaterThanOrEqualTo(name.right));
      expect(time.right, lessThan(name.left));
    });

    testWidgets('Settings: this phone\'s zone, any city, or off', (
      tester,
    ) async {
      tallSettings(tester);
      final engine = engineWith(const Duration(hours: -7))
        ..phoneZone = 'Europe/London';
      final prefs = InMemoryPreferencesStore();
      await tester.pumpWidget(
        testApp(engine, home: const ClockSettingsPage(), prefs: prefs),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('homeZone'));
      expect(
        find.descendant(of: row, matching: find.text('Home time zone')),
        findsOneWidget,
      );
      expect(find.descendant(of: row, matching: find.text('Off')), findsOne);
      // Under "Ring at least this loud".
      expect(
        tester.getRect(row).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey('minVolume'))).bottom,
        ),
      );

      // Nothing picked yet: no "Off" to choose.
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('homeOff')), findsNothing);
      final here = find.byKey(const ValueKey('homeHere'));
      final pick = find.byKey(const ValueKey('homePick'));
      expect(
        find.descendant(
          of: here,
          matching: find.text("This phone's time zone now (London)"),
        ),
        findsOneWidget,
      );
      // One under the other.
      expect(
        tester.getRect(pick).top,
        greaterThanOrEqualTo(tester.getRect(here).bottom),
      );
      await tester.tap(here);
      await tester.pumpAndSettle();
      expect(await prefs.read('clock_home_zone'), 'Europe/London');
      expect(
        find.descendant(of: row, matching: find.textContaining('London. ')),
        findsOneWidget,
      );

      // Any city, also one the world clock could already have.
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('homePick')));
      await tester.pumpAndSettle();
      expect(find.byType(CityPickerPage), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'home');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hometown'));
      await tester.pumpAndSettle();
      expect(find.byType(CityPickerPage), findsNothing);
      expect(await prefs.read('clock_home_zone'), 'Test/Hometown');
      expect(
        find.descendant(of: row, matching: find.textContaining('Hometown. ')),
        findsOneWidget,
      );

      // Off again: last in the sheet.
      await tester.tap(row);
      await tester.pumpAndSettle();
      final off = find.byKey(const ValueKey('homeOff'));
      expect(
        tester.getRect(off).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey('homePick'))).bottom,
        ),
      );
      await tester.tap(off);
      await tester.pumpAndSettle();
      expect(await prefs.read('clock_home_zone'), '');
      expect(find.descendant(of: row, matching: find.text('Off')), findsOne);
    });

    testWidgets('a city of the world clock can still be picked as home', (
      tester,
    ) async {
      tallPhone(tester);
      final prefs = InMemoryPreferencesStore();
      await prefs.write('clock_world_cities', '["Asia/Tokyo"]');
      await tester.pumpWidget(
        testApp(
          FakeClockEngine(),
          home: const CityPickerPage(forHome: true),
          prefs: prefs,
        ),
      );
      await frames(tester);
      final tokyo = tester.widget<ListTile>(
        find.ancestor(of: find.text('Tokyo'), matching: find.byType(ListTile)),
      );
      expect(tokyo.enabled, isTrue);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    test('home is backed up, and arrives on the other phone', () async {
      Future<ProviderContainer> phone(FakeSettingsVault vault) async {
        final container = ProviderContainer(
          overrides: [
            clockEngineProvider.overrideWithValue(FakeClockEngine()),
            ztPreferencesStoreProvider.overrideWithValue(
              InMemoryPreferencesStore(),
            ),
            settingsVaultProvider.overrideWith((ref) async => vault),
          ],
        );
        addTearDown(container.dispose);
        return container;
      }

      Future<void> sync(ProviderContainer c) async =>
          (await c.read(settingsSyncProvider.future))!.run();

      final vault = FakeSettingsVault();
      final a = await phone(vault);
      final b = await phone(vault);
      await a.read(homeZoneProvider.future);
      await a.read(homeZoneProvider.notifier).set('Asia/Tokyo');
      await sync(a);
      expect(vault.items['home']!.data, {'zone': 'Asia/Tokyo'});
      await sync(b);
      expect(await b.read(homeZoneProvider.future), 'Asia/Tokyo');
      expect((await b.read(homeZoneInfoProvider.future))?.city, 'Tokyo');
      // Taking it from the account is not a change to send back.
      final writes = vault.writes;
      await sync(b);
      expect(vault.writes, writes);

      // Switched off on the second phone: off on the first too.
      await b.read(homeZoneProvider.notifier).set(null);
      await sync(b);
      expect(vault.items['home']!.data, {'zone': null});
      await sync(a);
      expect(await a.read(homeZoneProvider.future), isNull);
      // A broken copy switches it off instead of crashing.
      await a.read(homeZoneProvider.notifier).set('Asia/Tokyo', byHand: false);
      await HomeSection(a.read(Provider((ref) => ref))).apply({'zone': 42});
      expect(await a.read(homeZoneProvider.future), isNull);
    });
  });

  group('battery hints', () {
    test('only the makers that stop closed apps get one', () {
      BatteryBrand? brand(String maker) =>
          AlarmCheck(maker: maker).batteryBrand;
      expect(brand('xiaomi redmi'), BatteryBrand.xiaomi);
      expect(brand('xiaomi poco'), BatteryBrand.xiaomi);
      expect(brand('huawei huawei'), BatteryBrand.huawei);
      expect(brand('honor honor'), BatteryBrand.huawei);
      expect(brand('samsung samsung'), BatteryBrand.samsung);
      expect(brand('google google'), isNull);
      expect(brand(''), isNull);
      expect(
        AlarmCheck.fromMap(const {'maker': 'samsung samsung'}).batteryBrand,
        BatteryBrand.samsung,
      );
      // Advice, not a problem: the count stays as it was.
      expect(const AlarmCheck(maker: 'samsung samsung').problems, 0);
    });

    testWidgets('a Samsung phone: the hint sits above "After a restart"', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final engine = FakeClockEngine(
        checkResult: const AlarmCheck(maker: 'samsung samsung'),
      );
      await tester.pumpWidget(testApp(engine, home: const AlarmCheckPage()));
      await tester.pumpAndSettle();
      final hint = find.byKey(const ValueKey('batteryHint'));
      expect(hint, findsOneWidget);
      expect(
        find.descendant(of: hint, matching: find.text('Samsung phones')),
        findsOneWidget,
      );
      expect(find.textContaining('Never sleeping'), findsNothing);
      expect(find.textContaining('pick Unrestricted'), findsOneWidget);
      // Still "Everything looks right": it is advice.
      expect(find.text('Everything looks right'), findsOneWidget);
      final box = tester.getRect(hint);
      expect(
        box.top,
        greaterThanOrEqualTo(tester.getRect(find.text('Main profile')).bottom),
      );
      expect(
        box.bottom,
        lessThanOrEqualTo(tester.getRect(find.text('After a restart')).top),
      );
      // The button is at the end of the row, beside the text, inside it.
      final open = tester.getRect(
        find.descendant(of: hint, matching: find.text('Open')),
      );
      final text = tester.getRect(find.textContaining('pick Unrestricted'));
      expect(open.left, greaterThanOrEqualTo(text.right));
      expect(open.right, lessThanOrEqualTo(box.right));
      expect(open.top, greaterThanOrEqualTo(box.top));
      expect(open.bottom, lessThanOrEqualTo(box.bottom));

      await tester.tap(find.descendant(of: hint, matching: find.text('Open')));
      await tester.pumpAndSettle();
      expect(engine.calls.last, 'openSettings app');
    });

    testWidgets('Xiaomi and Huawei get their own words; a Pixel gets none', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<void> open(String maker) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          testApp(
            FakeClockEngine(checkResult: AlarmCheck(maker: maker)),
            home: const AlarmCheckPage(),
          ),
        );
        await tester.pumpAndSettle();
      }

      await open('xiaomi redmi');
      expect(find.text('Xiaomi, Redmi and POCO phones'), findsOneWidget);
      expect(find.textContaining('Autostart'), findsOneWidget);
      await open('huawei honor');
      expect(find.text('Huawei and Honor phones'), findsOneWidget);
      expect(find.textContaining('App launch'), findsOneWidget);
      await open('google google');
      expect(find.byKey(const ValueKey('batteryHint')), findsNothing);
    });

    testWidgets('Hebrew, small phone, large text: no overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testApp(
          FakeClockEngine(checkResult: const AlarmCheck(maker: 'xiaomi poco')),
          home: const AlarmCheckPage(),
          locale: hebrew,
          textScale: 1.5,
        ),
      );
      await tester.pumpAndSettle();
      final hint = find.byKey(const ValueKey('batteryHint'));
      await tester.ensureVisible(hint);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('טלפונים של Xiaomi, Redmi ו-POCO'), findsOneWidget);
      // Right to left: the button is at the left end.
      final open = tester.getRect(
        find.descendant(of: hint, matching: find.text('פתיחה')),
      );
      expect(open.center.dx, lessThan(tester.getRect(hint).center.dx));
    });
  });
}
