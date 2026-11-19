import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../holidays/holiday_feed.dart';
import '../holidays/holidays.dart';
import '../l10n/l10n.dart';

/// Settings > Public holidays: which holiday calendar, and which of its
/// days alarms with "Skip public holidays" stay silent on.
class HolidaysPage extends ConsumerWidget {
  const HolidaysPage({super.key});

  Future<void> _choose(BuildContext context, WidgetRef ref, String? now) async {
    final l = context.l10n;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.holidayCalendar),
        children: [
          RadioGroup<String>(
            groupValue: now ?? '',
            onChanged: (v) => Navigator.of(context).pop(v),
            child: Column(
              children: [
                RadioListTile<String>(value: '', title: Text(l.noHolidays)),
                for (final c in HolidayCalendar.all)
                  RadioListTile<String>(value: c.feedId, title: Text(c.name)),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;
    await ref
        .read(holidaysProvider.notifier)
        .choose(picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final soft = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final tag = Localizations.localeOf(context).toLanguageTag();
    final s = ref.watch(holidaysProvider).value ?? const HolidaysState();
    final now = DateTime.now();
    final until = dayString(DateTime(now.year + 1, now.month, now.day));
    final days = [
      for (final h in s.upcoming(now))
        if (h.day.compareTo(until) <= 0) h,
    ];
    final calendar = s.calendar;
    return Scaffold(
      appBar: AppBar(title: Text(l.publicHolidays)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.only(bottom: 24),
          children: [
            ListTile(
              key: const ValueKey('holidayCalendar'),
              leading: const Icon(Icons.public),
              title: Text(l.holidayCalendar),
              subtitle: Text(calendar?.name ?? l.noHolidays),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _choose(context, ref, s.feedId),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: Text(l.holidaysPrivacy, style: soft),
            ),
            if (calendar != null) ...[
              ListTile(
                key: const ValueKey('holidayStatus'),
                title: Text(
                  s.loading
                      ? l.holidaysDownloading
                      : s.failed
                      ? l.holidaysFailed
                      : s.fetchedAt == null
                      ? l.holidaysDownloading
                      : l.holidaysUpdated(
                          DateFormat.yMMMd(tag).format(s.fetchedAt!),
                        ),
                ),
                trailing: IconButton(
                  tooltip: l.refresh,
                  onPressed: s.loading
                      ? null
                      : () => ref.read(holidaysProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                ),
              ),
              if (days.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                  child: Text(
                    s.marksPublic ? l.holidaysTickedHint : l.holidaysTickHint,
                    key: const ValueKey('holidayHint'),
                    style: soft,
                  ),
                ),
              for (final h in days)
                CheckboxListTile(
                  key: ValueKey('holiday-${h.day}'),
                  value: s.skips(h),
                  onChanged: (v) => ref
                      .read(holidaysProvider.notifier)
                      .setSkip(h, v ?? false),
                  title: Text(h.name),
                  subtitle: Text(
                    DateFormat.yMMMEd(tag).format(DateTime.parse(h.day)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
