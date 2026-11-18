import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../engine/alarm.dart';
import '../l10n/l10n.dart';

/// The words the alarm screens share: times, days and "rings in".

String _tag(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();

/// A time of day the way the phone writes it (12 or 24 hours).
String timeOfDayText(BuildContext context, int hour, int minute) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: hour, minute: minute),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

String clockText(BuildContext context, DateTime at) =>
    timeOfDayText(context, at.hour, at.minute);

/// "Today", "Tomorrow", or the date ("Thu, Nov 19").
String dayText(BuildContext context, DateTime at, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final days = DateUtils.dateOnly(at).difference(today).inHours / 24;
  if (days.round() == 0) return context.l10n.today;
  if (days.round() == 1) return context.l10n.tomorrow;
  return DateFormat.MMMEd(_tag(context)).format(at);
}

/// The seven days in the order this language starts its week, as ISO
/// numbers (1 = Monday .. 7 = Sunday).
List<int> weekOrder(BuildContext context) {
  // 0 = Sunday .. 6 = Saturday.
  final first = MaterialLocalizations.of(context).firstDayOfWeekIndex;
  return [
    for (var i = 0; i < 7; i++) (first + i) % 7 == 0 ? 7 : (first + i) % 7,
  ];
}

// 1 January 2024 was a Monday.
DateTime _sample(int isoDay) => DateTime(2024, 1, isoDay);

/// "Mon". Hebrew names its days by letter ("א׳" for Sunday), which is
/// what people there read on a calendar; its longer short form is "יום א׳".
String shortDayName(BuildContext context, int isoDay) {
  final tag = _tag(context);
  final format = Localizations.localeOf(context).languageCode == 'he'
      ? DateFormat.EEEEE(tag)
      : DateFormat.E(tag);
  return format.format(_sample(isoDay));
}

/// "Monday".
String fullDayName(BuildContext context, int isoDay) =>
    DateFormat.EEEE(_tag(context)).format(_sample(isoDay));

/// When an alarm rings: "Every day", "Sun, Mon, Tue", or for one that
/// rings once the day it rings ("Tomorrow").
String repeatText(BuildContext context, ClockAlarm alarm, {DateTime? now}) {
  final l = context.l10n;
  if (alarm.days.length == 7) return l.everyDay;
  if (alarm.repeats) {
    return [
      for (final day in weekOrder(context))
        if (alarm.days.contains(day)) shortDayName(context, day),
    ].join(', ');
  }
  final next = alarm.nextRing;
  return alarm.enabled && next != null
      ? dayText(context, next, now: now)
      : l.once;
}

/// "Rings in 7 h 30 min", rounded up to the minute.
String ringsInText(AppL10n l, Duration until) {
  if (until < const Duration(minutes: 1)) return l.ringsInUnderMinute;
  final minutes = (until.inSeconds / 60).ceil();
  if (minutes < 60) return l.ringsInMinutes(minutes);
  if (minutes < 24 * 60) return l.ringsInHours(minutes ~/ 60, minutes % 60);
  return l.ringsInDays(minutes ~/ (24 * 60), (minutes % (24 * 60)) ~/ 60);
}

/// A short message at the bottom. With an action it stays 6 seconds
/// (Flutter keeps a snackbar with an action open forever otherwise).
void showSnack(
  ScaffoldMessengerState messenger,
  String text, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        duration: Duration(seconds: actionLabel == null ? 4 : 6),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
}
