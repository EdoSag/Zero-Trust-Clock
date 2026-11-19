// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ZT Clock';

  @override
  String get alarms => 'Alarms';

  @override
  String get settings => 'Settings';

  @override
  String get addAlarm => 'Add alarm';

  @override
  String get noAlarms => 'No alarms yet';

  @override
  String get noAlarmsHint => 'Tap + to set one.';

  @override
  String get everyDay => 'Every day';

  @override
  String get once => 'Once';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get turnOffOnce => 'Turn off once';

  @override
  String get turnBackOn => 'Turn back on';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get moreOptions => 'More options';

  @override
  String offOnceNext(String day) {
    return 'Off once. Next: $day';
  }

  @override
  String get offOnce => 'Off once';

  @override
  String get undo => 'Undo';

  @override
  String get alarmOff => 'Alarm off';

  @override
  String get justOnce => 'Just once';

  @override
  String get alarmDeleted => 'Alarm deleted';

  @override
  String snoozedUntil(String time) {
    return 'Snoozed until $time';
  }

  @override
  String get dismiss => 'Dismiss';

  @override
  String get snooze => 'Snooze';

  @override
  String get ringingNow => 'Ringing now';

  @override
  String ringsInDays(int days, int hours) {
    return 'Rings in $days d $hours h';
  }

  @override
  String ringsInHours(int hours, int minutes) {
    return 'Rings in $hours h $minutes min';
  }

  @override
  String ringsInMinutes(int minutes) {
    return 'Rings in $minutes min';
  }

  @override
  String get ringsInUnderMinute => 'Rings in less than a minute';

  @override
  String get mayNotRing => 'Alarms may not ring';

  @override
  String mayNotRingHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things on this phone need attention.',
      one: '1 thing on this phone needs attention.',
    );
    return '$_temp0';
  }

  @override
  String get openAlarmCheck => 'Open Alarm check';

  @override
  String get editAlarm => 'Edit alarm';

  @override
  String get changeTime => 'Change time';

  @override
  String get repeat => 'Repeat';

  @override
  String get ringsOnce => 'No day picked: the alarm rings once.';

  @override
  String get label => 'Label';

  @override
  String get labelHelper => 'Not shown while the phone is locked.';

  @override
  String get vibrate => 'Vibrate';

  @override
  String get snoozeLength => 'Snooze length';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get save => 'Save';

  @override
  String get couldNotSave => 'That did not work. Try again.';

  @override
  String get alarmCheck => 'Alarm check';

  @override
  String get alarmCheckSubtitle => 'What can stop an alarm on this phone';

  @override
  String get alarmCheckIntro =>
      'Each line is something that can stop an alarm on this phone. Fix what is marked, then try a test alarm.';

  @override
  String get allGood => 'Everything looks right';

  @override
  String get fix => 'Fix';

  @override
  String get checkNotifications => 'Notifications';

  @override
  String get checkNotificationsOk => 'On';

  @override
  String get checkNotificationsBad =>
      'Off. A ringing alarm cannot show on screen.';

  @override
  String get checkRingChannel => '\"Ringing alarms\" notifications';

  @override
  String get checkRingChannelOk => 'Normal';

  @override
  String get checkRingChannelBad =>
      'Turned down or off. The alarm screen may not open.';

  @override
  String get checkFullScreen => 'Alarm screen over the lock screen';

  @override
  String get checkFullScreenOk => 'Allowed';

  @override
  String get checkFullScreenBad =>
      'Not allowed. You would only get a notification.';

  @override
  String get checkExact => 'Exact alarms';

  @override
  String get checkExactOk => 'Allowed';

  @override
  String get checkExactBad => 'Not allowed. Alarms could ring late.';

  @override
  String get checkVolume => 'Alarm volume';

  @override
  String checkVolumeOk(int level, int max) {
    return '$level of $max';
  }

  @override
  String get checkVolumeBad => 'At zero. Alarms only vibrate.';

  @override
  String get checkSilence => 'Do Not Disturb';

  @override
  String get checkSilenceOk => 'Alarms can ring';

  @override
  String get checkSilenceBad => 'Total silence is on. It mutes alarms.';

  @override
  String get checkProfile => 'Phone profile';

  @override
  String get checkProfileOk => 'Main profile';

  @override
  String get checkProfileBad =>
      'Secondary profile. When this profile is ended, its alarms do not ring.';

  @override
  String get checkRestart => 'After a restart';

  @override
  String get checkRestartNever =>
      'No restart seen since the app was installed.';

  @override
  String checkRestartLocked(String when) {
    return 'Alarms were set again on $when, before the phone was unlocked.';
  }

  @override
  String checkRestartUnlocked(String when) {
    return 'Alarms were set again on $when, after the phone was unlocked.';
  }

  @override
  String get tryIt => 'Try it';

  @override
  String get testIn10 => 'Test alarm in 10 seconds';

  @override
  String get testIn10Hint =>
      'Rings like a real alarm. Lock the phone first to see the alarm screen.';

  @override
  String get testStarted => 'Test alarm rings in 10 seconds.';

  @override
  String get restartTest => 'Restart test';

  @override
  String get restartTestHint =>
      'Sets a test alarm 3 minutes from now. Restart the phone and leave it locked. The alarm should still ring.';

  @override
  String get restartTestStarted =>
      'Test alarm rings in 3 minutes. Restart the phone now and do not unlock it.';

  @override
  String alarmsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count alarms from your account were added. They stay off on this phone until you switch them on.',
      one:
          '1 alarm from your account was added. It stays off on this phone until you switch it on.',
    );
    return '$_temp0';
  }

  @override
  String get date => 'Date';

  @override
  String get sound => 'Sound';

  @override
  String get soundChime => 'ZT chime';

  @override
  String get soundSystem => 'The phone\'s alarm sound';

  @override
  String get soundRingtone => 'Choose a phone sound';

  @override
  String get soundFile => 'Choose an audio file';

  @override
  String get soundPicked => 'Picked sound';

  @override
  String get soundHint =>
      'A sound you choose is copied into the app, so it also plays before the phone is first unlocked. If it can\'t play, the ZT chime rings instead.';

  @override
  String get gradual => 'Gradually louder';

  @override
  String get gradualHint =>
      'Starts quietly and reaches full volume in a minute';

  @override
  String get silenceAfter => 'Silence after';

  @override
  String get pauseUntil => 'Pause until…';

  @override
  String get pauseUntilHelp => 'Silent through this day';

  @override
  String pausedUntil(String day) {
    return 'Paused until $day';
  }

  @override
  String get resume => 'Resume';

  @override
  String get pauseAll => 'Pause all alarms until…';

  @override
  String get resumeAll => 'Resume all alarms';

  @override
  String pausedAllUntil(String day) {
    return 'Repeating alarms are paused through $day. Alarms set for one day still ring.';
  }

  @override
  String get timers => 'Timers';

  @override
  String get stopwatch => 'Stopwatch';

  @override
  String get addTimer => 'Add timer';

  @override
  String get start => 'Start';

  @override
  String get pause => 'Pause';

  @override
  String get reset => 'Reset';

  @override
  String get addMinute => '+1:00';

  @override
  String get stop => 'Stop';

  @override
  String get timesUp => 'Time\'s up';

  @override
  String timerOf(String length) {
    return '$length timer';
  }

  @override
  String get timerPaused => 'Paused';

  @override
  String get timerLabel => 'Timer label';

  @override
  String get deleteTimer => 'Delete timer';

  @override
  String get cancel => 'Cancel';

  @override
  String get quickTimers => 'Quick timers';

  @override
  String get saveQuickTimer => 'Save as a quick timer';

  @override
  String get quickTimerSaved => 'Saved as a quick timer';

  @override
  String get quickTimerRemoved => 'Quick timer removed';

  @override
  String get quickTimersHint =>
      'Tap one to start it. Remove one you saved with its ×.';

  @override
  String get hoursUnit => 'h';

  @override
  String get minutesUnit => 'm';

  @override
  String get secondsUnit => 's';

  @override
  String get deleteDigit => 'Delete digit';

  @override
  String get lap => 'Lap';

  @override
  String lapNumber(int number) {
    return 'Lap $number';
  }

  @override
  String get copyLaps => 'Copy laps';

  @override
  String get lapsCopied => 'Laps copied';

  @override
  String get timerStarted => 'Timer started';

  @override
  String get clock => 'Clock';

  @override
  String get addCity => 'Add city';

  @override
  String get searchCities => 'Search cities or countries';

  @override
  String get noCities => 'No cities yet';

  @override
  String get noCitiesHint => 'Add a city to see its time next to yours.';

  @override
  String cityRemoved(String city) {
    return '$city removed';
  }

  @override
  String get remove => 'Remove';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get sameTime => 'Same time';

  @override
  String timeAhead(String time) {
    return '$time ahead';
  }

  @override
  String timeBehind(String time) {
    return '$time behind';
  }

  @override
  String hoursOnly(int hours) {
    return '$hours h';
  }

  @override
  String hoursAndMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String dayAndDifference(String day, String difference) {
    return '$day, $difference';
  }

  @override
  String get noCityFound => 'No city found';

  @override
  String get dragToReorder => 'Long-press to reorder, swipe to remove.';
}
