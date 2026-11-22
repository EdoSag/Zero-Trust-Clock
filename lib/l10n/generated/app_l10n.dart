import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_l10n_en.dart';
import 'app_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ZT Clock'**
  String get appTitle;

  /// No description provided for @alarms.
  ///
  /// In en, this message translates to:
  /// **'Alarms'**
  String get alarms;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @addAlarm.
  ///
  /// In en, this message translates to:
  /// **'Add alarm'**
  String get addAlarm;

  /// No description provided for @noAlarms.
  ///
  /// In en, this message translates to:
  /// **'No alarms yet'**
  String get noAlarms;

  /// No description provided for @noAlarmsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to set one.'**
  String get noAlarmsHint;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get everyDay;

  /// No description provided for @once.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get once;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @turnOffOnce.
  ///
  /// In en, this message translates to:
  /// **'Turn off once'**
  String get turnOffOnce;

  /// No description provided for @turnBackOn.
  ///
  /// In en, this message translates to:
  /// **'Turn back on'**
  String get turnBackOn;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @offOnceNext.
  ///
  /// In en, this message translates to:
  /// **'Off once. Next: {day}'**
  String offOnceNext(String day);

  /// No description provided for @offOnce.
  ///
  /// In en, this message translates to:
  /// **'Off once'**
  String get offOnce;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @alarmOff.
  ///
  /// In en, this message translates to:
  /// **'Alarm off'**
  String get alarmOff;

  /// No description provided for @justOnce.
  ///
  /// In en, this message translates to:
  /// **'Just once'**
  String get justOnce;

  /// No description provided for @alarmDeleted.
  ///
  /// In en, this message translates to:
  /// **'Alarm deleted'**
  String get alarmDeleted;

  /// No description provided for @snoozedUntil.
  ///
  /// In en, this message translates to:
  /// **'Snoozed until {time}'**
  String snoozedUntil(String time);

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @snooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze'**
  String get snooze;

  /// No description provided for @ringingNow.
  ///
  /// In en, this message translates to:
  /// **'Ringing now'**
  String get ringingNow;

  /// No description provided for @ringsInDays.
  ///
  /// In en, this message translates to:
  /// **'Rings in {days} d {hours} h'**
  String ringsInDays(int days, int hours);

  /// No description provided for @ringsInHours.
  ///
  /// In en, this message translates to:
  /// **'Rings in {hours} h {minutes} min'**
  String ringsInHours(int hours, int minutes);

  /// No description provided for @ringsInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Rings in {minutes} min'**
  String ringsInMinutes(int minutes);

  /// No description provided for @ringsInUnderMinute.
  ///
  /// In en, this message translates to:
  /// **'Rings in less than a minute'**
  String get ringsInUnderMinute;

  /// No description provided for @mayNotRing.
  ///
  /// In en, this message translates to:
  /// **'Alarms may not ring'**
  String get mayNotRing;

  /// No description provided for @mayNotRingHint.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 thing on this phone needs attention.} other{{count} things on this phone need attention.}}'**
  String mayNotRingHint(int count);

  /// No description provided for @openAlarmCheck.
  ///
  /// In en, this message translates to:
  /// **'Open Alarm check'**
  String get openAlarmCheck;

  /// No description provided for @editAlarm.
  ///
  /// In en, this message translates to:
  /// **'Edit alarm'**
  String get editAlarm;

  /// No description provided for @changeTime.
  ///
  /// In en, this message translates to:
  /// **'Change time'**
  String get changeTime;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @ringsOnce.
  ///
  /// In en, this message translates to:
  /// **'No day picked: the alarm rings once.'**
  String get ringsOnce;

  /// No description provided for @label.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get label;

  /// No description provided for @labelHelper.
  ///
  /// In en, this message translates to:
  /// **'Not shown while the phone is locked.'**
  String get labelHelper;

  /// No description provided for @vibrate.
  ///
  /// In en, this message translates to:
  /// **'Vibrate'**
  String get vibrate;

  /// No description provided for @snoozeLength.
  ///
  /// In en, this message translates to:
  /// **'Snooze length'**
  String get snoozeLength;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @couldNotSave.
  ///
  /// In en, this message translates to:
  /// **'That did not work. Try again.'**
  String get couldNotSave;

  /// No description provided for @alarmCheck.
  ///
  /// In en, this message translates to:
  /// **'Alarm check'**
  String get alarmCheck;

  /// No description provided for @alarmCheckSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What can stop an alarm on this phone'**
  String get alarmCheckSubtitle;

  /// No description provided for @alarmCheckIntro.
  ///
  /// In en, this message translates to:
  /// **'Each line is something that can stop an alarm on this phone. Fix what is marked, then try a test alarm.'**
  String get alarmCheckIntro;

  /// No description provided for @allGood.
  ///
  /// In en, this message translates to:
  /// **'Everything looks right'**
  String get allGood;

  /// No description provided for @fix.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get fix;

  /// No description provided for @checkNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get checkNotifications;

  /// No description provided for @checkNotificationsOk.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get checkNotificationsOk;

  /// No description provided for @checkNotificationsBad.
  ///
  /// In en, this message translates to:
  /// **'Off. A ringing alarm cannot show on screen.'**
  String get checkNotificationsBad;

  /// No description provided for @checkRingChannel.
  ///
  /// In en, this message translates to:
  /// **'\"Ringing alarms\" notifications'**
  String get checkRingChannel;

  /// No description provided for @checkRingChannelOk.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get checkRingChannelOk;

  /// No description provided for @checkRingChannelBad.
  ///
  /// In en, this message translates to:
  /// **'Turned down or off. The alarm screen may not open.'**
  String get checkRingChannelBad;

  /// No description provided for @checkFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Alarm screen over the lock screen'**
  String get checkFullScreen;

  /// No description provided for @checkFullScreenOk.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get checkFullScreenOk;

  /// No description provided for @checkFullScreenBad.
  ///
  /// In en, this message translates to:
  /// **'Not allowed. You would only get a notification.'**
  String get checkFullScreenBad;

  /// No description provided for @checkExact.
  ///
  /// In en, this message translates to:
  /// **'Exact alarms'**
  String get checkExact;

  /// No description provided for @checkExactOk.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get checkExactOk;

  /// No description provided for @checkExactBad.
  ///
  /// In en, this message translates to:
  /// **'Not allowed. Alarms could ring late.'**
  String get checkExactBad;

  /// No description provided for @checkVolume.
  ///
  /// In en, this message translates to:
  /// **'Alarm volume'**
  String get checkVolume;

  /// No description provided for @checkVolumeOk.
  ///
  /// In en, this message translates to:
  /// **'{level} of {max}'**
  String checkVolumeOk(int level, int max);

  /// No description provided for @checkVolumeBad.
  ///
  /// In en, this message translates to:
  /// **'At zero. Alarms only vibrate.'**
  String get checkVolumeBad;

  /// No description provided for @checkSilence.
  ///
  /// In en, this message translates to:
  /// **'Do Not Disturb'**
  String get checkSilence;

  /// No description provided for @checkSilenceOk.
  ///
  /// In en, this message translates to:
  /// **'Alarms can ring'**
  String get checkSilenceOk;

  /// No description provided for @checkSilenceBad.
  ///
  /// In en, this message translates to:
  /// **'Total silence is on. It mutes alarms.'**
  String get checkSilenceBad;

  /// No description provided for @checkProfile.
  ///
  /// In en, this message translates to:
  /// **'Phone profile'**
  String get checkProfile;

  /// No description provided for @checkProfileOk.
  ///
  /// In en, this message translates to:
  /// **'Main profile'**
  String get checkProfileOk;

  /// No description provided for @checkProfileBad.
  ///
  /// In en, this message translates to:
  /// **'Secondary profile. When this profile is ended, its alarms do not ring.'**
  String get checkProfileBad;

  /// No description provided for @batteryXiaomi.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi, Redmi and POCO phones'**
  String get batteryXiaomi;

  /// No description provided for @batteryXiaomiHint.
  ///
  /// In en, this message translates to:
  /// **'These phones can stop an app that is closed, and its alarms with it. In the app\'s settings turn on Autostart, and set Battery saver to No restrictions.'**
  String get batteryXiaomiHint;

  /// No description provided for @batteryHuawei.
  ///
  /// In en, this message translates to:
  /// **'Huawei and Honor phones'**
  String get batteryHuawei;

  /// No description provided for @batteryHuaweiHint.
  ///
  /// In en, this message translates to:
  /// **'These phones close apps to save battery. In Settings > Battery > App launch, switch ZT Clock to Manage manually and leave Auto-launch and Run in background on.'**
  String get batteryHuaweiHint;

  /// No description provided for @batterySamsung.
  ///
  /// In en, this message translates to:
  /// **'Samsung phones'**
  String get batterySamsung;

  /// No description provided for @batterySamsungHint.
  ///
  /// In en, this message translates to:
  /// **'Samsung puts apps you rarely open to sleep, and a sleeping app\'s alarms can be late. In the app\'s settings open Battery and pick Unrestricted, and keep ZT Clock out of Sleeping apps.'**
  String get batterySamsungHint;

  /// No description provided for @openAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openAppSettings;

  /// No description provided for @checkRestart.
  ///
  /// In en, this message translates to:
  /// **'After a restart'**
  String get checkRestart;

  /// No description provided for @checkRestartNever.
  ///
  /// In en, this message translates to:
  /// **'No restart seen since the app was installed.'**
  String get checkRestartNever;

  /// No description provided for @checkRestartLocked.
  ///
  /// In en, this message translates to:
  /// **'Alarms were set again on {when}, before the phone was unlocked.'**
  String checkRestartLocked(String when);

  /// No description provided for @checkRestartUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Alarms were set again on {when}, after the phone was unlocked.'**
  String checkRestartUnlocked(String when);

  /// No description provided for @tryIt.
  ///
  /// In en, this message translates to:
  /// **'Try it'**
  String get tryIt;

  /// No description provided for @testIn10.
  ///
  /// In en, this message translates to:
  /// **'Test alarm in 10 seconds'**
  String get testIn10;

  /// No description provided for @testIn10Hint.
  ///
  /// In en, this message translates to:
  /// **'Rings like a real alarm. Lock the phone first to see the alarm screen.'**
  String get testIn10Hint;

  /// No description provided for @testStarted.
  ///
  /// In en, this message translates to:
  /// **'Test alarm rings in 10 seconds.'**
  String get testStarted;

  /// No description provided for @restartTest.
  ///
  /// In en, this message translates to:
  /// **'Restart test'**
  String get restartTest;

  /// No description provided for @restartTestHint.
  ///
  /// In en, this message translates to:
  /// **'Sets a test alarm 3 minutes from now. Restart the phone and leave it locked. The alarm should still ring.'**
  String get restartTestHint;

  /// No description provided for @restartTestStarted.
  ///
  /// In en, this message translates to:
  /// **'Test alarm rings in 3 minutes. Restart the phone now and do not unlock it.'**
  String get restartTestStarted;

  /// No description provided for @alarmsAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 alarm from your account was added. It stays off on this phone until you switch it on.} other{{count} alarms from your account were added. They stay off on this phone until you switch them on.}}'**
  String alarmsAdded(int count);

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @sound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// No description provided for @soundChime.
  ///
  /// In en, this message translates to:
  /// **'ZT chime'**
  String get soundChime;

  /// No description provided for @soundSystem.
  ///
  /// In en, this message translates to:
  /// **'The phone\'s alarm sound'**
  String get soundSystem;

  /// No description provided for @soundRingtone.
  ///
  /// In en, this message translates to:
  /// **'Choose a phone sound'**
  String get soundRingtone;

  /// No description provided for @soundFile.
  ///
  /// In en, this message translates to:
  /// **'Choose an audio file'**
  String get soundFile;

  /// No description provided for @soundPicked.
  ///
  /// In en, this message translates to:
  /// **'Picked sound'**
  String get soundPicked;

  /// No description provided for @soundHint.
  ///
  /// In en, this message translates to:
  /// **'A sound you choose is copied into the app, so it also plays before the phone is first unlocked. If it can\'t play, the ZT chime rings instead.'**
  String get soundHint;

  /// No description provided for @gradual.
  ///
  /// In en, this message translates to:
  /// **'Gradually louder'**
  String get gradual;

  /// No description provided for @gradualHint.
  ///
  /// In en, this message translates to:
  /// **'Starts quietly and reaches full volume in a minute'**
  String get gradualHint;

  /// No description provided for @silenceAfter.
  ///
  /// In en, this message translates to:
  /// **'Silence after'**
  String get silenceAfter;

  /// No description provided for @pauseUntil.
  ///
  /// In en, this message translates to:
  /// **'Pause until…'**
  String get pauseUntil;

  /// No description provided for @pauseUntilHelp.
  ///
  /// In en, this message translates to:
  /// **'Silent through this day'**
  String get pauseUntilHelp;

  /// No description provided for @pausedUntil.
  ///
  /// In en, this message translates to:
  /// **'Paused until {day}'**
  String pausedUntil(String day);

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @pauseAll.
  ///
  /// In en, this message translates to:
  /// **'Pause all alarms until…'**
  String get pauseAll;

  /// No description provided for @resumeAll.
  ///
  /// In en, this message translates to:
  /// **'Resume all alarms'**
  String get resumeAll;

  /// No description provided for @pausedAllUntil.
  ///
  /// In en, this message translates to:
  /// **'Repeating alarms are paused through {day}. Alarms set for one day still ring.'**
  String pausedAllUntil(String day);

  /// No description provided for @timers.
  ///
  /// In en, this message translates to:
  /// **'Timers'**
  String get timers;

  /// No description provided for @stopwatch.
  ///
  /// In en, this message translates to:
  /// **'Stopwatch'**
  String get stopwatch;

  /// No description provided for @addTimer.
  ///
  /// In en, this message translates to:
  /// **'Add timer'**
  String get addTimer;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @addMinute.
  ///
  /// In en, this message translates to:
  /// **'+1:00'**
  String get addMinute;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @timesUp.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up'**
  String get timesUp;

  /// No description provided for @timerOf.
  ///
  /// In en, this message translates to:
  /// **'{length} timer'**
  String timerOf(String length);

  /// No description provided for @timerPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get timerPaused;

  /// No description provided for @timerLabel.
  ///
  /// In en, this message translates to:
  /// **'Timer label'**
  String get timerLabel;

  /// No description provided for @deleteTimer.
  ///
  /// In en, this message translates to:
  /// **'Delete timer'**
  String get deleteTimer;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @quickTimers.
  ///
  /// In en, this message translates to:
  /// **'Quick timers'**
  String get quickTimers;

  /// No description provided for @saveQuickTimer.
  ///
  /// In en, this message translates to:
  /// **'Save as a quick timer'**
  String get saveQuickTimer;

  /// No description provided for @quickTimerSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved as a quick timer'**
  String get quickTimerSaved;

  /// No description provided for @quickTimerRemoved.
  ///
  /// In en, this message translates to:
  /// **'Quick timer removed'**
  String get quickTimerRemoved;

  /// No description provided for @quickTimersHint.
  ///
  /// In en, this message translates to:
  /// **'Tap one to start it. Remove one you saved with its ×.'**
  String get quickTimersHint;

  /// No description provided for @hoursUnit.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get hoursUnit;

  /// No description provided for @minutesUnit.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get minutesUnit;

  /// No description provided for @secondsUnit.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get secondsUnit;

  /// No description provided for @deleteDigit.
  ///
  /// In en, this message translates to:
  /// **'Delete digit'**
  String get deleteDigit;

  /// No description provided for @lap.
  ///
  /// In en, this message translates to:
  /// **'Lap'**
  String get lap;

  /// No description provided for @lapNumber.
  ///
  /// In en, this message translates to:
  /// **'Lap {number}'**
  String lapNumber(int number);

  /// No description provided for @copyLaps.
  ///
  /// In en, this message translates to:
  /// **'Copy laps'**
  String get copyLaps;

  /// No description provided for @lapsCopied.
  ///
  /// In en, this message translates to:
  /// **'Laps copied'**
  String get lapsCopied;

  /// No description provided for @timerStarted.
  ///
  /// In en, this message translates to:
  /// **'Timer started'**
  String get timerStarted;

  /// No description provided for @clock.
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get clock;

  /// No description provided for @addCity.
  ///
  /// In en, this message translates to:
  /// **'Add city'**
  String get addCity;

  /// No description provided for @searchCities.
  ///
  /// In en, this message translates to:
  /// **'Search cities or countries'**
  String get searchCities;

  /// No description provided for @noCities.
  ///
  /// In en, this message translates to:
  /// **'No cities yet'**
  String get noCities;

  /// No description provided for @noCitiesHint.
  ///
  /// In en, this message translates to:
  /// **'Add a city to see its time next to yours.'**
  String get noCitiesHint;

  /// No description provided for @cityRemoved.
  ///
  /// In en, this message translates to:
  /// **'{city} removed'**
  String cityRemoved(String city);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @sameTime.
  ///
  /// In en, this message translates to:
  /// **'Same time'**
  String get sameTime;

  /// No description provided for @timeAhead.
  ///
  /// In en, this message translates to:
  /// **'{time} ahead'**
  String timeAhead(String time);

  /// No description provided for @timeBehind.
  ///
  /// In en, this message translates to:
  /// **'{time} behind'**
  String timeBehind(String time);

  /// No description provided for @hoursOnly.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String hoursOnly(int hours);

  /// No description provided for @hoursAndMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String hoursAndMinutes(int hours, int minutes);

  /// No description provided for @dayAndDifference.
  ///
  /// In en, this message translates to:
  /// **'{day}, {difference}'**
  String dayAndDifference(String day, String difference);

  /// No description provided for @noCityFound.
  ///
  /// In en, this message translates to:
  /// **'No city found'**
  String get noCityFound;

  /// No description provided for @dragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Long-press to reorder, swipe to remove.'**
  String get dragToReorder;

  /// No description provided for @homeIn.
  ///
  /// In en, this message translates to:
  /// **'Home: {city}'**
  String homeIn(String city);

  /// No description provided for @homeTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Home time zone'**
  String get homeTimeZone;

  /// No description provided for @homeTimeZoneOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get homeTimeZoneOff;

  /// No description provided for @homeTimeZoneOn.
  ///
  /// In en, this message translates to:
  /// **'{city}. Its time shows in the Clock tab while the phone is in another time zone.'**
  String homeTimeZoneOn(String city);

  /// No description provided for @homeHere.
  ///
  /// In en, this message translates to:
  /// **'This phone\'s time zone now ({city})'**
  String homeHere(String city);

  /// No description provided for @homePickCity.
  ///
  /// In en, this message translates to:
  /// **'Pick a city'**
  String get homePickCity;

  /// No description provided for @homeTimeZoneAbout.
  ///
  /// In en, this message translates to:
  /// **'When you travel and the phone changes time zone, the Clock tab also shows the time at home. At home nothing is added.'**
  String get homeTimeZoneAbout;

  /// No description provided for @bedtime.
  ///
  /// In en, this message translates to:
  /// **'Bedtime'**
  String get bedtime;

  /// No description provided for @bedtimeSchedule.
  ///
  /// In en, this message translates to:
  /// **'Bedtime schedule'**
  String get bedtimeSchedule;

  /// No description provided for @bedtimeScheduleHint.
  ///
  /// In en, this message translates to:
  /// **'A reminder before bed, and quiet through the night.'**
  String get bedtimeScheduleHint;

  /// No description provided for @bedtimeStart.
  ///
  /// In en, this message translates to:
  /// **'Bedtime'**
  String get bedtimeStart;

  /// No description provided for @wakeUp.
  ///
  /// In en, this message translates to:
  /// **'Wake up'**
  String get wakeUp;

  /// No description provided for @sleepFor.
  ///
  /// In en, this message translates to:
  /// **'{length} of sleep'**
  String sleepFor(String length);

  /// No description provided for @nights.
  ///
  /// In en, this message translates to:
  /// **'Nights'**
  String get nights;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @doNotDisturbAtBedtime.
  ///
  /// In en, this message translates to:
  /// **'Do Not Disturb at bedtime'**
  String get doNotDisturbAtBedtime;

  /// No description provided for @doNotDisturbHint.
  ///
  /// In en, this message translates to:
  /// **'Silences calls and notifications through the night. Alarms still ring.'**
  String get doNotDisturbHint;

  /// No description provided for @dndNeedsAccess.
  ///
  /// In en, this message translates to:
  /// **'Needs Do Not Disturb access in Android\'s settings.'**
  String get dndNeedsAccess;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @wakeUpAlarm.
  ///
  /// In en, this message translates to:
  /// **'Wake-up alarm'**
  String get wakeUpAlarm;

  /// No description provided for @wakeUpAlarmHint.
  ///
  /// In en, this message translates to:
  /// **'An alarm at {time} on the mornings after your nights.'**
  String wakeUpAlarmHint(String time);

  /// No description provided for @sunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise before the alarm'**
  String get sunrise;

  /// No description provided for @sunriseHint.
  ///
  /// In en, this message translates to:
  /// **'The screen lights up slowly for {minutes} minutes before the wake-up alarm. Not when you are already using the phone.'**
  String sunriseHint(int minutes);

  /// No description provided for @sunriseNeedsAlarm.
  ///
  /// In en, this message translates to:
  /// **'Needs the wake-up alarm.'**
  String get sunriseNeedsAlarm;

  /// No description provided for @saveSleep.
  ///
  /// In en, this message translates to:
  /// **'Save sleep to Health Connect'**
  String get saveSleep;

  /// No description provided for @saveSleepHint.
  ///
  /// In en, this message translates to:
  /// **'Each night is saved as sleep, from bedtime until you dismiss the wake-up alarm. Apps you allow in Health Connect can read it. Not backed up.'**
  String get saveSleepHint;

  /// No description provided for @saveSleepNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'ZT Clock is not allowed to save sleep in Health Connect.'**
  String get saveSleepNotAllowed;

  /// No description provided for @saveSleepNeedsAccess.
  ///
  /// In en, this message translates to:
  /// **'Needs permission to write sleep in Health Connect.'**
  String get saveSleepNeedsAccess;

  /// No description provided for @sleepSounds.
  ///
  /// In en, this message translates to:
  /// **'Sleep sounds'**
  String get sleepSounds;

  /// No description provided for @sleepSoundsHint.
  ///
  /// In en, this message translates to:
  /// **'Made on the phone, on the media volume. They fade out at the end.'**
  String get sleepSoundsHint;

  /// No description provided for @soundWhite.
  ///
  /// In en, this message translates to:
  /// **'White noise'**
  String get soundWhite;

  /// No description provided for @soundPink.
  ///
  /// In en, this message translates to:
  /// **'Pink noise'**
  String get soundPink;

  /// No description provided for @soundDeep.
  ///
  /// In en, this message translates to:
  /// **'Deep noise'**
  String get soundDeep;

  /// No description provided for @stopAfter.
  ///
  /// In en, this message translates to:
  /// **'Stop after'**
  String get stopAfter;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @stopsAt.
  ///
  /// In en, this message translates to:
  /// **'Plays until {time}'**
  String stopsAt(String time);

  /// No description provided for @wakeTask.
  ///
  /// In en, this message translates to:
  /// **'Wake-up task'**
  String get wakeTask;

  /// No description provided for @wakeTaskHint.
  ///
  /// In en, this message translates to:
  /// **'Done before the alarm can be dismissed. Snooze still works.'**
  String get wakeTaskHint;

  /// No description provided for @wakeTaskNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get wakeTaskNone;

  /// No description provided for @wakeTaskMath.
  ///
  /// In en, this message translates to:
  /// **'Solve 3 sums'**
  String get wakeTaskMath;

  /// No description provided for @wakeTaskShake.
  ///
  /// In en, this message translates to:
  /// **'Shake 30 times'**
  String get wakeTaskShake;

  /// No description provided for @screensaver.
  ///
  /// In en, this message translates to:
  /// **'Night clock screensaver'**
  String get screensaver;

  /// No description provided for @screensaverHint.
  ///
  /// In en, this message translates to:
  /// **'Shows the time and the next alarm while the phone charges. Choose \"Night clock\" in Android\'s screensaver settings.'**
  String get screensaverHint;

  /// No description provided for @screensaverNight.
  ///
  /// In en, this message translates to:
  /// **'Dim red'**
  String get screensaverNight;

  /// No description provided for @screensaverNightHint.
  ///
  /// In en, this message translates to:
  /// **'Easy on the eyes in a dark room'**
  String get screensaverNightHint;

  /// No description provided for @publicHolidays.
  ///
  /// In en, this message translates to:
  /// **'Public holidays'**
  String get publicHolidays;

  /// No description provided for @publicHolidaysHint.
  ///
  /// In en, this message translates to:
  /// **'Days alarms with \"Skip public holidays\" stay silent'**
  String get publicHolidaysHint;

  /// No description provided for @holidayCalendar.
  ///
  /// In en, this message translates to:
  /// **'Holiday calendar'**
  String get holidayCalendar;

  /// No description provided for @noHolidays.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noHolidays;

  /// No description provided for @holidaysPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Downloaded from Google\'s public holiday calendars, like any web page. No account is used and nothing about you is sent.'**
  String get holidaysPrivacy;

  /// No description provided for @holidaysDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get holidaysDownloading;

  /// No description provided for @holidaysFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download. The last list still counts.'**
  String get holidaysFailed;

  /// No description provided for @holidaysUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String holidaysUpdated(String date);

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @holidaysTickedHint.
  ///
  /// In en, this message translates to:
  /// **'Days off are ticked. Untick any day your alarms should ring on.'**
  String get holidaysTickedHint;

  /// No description provided for @holidaysTickHint.
  ///
  /// In en, this message translates to:
  /// **'Tick the days your alarms should skip. This calendar doesn\'t say which days are days off.'**
  String get holidaysTickHint;

  /// No description provided for @skipHolidays.
  ///
  /// In en, this message translates to:
  /// **'Skip public holidays'**
  String get skipHolidays;

  /// No description provided for @skipHolidaysPick.
  ///
  /// In en, this message translates to:
  /// **'Choose a holiday calendar first'**
  String get skipHolidaysPick;

  /// No description provided for @logToTime.
  ///
  /// In en, this message translates to:
  /// **'Log to ZT Time'**
  String get logToTime;

  /// No description provided for @logToTimeSpan.
  ///
  /// In en, this message translates to:
  /// **'{start} to {end} ({length})'**
  String logToTimeSpan(String start, String end, String length);

  /// No description provided for @whatWasIt.
  ///
  /// In en, this message translates to:
  /// **'What was it?'**
  String get whatWasIt;

  /// No description provided for @project.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get project;

  /// No description provided for @noProject.
  ///
  /// In en, this message translates to:
  /// **'No project'**
  String get noProject;

  /// No description provided for @logIt.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get logIt;

  /// No description provided for @loggedToTime.
  ///
  /// In en, this message translates to:
  /// **'Logged in ZT Time'**
  String get loggedToTime;

  /// No description provided for @couldNotLog.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t log it. Check the connection and try again.'**
  String get couldNotLog;

  /// No description provided for @offlineEdition.
  ///
  /// In en, this message translates to:
  /// **'Offline edition'**
  String get offlineEdition;

  /// No description provided for @offlineEditionHint.
  ///
  /// In en, this message translates to:
  /// **'No internet permission. No account, no sync, no downloads: nothing leaves this phone.'**
  String get offlineEditionHint;

  /// No description provided for @soundBells.
  ///
  /// In en, this message translates to:
  /// **'Bells'**
  String get soundBells;

  /// No description provided for @soundBeeps.
  ///
  /// In en, this message translates to:
  /// **'Beeps'**
  String get soundBeeps;

  /// No description provided for @soundSunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get soundSunrise;

  /// No description provided for @soundBuzzer.
  ///
  /// In en, this message translates to:
  /// **'Buzzer'**
  String get soundBuzzer;

  /// No description provided for @wakeTaskScan.
  ///
  /// In en, this message translates to:
  /// **'Scan a code'**
  String get wakeTaskScan;

  /// No description provided for @wakeTaskScanSaved.
  ///
  /// In en, this message translates to:
  /// **'Code saved'**
  String get wakeTaskScanSaved;

  /// No description provided for @wakeTaskScanHint.
  ///
  /// In en, this message translates to:
  /// **'Scan the same QR code or barcode to dismiss. Keep it away from the bed. If the camera can\'t be used, the alarm asks for sums instead.'**
  String get wakeTaskScanHint;

  /// No description provided for @wakeTaskScanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan another'**
  String get wakeTaskScanAgain;

  /// No description provided for @wakeTaskScanNone.
  ///
  /// In en, this message translates to:
  /// **'No code was scanned'**
  String get wakeTaskScanNone;

  /// No description provided for @volumeButtons.
  ///
  /// In en, this message translates to:
  /// **'Volume buttons'**
  String get volumeButtons;

  /// No description provided for @volumeButtonsVolume.
  ///
  /// In en, this message translates to:
  /// **'Change the volume'**
  String get volumeButtonsVolume;

  /// No description provided for @volumeButtonsAbout.
  ///
  /// In en, this message translates to:
  /// **'What the volume buttons do while an alarm rings on its own screen. A wake-up task is still asked for.'**
  String get volumeButtonsAbout;

  /// No description provided for @minVolume.
  ///
  /// In en, this message translates to:
  /// **'Ring at least this loud'**
  String get minVolume;

  /// No description provided for @minVolumeOff.
  ///
  /// In en, this message translates to:
  /// **'Off: the phone\'s alarm volume'**
  String get minVolumeOff;

  /// No description provided for @minVolumePercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of the loudest'**
  String minVolumePercent(int percent);

  /// No description provided for @minVolumeAbout.
  ///
  /// In en, this message translates to:
  /// **'If the phone\'s alarm volume is lower, it is raised while an alarm rings and put back afterwards. Timers are not changed.'**
  String get minVolumeAbout;

  /// No description provided for @repeatWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get repeatWeekdays;

  /// No description provided for @repeatShifts.
  ///
  /// In en, this message translates to:
  /// **'Shift pattern'**
  String get repeatShifts;

  /// No description provided for @shiftText.
  ///
  /// In en, this message translates to:
  /// **'Shifts: {on} of every {length} days'**
  String shiftText(int on, int length);

  /// No description provided for @shiftLength.
  ///
  /// In en, this message translates to:
  /// **'Days in the cycle'**
  String get shiftLength;

  /// No description provided for @shiftStart.
  ///
  /// In en, this message translates to:
  /// **'Day 1 of the cycle'**
  String get shiftStart;

  /// No description provided for @shiftDaysHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the days of the cycle the alarm rings on. The cycle repeats from day 1 again and again.'**
  String get shiftDaysHint;

  /// No description provided for @shiftDay.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String shiftDay(int day);

  /// No description provided for @shiftOnOff.
  ///
  /// In en, this message translates to:
  /// **'{on} on, {off} off'**
  String shiftOnOff(int on, int off);

  /// No description provided for @shiftTwoShiftsHint.
  ///
  /// In en, this message translates to:
  /// **'Two shifts with different times, like 2 days, 2 nights, 4 off? Make one alarm for each, with the same day 1.'**
  String get shiftTwoShiftsHint;

  /// No description provided for @shiftToday.
  ///
  /// In en, this message translates to:
  /// **'Today is day {day} of {length}'**
  String shiftToday(int day, int length);

  /// No description provided for @calendarLink.
  ///
  /// In en, this message translates to:
  /// **'Follow ZT Calendar'**
  String get calendarLink;

  /// No description provided for @calendarLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Rings in time for the day\'s first event. ZT Clock reads ZT Calendar each time it is opened, two weeks ahead; days it hasn\'t read ring at the alarm\'s own time.'**
  String get calendarLinkHint;

  /// No description provided for @calendarNeedsAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to follow ZT Calendar.'**
  String get calendarNeedsAccount;

  /// No description provided for @calendarNeedsRepeat.
  ///
  /// In en, this message translates to:
  /// **'Pick repeat days or a shift pattern first.'**
  String get calendarNeedsRepeat;

  /// No description provided for @calendarLead.
  ///
  /// In en, this message translates to:
  /// **'Before the first event'**
  String get calendarLead;

  /// No description provided for @calendarEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier when needed'**
  String get calendarEarlier;

  /// No description provided for @calendarEarlierHint.
  ///
  /// In en, this message translates to:
  /// **'Rings at {time}, or earlier when the first event needs it.'**
  String calendarEarlierHint(String time);

  /// No description provided for @calendarFollow.
  ///
  /// In en, this message translates to:
  /// **'Always before the first event'**
  String get calendarFollow;

  /// No description provided for @calendarFollowHint.
  ///
  /// In en, this message translates to:
  /// **'Rings before the first event, later than {time} too. Without events: {time}.'**
  String calendarFollowHint(String time);

  /// No description provided for @calendarEarliest.
  ///
  /// In en, this message translates to:
  /// **'Never before'**
  String get calendarEarliest;

  /// No description provided for @calendarOtherDays.
  ///
  /// In en, this message translates to:
  /// **'Also on other days, for a morning event'**
  String get calendarOtherDays;

  /// No description provided for @calendarLinkedShort.
  ///
  /// In en, this message translates to:
  /// **'Follows ZT Calendar'**
  String get calendarLinkedShort;

  /// No description provided for @smartWake.
  ///
  /// In en, this message translates to:
  /// **'Smart wake window'**
  String get smartWake;

  /// No description provided for @smartWakeHint.
  ///
  /// In en, this message translates to:
  /// **'With the phone on the bed, it rings up to this much earlier when you stir, so you wake in light sleep. Without movement it rings at its time.'**
  String get smartWakeHint;

  /// No description provided for @smartWakeOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get smartWakeOff;

  /// No description provided for @morningScreen.
  ///
  /// In en, this message translates to:
  /// **'After dismissing an alarm'**
  String get morningScreen;

  /// No description provided for @morningOff.
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get morningOff;

  /// No description provided for @morningCounts.
  ///
  /// In en, this message translates to:
  /// **'The day ahead, counts only'**
  String get morningCounts;

  /// No description provided for @morningDetails.
  ///
  /// In en, this message translates to:
  /// **'The day ahead, with names'**
  String get morningDetails;

  /// No description provided for @morningHint.
  ///
  /// In en, this message translates to:
  /// **'Today\'s events from ZT Calendar, tasks from ZT Tasks and quests from ZT Quests, as ZT Clock last read them (signed in). Names also show over the lock screen.'**
  String get morningHint;

  /// No description provided for @questGoal.
  ///
  /// In en, this message translates to:
  /// **'{category, select, fitness{Fitness} productivity{Productivity} nutrition{Nutrition} sleep{Sleep} learning{Learning} mindfulness{Mindfulness} other{Goal}}'**
  String questGoal(String category);
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'he':
      return AppL10nHe();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
