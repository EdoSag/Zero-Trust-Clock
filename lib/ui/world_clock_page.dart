import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../world/world_cities.dart';
import '../world/world_zone.dart';
import 'alarm_text.dart';
import 'settings_button.dart';

/// "Tomorrow, 7 h ahead": a city's day and its distance from here.
String zoneDifferenceText(BuildContext context, WorldZone zone, DateTime now) {
  final l = context.l10n;
  final there = zone.timeAt(now);
  final here = DateTime(now.year, now.month, now.day, now.hour, now.minute);
  final days = DateUtils.dateOnly(
    there,
  ).difference(DateUtils.dateOnly(here)).inHours;
  final day = days >= 12
      ? l.tomorrow
      : days <= -12
      ? l.yesterday
      : l.today;
  final diff = zone.offset - now.timeZoneOffset;
  if (diff == Duration.zero) return l.dayAndDifference(day, l.sameTime);
  final abs = diff.abs();
  final h = abs.inHours;
  final m = abs.inMinutes % 60;
  final amount = h == 0
      ? l.minutesShort(m)
      : m == 0
      ? l.hoursOnly(h)
      : l.hoursAndMinutes(h, m);
  return l.dayAndDifference(
    day,
    diff.isNegative ? l.timeBehind(amount) : l.timeAhead(amount),
  );
}

/// The Clock tab: the time here, then the picked cities.
class WorldClockPage extends ConsumerStatefulWidget {
  const WorldClockPage({super.key});

  @override
  ConsumerState<WorldClockPage> createState() => _WorldClockPageState();
}

class _WorldClockPageState extends ConsumerState<WorldClockPage> {
  Timer? _tick;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      // Every ten minutes, the offsets again (daylight saving time).
      if (++_ticks % 120 == 0) ref.invalidate(savedZonesProvider);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _add() async {
    final id = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const CityPickerPage()));
    if (id == null || !mounted) return;
    await ref.read(worldCitiesProvider.notifier).add(id);
  }

  Future<void> _remove(WorldZone zone, int index) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final cities = ref.read(worldCitiesProvider.notifier);
    await cities.remove(zone.id);
    showSnack(
      messenger,
      l.cityRemoved(zone.city),
      actionLabel: l.undo,
      onAction: () => cities.insert(index, zone.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final zones = ref.watch(savedZonesProvider);
    // The picked ids decide what shows, at once (a swipe, Undo, a drag);
    // names and offsets come from the zones as last read.
    final ids = ref.watch(worldCitiesProvider).value ?? const <String>[];
    final known = {
      for (final z in ref.watch(allZonesProvider).value ?? const <WorldZone>[])
        z.id: z,
      for (final z in zones.value ?? const <WorldZone>[]) z.id: z,
    };
    final list = [
      for (final id in ids)
        if (known[id] case final z?) z,
    ];
    final tag = Localizations.localeOf(context).toLanguageTag();
    return Scaffold(
      appBar: AppBar(title: Text(l.clock), actions: const [SettingsButton()]),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addCity',
        tooltip: l.addCity,
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
                child: Column(
                  key: const ValueKey('hereNow'),
                  children: [
                    Text(
                      clockText(context, now),
                      style: theme.textTheme.displayLarge,
                    ),
                    Text(
                      DateFormat.MMMMEEEEd(tag).format(now),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (zones.hasValue && list.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: 48),
                  child: Column(
                    children: [
                      Icon(
                        Icons.public,
                        size: 56,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(l.noCities, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 32,
                        ),
                        child: Text(
                          l.noCitiesHint,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (list.isNotEmpty)
              SliverReorderableList(
                itemCount: list.length,
                onReorderItem: (from, to) =>
                    ref.read(worldCitiesProvider.notifier).move(from, to),
                itemBuilder: (context, i) {
                  final zone = list[i];
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(zone.id),
                    index: i,
                    child: Dismissible(
                      key: ValueKey('dismiss-${zone.id}'),
                      onDismissed: (_) => _remove(zone, i),
                      background: Container(
                        color: theme.colorScheme.errorContainer,
                      ),
                      child: Semantics(
                        customSemanticsActions: {
                          CustomSemanticsAction(label: l.remove): () =>
                              _remove(zone, i),
                        },
                        child: CityRow(zone: zone, now: now),
                      ),
                    ),
                  );
                },
              ),
            if (list.length > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
                  child: Text(
                    l.dragToReorder,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            // Room for the + button.
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}

/// One city: its name, day and distance from here, and its time.
class CityRow extends StatelessWidget {
  const CityRow({super.key, required this.zone, required this.now});

  final WorldZone zone;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        title: Text(zone.city, style: theme.textTheme.titleMedium),
        subtitle: Text(zoneDifferenceText(context, zone, now)),
        trailing: Text(
          clockText(context, zone.timeAt(now)),
          style: theme.textTheme.headlineMedium,
        ),
      ),
    );
  }
}

/// "Add city": search every city Android knows. Pops with its zone id.
class CityPickerPage extends ConsumerStatefulWidget {
  const CityPickerPage({super.key});

  @override
  ConsumerState<CityPickerPage> createState() => _CityPickerPageState();
}

class _CityPickerPageState extends ConsumerState<CityPickerPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(WorldZone z) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return z.city.toLowerCase().contains(q) ||
        z.country.toLowerCase().contains(q) ||
        z.id.toLowerCase().replaceAll('_', ' ').contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final saved = ref.watch(worldCitiesProvider).value ?? const <String>[];
    final all = ref.watch(allZonesProvider);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _search,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l.searchCities,
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: all.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l.couldNotSave)),
        data: (zones) {
          final shown = [...zones.where(_matches)]
            ..sort((a, b) => a.city.compareTo(b.city));
          if (shown.isEmpty) {
            return Center(child: Text(l.noCityFound));
          }
          return ListView.builder(
            itemCount: shown.length,
            itemBuilder: (context, i) {
              final z = shown[i];
              final picked = saved.contains(z.id);
              return ListTile(
                enabled: !picked,
                title: Text(z.city),
                subtitle: z.country.isEmpty ? null : Text(z.country),
                trailing: picked
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : Text(
                        clockText(context, z.timeAt(now)),
                        style: theme.textTheme.titleMedium,
                      ),
                onTap: () => Navigator.of(context).pop(z.id),
              );
            },
          );
        },
      ),
    );
  }
}
