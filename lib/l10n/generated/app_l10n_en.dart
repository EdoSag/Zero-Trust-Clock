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
  String get batteryXiaomi => 'Xiaomi, Redmi and POCO phones';

  @override
  String get batteryXiaomiHint =>
      'These phones can stop an app that is closed, and its alarms with it. In the app\'s settings turn on Autostart, and set Battery saver to No restrictions.';

  @override
  String get batteryHuawei => 'Huawei and Honor phones';

  @override
  String get batteryHuaweiHint =>
      'These phones close apps to save battery. In Settings > Battery > App launch, switch ZT Clock to Manage manually and leave Auto-launch and Run in background on.';

  @override
  String get batterySamsung => 'Samsung phones';

  @override
  String get batterySamsungHint =>
      'Samsung puts apps you rarely open to sleep, and a sleeping app\'s alarms can be late. In the app\'s settings open Battery and pick Unrestricted, and keep ZT Clock out of Sleeping apps.';

  @override
  String get openAppSettings => 'Open';

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

  @override
  String homeIn(String city) {
    return 'Home: $city';
  }

  @override
  String get homeTimeZone => 'Home time zone';

  @override
  String get homeTimeZoneOff => 'Off';

  @override
  String homeTimeZoneOn(String city) {
    return '$city. Its time shows in the Clock tab while the phone is in another time zone.';
  }

  @override
  String homeHere(String city) {
    return 'This phone\'s time zone now ($city)';
  }

  @override
  String get homePickCity => 'Pick a city';

  @override
  String get homeTimeZoneAbout =>
      'When you travel and the phone changes time zone, the Clock tab also shows the time at home. At home nothing is added.';

  @override
  String get bedtime => 'Bedtime';

  @override
  String get bedtimeSchedule => 'Bedtime schedule';

  @override
  String get bedtimeScheduleHint =>
      'A reminder before bed, and quiet through the night.';

  @override
  String get bedtimeStart => 'Bedtime';

  @override
  String get wakeUp => 'Wake up';

  @override
  String sleepFor(String length) {
    return '$length of sleep';
  }

  @override
  String get nights => 'Nights';

  @override
  String get reminder => 'Reminder';

  @override
  String get off => 'Off';

  @override
  String get doNotDisturbAtBedtime => 'Do Not Disturb at bedtime';

  @override
  String get doNotDisturbHint =>
      'Silences calls and notifications through the night. Alarms still ring.';

  @override
  String get dndNeedsAccess =>
      'Needs Do Not Disturb access in Android\'s settings.';

  @override
  String get allow => 'Allow';

  @override
  String get wakeUpAlarm => 'Wake-up alarm';

  @override
  String wakeUpAlarmHint(String time) {
    return 'An alarm at $time on the mornings after your nights.';
  }

  @override
  String get sunrise => 'Sunrise before the alarm';

  @override
  String sunriseHint(int minutes) {
    return 'The screen lights up slowly for $minutes minutes before the wake-up alarm. Not when you are already using the phone.';
  }

  @override
  String get sunriseNeedsAlarm => 'Needs the wake-up alarm.';

  @override
  String get saveSleep => 'Save sleep to Health Connect';

  @override
  String get saveSleepHint =>
      'Each night is saved as sleep, from bedtime until you dismiss the wake-up alarm. Apps you allow in Health Connect can read it. Not backed up.';

  @override
  String get saveSleepNotAllowed =>
      'ZT Clock is not allowed to save sleep in Health Connect.';

  @override
  String get saveSleepNeedsAccess =>
      'Needs permission to write sleep in Health Connect.';

  @override
  String get sleepSounds => 'Sleep sounds';

  @override
  String get sleepSoundsHint =>
      'Made on the phone, on the media volume. They fade out at the end.';

  @override
  String get soundWhite => 'White noise';

  @override
  String get soundPink => 'Pink noise';

  @override
  String get soundDeep => 'Deep noise';

  @override
  String get stopAfter => 'Stop after';

  @override
  String get play => 'Play';

  @override
  String stopsAt(String time) {
    return 'Plays until $time';
  }

  @override
  String get wakeTask => 'Wake-up task';

  @override
  String get wakeTaskHint =>
      'Done before the alarm can be dismissed. Snooze still works.';

  @override
  String get wakeTaskNone => 'None';

  @override
  String get wakeTaskMath => 'Solve 3 sums';

  @override
  String get wakeTaskShake => 'Shake 30 times';

  @override
  String get screensaver => 'Night clock screensaver';

  @override
  String get screensaverHint =>
      'Shows the time and the next alarm while the phone charges. Choose \"Night clock\" in Android\'s screensaver settings.';

  @override
  String get screensaverNight => 'Dim red';

  @override
  String get screensaverNightHint => 'Easy on the eyes in a dark room';

  @override
  String get publicHolidays => 'Public holidays';

  @override
  String get publicHolidaysHint =>
      'Days alarms with \"Skip public holidays\" stay silent';

  @override
  String get holidayCalendar => 'Holiday calendar';

  @override
  String get noHolidays => 'None';

  @override
  String get holidaysPrivacy =>
      'Downloaded from Google\'s public holiday calendars, like any web page. No account is used and nothing about you is sent.';

  @override
  String get holidaysDownloading => 'Downloading…';

  @override
  String get holidaysFailed =>
      'Couldn\'t download. The last list still counts.';

  @override
  String holidaysUpdated(String date) {
    return 'Updated $date';
  }

  @override
  String get refresh => 'Refresh';

  @override
  String get holidaysTickedHint =>
      'Days off are ticked. Untick any day your alarms should ring on.';

  @override
  String get holidaysTickHint =>
      'Tick the days your alarms should skip. This calendar doesn\'t say which days are days off.';

  @override
  String get skipHolidays => 'Skip public holidays';

  @override
  String get skipHolidaysPick => 'Choose a holiday calendar first';

  @override
  String get logToTime => 'Log to ZT Time';

  @override
  String logToTimeSpan(String start, String end, String length) {
    return '$start to $end ($length)';
  }

  @override
  String get whatWasIt => 'What was it?';

  @override
  String get project => 'Project';

  @override
  String get noProject => 'No project';

  @override
  String get logIt => 'Log';

  @override
  String get loggedToTime => 'Logged in ZT Time';

  @override
  String get couldNotLog =>
      'Couldn\'t log it. Check the connection and try again.';

  @override
  String get offlineEdition => 'Offline edition';

  @override
  String get offlineEditionHint =>
      'No internet permission. No account, no sync, no downloads: nothing leaves this phone.';

  @override
  String get soundBells => 'Bells';

  @override
  String get soundBeeps => 'Beeps';

  @override
  String get soundSunrise => 'Sunrise';

  @override
  String get soundBuzzer => 'Buzzer';

  @override
  String get wakeTaskScan => 'Scan a code';

  @override
  String get wakeTaskScanSaved => 'Code saved';

  @override
  String get wakeTaskScanHint =>
      'Scan the same QR code or barcode to dismiss. Keep it away from the bed. If the camera can\'t be used, the alarm asks for sums instead.';

  @override
  String get wakeTaskScanAgain => 'Scan another';

  @override
  String get wakeTaskScanNone => 'No code was scanned';

  @override
  String get volumeButtons => 'Volume buttons';

  @override
  String get volumeButtonsVolume => 'Change the volume';

  @override
  String get volumeButtonsAbout =>
      'What the volume buttons do while an alarm rings on its own screen. A wake-up task is still asked for.';

  @override
  String get minVolume => 'Ring at least this loud';

  @override
  String get minVolumeOff => 'Off: the phone\'s alarm volume';

  @override
  String minVolumePercent(int percent) {
    return '$percent% of the loudest';
  }

  @override
  String get minVolumeAbout =>
      'If the phone\'s alarm volume is lower, it is raised while an alarm rings and put back afterwards. Timers are not changed.';
}
