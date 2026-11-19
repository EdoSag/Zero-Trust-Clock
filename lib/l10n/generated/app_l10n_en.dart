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
}
