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
