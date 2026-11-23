// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppL10nHe extends AppL10n {
  AppL10nHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'ZT Clock';

  @override
  String get alarms => 'שעונים מעוררים';

  @override
  String get settings => 'הגדרות';

  @override
  String get addAlarm => 'הוספת שעון מעורר';

  @override
  String get noAlarms => 'אין עדיין שעונים מעוררים';

  @override
  String get noAlarmsHint => 'לחצו על + כדי להוסיף.';

  @override
  String get everyDay => 'כל יום';

  @override
  String get once => 'פעם אחת';

  @override
  String get today => 'היום';

  @override
  String get tomorrow => 'מחר';

  @override
  String get turnOffOnce => 'כיבוי לפעם אחת';

  @override
  String get turnBackOn => 'הפעלה מחדש';

  @override
  String get edit => 'עריכה';

  @override
  String get delete => 'מחיקה';

  @override
  String get moreOptions => 'אפשרויות נוספות';

  @override
  String offOnceNext(String day) {
    return 'כבוי לפעם אחת. הבא: $day';
  }

  @override
  String get offOnce => 'כבוי לפעם אחת';

  @override
  String get undo => 'ביטול';

  @override
  String get alarmOff => 'השעון המעורר כבוי';

  @override
  String get justOnce => 'רק הפעם';

  @override
  String get alarmDeleted => 'השעון המעורר נמחק';

  @override
  String snoozedUntil(String time) {
    return 'נודניק עד $time';
  }

  @override
  String get dismiss => 'סגירה';

  @override
  String get snooze => 'נודניק';

  @override
  String get ringingNow => 'מצלצל עכשיו';

  @override
  String ringsInDays(int days, int hours) {
    return 'יצלצל בעוד $days ימים ו-$hours שעות';
  }

  @override
  String ringsInHours(int hours, int minutes) {
    return 'יצלצל בעוד $hours שעות ו-$minutes דקות';
  }

  @override
  String ringsInMinutes(int minutes) {
    return 'יצלצל בעוד $minutes דקות';
  }

  @override
  String get ringsInUnderMinute => 'יצלצל בעוד פחות מדקה';

  @override
  String get mayNotRing => 'ייתכן שהשעונים המעוררים לא יצלצלו';

  @override
  String mayNotRingHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count דברים בטלפון הזה דורשים טיפול.',
      one: 'דבר אחד בטלפון הזה דורש טיפול.',
    );
    return '$_temp0';
  }

  @override
  String get openAlarmCheck => 'פתיחת בדיקת השעון המעורר';

  @override
  String get editAlarm => 'עריכת שעון מעורר';

  @override
  String get changeTime => 'שינוי השעה';

  @override
  String get repeat => 'חזרה';

  @override
  String get ringsOnce => 'לא נבחר יום: השעון המעורר יצלצל פעם אחת.';

  @override
  String get label => 'תווית';

  @override
  String get labelHelper => 'לא מוצגת כשהטלפון נעול.';

  @override
  String get vibrate => 'רטט';

  @override
  String get snoozeLength => 'משך הנודניק';

  @override
  String minutesShort(int minutes) {
    return '$minutes דק׳';
  }

  @override
  String get save => 'שמירה';

  @override
  String get couldNotSave => 'זה לא הצליח. נסו שוב.';

  @override
  String get alarmCheck => 'בדיקת השעון המעורר';

  @override
  String get alarmCheckSubtitle => 'מה עלול למנוע משעון מעורר לצלצל בטלפון הזה';

  @override
  String get alarmCheckIntro =>
      'כל שורה היא דבר שעלול למנוע משעון מעורר לצלצל בטלפון הזה. תקנו את מה שמסומן, ואז נסו שעון מעורר לבדיקה.';

  @override
  String get allGood => 'הכול נראה תקין';

  @override
  String get fix => 'תיקון';

  @override
  String get checkNotifications => 'התראות';

  @override
  String get checkNotificationsOk => 'פועלות';

  @override
  String get checkNotificationsBad =>
      'כבויות. שעון מעורר מצלצל לא יכול להופיע על המסך.';

  @override
  String get checkRingChannel => 'התראות \"שעונים מעוררים שמצלצלים\"';

  @override
  String get checkRingChannelOk => 'רגיל';

  @override
  String get checkRingChannelBad =>
      'הונמכו או כובו. ייתכן שמסך השעון המעורר לא ייפתח.';

  @override
  String get checkFullScreen => 'מסך השעון המעורר מעל מסך הנעילה';

  @override
  String get checkFullScreenOk => 'מותר';

  @override
  String get checkFullScreenBad => 'לא מותר. תקבלו רק התראה.';

  @override
  String get checkExact => 'שעונים מעוררים מדויקים';

  @override
  String get checkExactOk => 'מותר';

  @override
  String get checkExactBad => 'לא מותר. שעונים מעוררים עלולים לצלצל באיחור.';

  @override
  String get checkVolume => 'עוצמת השעון המעורר';

  @override
  String checkVolumeOk(int level, int max) {
    return '$level מתוך $max';
  }

  @override
  String get checkVolumeBad => 'על אפס. השעונים המעוררים רק ירטטו.';

  @override
  String get checkSilence => 'נא לא להפריע';

  @override
  String get checkSilenceOk => 'שעונים מעוררים יכולים לצלצל';

  @override
  String get checkSilenceBad =>
      'מצב \"שקט מוחלט\" פועל. הוא משתיק גם שעונים מעוררים.';

  @override
  String get checkProfile => 'פרופיל הטלפון';

  @override
  String get checkProfileOk => 'הפרופיל הראשי';

  @override
  String get checkProfileBad =>
      'פרופיל משני. כשמסיימים את הפרופיל הזה, השעונים המעוררים שלו לא מצלצלים.';

  @override
  String get batteryXiaomi => 'טלפונים של Xiaomi, Redmi ו-POCO';

  @override
  String get batteryXiaomiHint =>
      'הטלפונים האלה יכולים לעצור אפליקציה סגורה, ואיתה את השעונים המעוררים שלה. בהגדרות האפליקציה הפעילו הפעלה אוטומטית (Autostart) ובחרו בחיסכון בסוללה \"ללא הגבלות\".';

  @override
  String get batteryHuawei => 'טלפונים של Huawei ו-Honor';

  @override
  String get batteryHuaweiHint =>
      'הטלפונים האלה סוגרים אפליקציות כדי לחסוך בסוללה. בהגדרות > סוללה > הפעלת אפליקציות, העבירו את ZT Clock לניהול ידני והשאירו דלוקים הפעלה אוטומטית והפעלה ברקע.';

  @override
  String get batterySamsung => 'טלפונים של Samsung';

  @override
  String get batterySamsungHint =>
      'Samsung מעבירה אפליקציות שלא פותחים הרבה למצב שינה, והשעונים המעוררים של אפליקציה ישנה יכולים לאחר. בהגדרות האפליקציה פתחו את סוללה ובחרו \"ללא הגבלה\", ואל תוסיפו את ZT Clock לאפליקציות במצב שינה.';

  @override
  String get openAppSettings => 'פתיחה';

  @override
  String get checkRestart => 'אחרי הפעלה מחדש';

  @override
  String get checkRestartNever => 'לא זוהתה הפעלה מחדש מאז התקנת האפליקציה.';

  @override
  String checkRestartLocked(String when) {
    return 'השעונים המעוררים הוגדרו מחדש ב-$when, לפני שהטלפון נפתח.';
  }

  @override
  String checkRestartUnlocked(String when) {
    return 'השעונים המעוררים הוגדרו מחדש ב-$when, אחרי שהטלפון נפתח.';
  }

  @override
  String get tryIt => 'נסו בעצמכם';

  @override
  String get testIn10 => 'שעון מעורר לבדיקה בעוד 10 שניות';

  @override
  String get testIn10Hint =>
      'מצלצל כמו שעון מעורר אמיתי. נעלו קודם את הטלפון כדי לראות את מסך השעון המעורר.';

  @override
  String get testStarted => 'שעון מעורר לבדיקה יצלצל בעוד 10 שניות.';

  @override
  String get restartTest => 'בדיקת הפעלה מחדש';

  @override
  String get restartTestHint =>
      'מגדיר שעון מעורר לבדיקה בעוד 3 דקות. הפעילו את הטלפון מחדש והשאירו אותו נעול. השעון המעורר אמור לצלצל בכל זאת.';

  @override
  String get restartTestStarted =>
      'שעון מעורר לבדיקה יצלצל בעוד 3 דקות. הפעילו עכשיו את הטלפון מחדש ואל תפתחו אותו.';

  @override
  String alarmsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'נוספו $count שעונים מעוררים מהחשבון. הם כבויים בטלפון הזה עד שתפעילו אותם.',
      one: 'נוסף שעון מעורר אחד מהחשבון. הוא כבוי בטלפון הזה עד שתפעילו אותו.',
    );
    return '$_temp0';
  }

  @override
  String get date => 'תאריך';

  @override
  String get sound => 'צליל';

  @override
  String get soundChime => 'צלצול ZT';

  @override
  String get soundSystem => 'צליל השעון המעורר של הטלפון';

  @override
  String get soundRingtone => 'בחירת צליל מהטלפון';

  @override
  String get soundFile => 'בחירת קובץ שמע';

  @override
  String get soundPicked => 'צליל שנבחר';

  @override
  String get soundHint =>
      'צליל שבוחרים מועתק לאפליקציה, כך שהוא מתנגן גם לפני שהטלפון נפתח בפעם הראשונה. אם אי אפשר לנגן אותו, יצלצל צלצול ZT.';

  @override
  String get gradual => 'עוצמה עולה בהדרגה';

  @override
  String get gradualHint => 'מתחיל בשקט ומגיע לעוצמה מלאה תוך דקה';

  @override
  String get silenceAfter => 'השתקה אחרי';

  @override
  String get pauseUntil => 'השהיה עד…';

  @override
  String get pauseUntilHelp => 'שקט עד סוף היום הזה';

  @override
  String pausedUntil(String day) {
    return 'מושהה עד $day';
  }

  @override
  String get resume => 'חידוש';

  @override
  String get pauseAll => 'השהיית כל השעונים המעוררים עד…';

  @override
  String get resumeAll => 'חידוש כל השעונים המעוררים';

  @override
  String pausedAllUntil(String day) {
    return 'השעונים המעוררים החוזרים מושהים עד סוף $day. שעונים מעוררים ליום אחד עדיין יצלצלו.';
  }

  @override
  String get timers => 'טיימרים';

  @override
  String get stopwatch => 'שעון עצר';

  @override
  String get addTimer => 'הוספת טיימר';

  @override
  String get start => 'התחלה';

  @override
  String get pause => 'השהיה';

  @override
  String get reset => 'איפוס';

  @override
  String get addMinute => '+1:00';

  @override
  String get stop => 'עצירה';

  @override
  String get timesUp => 'הזמן נגמר';

  @override
  String timerOf(String length) {
    return 'טיימר $length';
  }

  @override
  String get timerPaused => 'מושהה';

  @override
  String get timerLabel => 'תווית לטיימר';

  @override
  String get deleteTimer => 'מחיקת הטיימר';

  @override
  String get cancel => 'ביטול';

  @override
  String get quickTimers => 'טיימרים מהירים';

  @override
  String get saveQuickTimer => 'שמירה כטיימר מהיר';

  @override
  String get quickTimerSaved => 'נשמר כטיימר מהיר';

  @override
  String get quickTimerRemoved => 'הטיימר המהיר הוסר';

  @override
  String get quickTimersHint =>
      'הקשה מתחילה טיימר. אפשר להסיר טיימר ששמרתם עם ×.';

  @override
  String get hoursUnit => 'ש׳';

  @override
  String get minutesUnit => 'ד׳';

  @override
  String get secondsUnit => 'שנ׳';

  @override
  String get deleteDigit => 'מחיקת ספרה';

  @override
  String get lap => 'הקפה';

  @override
  String lapNumber(int number) {
    return 'הקפה $number';
  }

  @override
  String get copyLaps => 'העתקת ההקפות';

  @override
  String get lapsCopied => 'ההקפות הועתקו';

  @override
  String get timerStarted => 'הטיימר התחיל';

  @override
  String get clock => 'שעון';

  @override
  String get addCity => 'הוספת עיר';

  @override
  String get searchCities => 'חיפוש עיר או מדינה';

  @override
  String get noCities => 'עדיין אין ערים';

  @override
  String get noCitiesHint => 'הוסיפו עיר כדי לראות את השעה בה לצד השעה שלכם.';

  @override
  String cityRemoved(String city) {
    return '$city הוסרה';
  }

  @override
  String get remove => 'הסרה';

  @override
  String get yesterday => 'אתמול';

  @override
  String get sameTime => 'אותה שעה';

  @override
  String timeAhead(String time) {
    return '$time קדימה';
  }

  @override
  String timeBehind(String time) {
    return '$time אחורה';
  }

  @override
  String hoursOnly(int hours) {
    return '$hours שע׳';
  }

  @override
  String hoursAndMinutes(int hours, int minutes) {
    return '$hours שע׳ $minutes דק׳';
  }

  @override
  String dayAndDifference(String day, String difference) {
    return '$day, $difference';
  }

  @override
  String get noCityFound => 'לא נמצאה עיר';

  @override
  String get dragToReorder => 'לחיצה ארוכה לשינוי הסדר, החלקה להסרה.';

  @override
  String homeIn(String city) {
    return 'בבית: $city';
  }

  @override
  String get homeTimeZone => 'אזור הזמן של הבית';

  @override
  String get homeTimeZoneOff => 'כבוי';

  @override
  String homeTimeZoneOn(String city) {
    return '$city. השעה שם מוצגת בלשונית השעון כשהטלפון באזור זמן אחר.';
  }

  @override
  String homeHere(String city) {
    return 'אזור הזמן של הטלפון עכשיו ($city)';
  }

  @override
  String get homePickCity => 'בחירת עיר';

  @override
  String get homeTimeZoneAbout =>
      'כשנוסעים והטלפון עובר לאזור זמן אחר, לשונית השעון מציגה גם את השעה בבית. בבית לא מתווסף כלום.';

  @override
  String get bedtime => 'שינה';

  @override
  String get bedtimeSchedule => 'לוח זמני שינה';

  @override
  String get bedtimeScheduleHint => 'תזכורת לפני השינה, ושקט לאורך הלילה.';

  @override
  String get bedtimeStart => 'שעת שינה';

  @override
  String get wakeUp => 'השכמה';

  @override
  String sleepFor(String length) {
    return '$length שינה';
  }

  @override
  String get nights => 'לילות';

  @override
  String get reminder => 'תזכורת';

  @override
  String get off => 'כבוי';

  @override
  String get doNotDisturbAtBedtime => 'נא לא להפריע בשעת השינה';

  @override
  String get doNotDisturbHint =>
      'משתיק שיחות והתראות לאורך הלילה. שעונים מעוררים עדיין מצלצלים.';

  @override
  String get dndNeedsAccess => 'נדרשת הרשאת נא לא להפריע בהגדרות של Android.';

  @override
  String get allow => 'מתן הרשאה';

  @override
  String get wakeUpAlarm => 'שעון מעורר להשכמה';

  @override
  String wakeUpAlarmHint(String time) {
    return 'שעון מעורר ב-$time בבקרים שאחרי הלילות שבחרתם.';
  }

  @override
  String get sunrise => 'זריחה לפני השעון המעורר';

  @override
  String sunriseHint(int minutes) {
    return 'המסך מתבהר לאט במשך $minutes דקות לפני שעון ההשכמה. לא כשאתם כבר משתמשים בטלפון.';
  }

  @override
  String get sunriseNeedsAlarm => 'נדרש שעון מעורר להשכמה.';

  @override
  String get saveSleep => 'שמירת השינה ב-Health Connect';

  @override
  String get saveSleepHint =>
      'כל לילה נשמר כשינה, משעת השינה ועד שמכבים את שעון ההשכמה. אפליקציות שתאשרו ב-Health Connect יוכלו לקרוא אותו. לא מגובה.';

  @override
  String get saveSleepNotAllowed =>
      'ל-ZT Clock אין הרשאה לשמור שינה ב-Health Connect.';

  @override
  String get saveSleepNeedsAccess => 'נדרשת הרשאה לכתוב שינה ב-Health Connect.';

  @override
  String get sleepSounds => 'צלילי שינה';

  @override
  String get sleepSoundsHint =>
      'נוצרים בטלפון, בעוצמת המדיה. נחלשים בהדרגה בסוף.';

  @override
  String get soundWhite => 'רעש לבן';

  @override
  String get soundPink => 'רעש ורוד';

  @override
  String get soundDeep => 'רעש עמוק';

  @override
  String get stopAfter => 'עצירה אחרי';

  @override
  String get play => 'הפעלה';

  @override
  String stopsAt(String time) {
    return 'מתנגן עד $time';
  }

  @override
  String get wakeTask => 'משימת השכמה';

  @override
  String get wakeTaskHint =>
      'צריך לבצע אותה לפני שאפשר לכבות את השעון. נודניק עדיין עובד.';

  @override
  String get wakeTaskNone => 'בלי';

  @override
  String get wakeTaskMath => '3 תרגילי חשבון';

  @override
  String get wakeTaskShake => 'לנער 30 פעמים';

  @override
  String get screensaver => 'שומר מסך של שעון לילה';

  @override
  String get screensaverHint =>
      'מציג את השעה ואת השעון המעורר הבא בזמן טעינה. בוחרים \"שעון לילה\" בהגדרות שומר המסך של Android.';

  @override
  String get screensaverNight => 'אדום עמום';

  @override
  String get screensaverNightHint => 'נעים לעיניים בחדר חשוך';

  @override
  String get publicHolidays => 'חגים';

  @override
  String get publicHolidaysHint =>
      'ימים שבהם שעונים עם \"דילוג על חגים\" לא מצלצלים';

  @override
  String get holidayCalendar => 'לוח חגים';

  @override
  String get noHolidays => 'בלי';

  @override
  String get holidaysPrivacy =>
      'מורד מלוחות החגים הציבוריים של Google, כמו כל דף אינטרנט. לא נעשה שימוש בחשבון ושום דבר עליכם לא נשלח.';

  @override
  String get holidaysDownloading => 'מוריד…';

  @override
  String get holidaysFailed => 'ההורדה נכשלה. הרשימה האחרונה עדיין בתוקף.';

  @override
  String holidaysUpdated(String date) {
    return 'עודכן ב-$date';
  }

  @override
  String get refresh => 'רענון';

  @override
  String get holidaysTickedHint =>
      'ימי החופש מסומנים. מבטלים את הסימון בכל יום שבו השעונים צריכים לצלצל.';

  @override
  String get holidaysTickHint =>
      'מסמנים את הימים שבהם השעונים ידלגו. הלוח הזה לא מציין אילו ימים הם ימי חופש.';

  @override
  String get skipHolidays => 'דילוג על חגים';

  @override
  String get skipHolidaysPick => 'קודם בוחרים לוח חגים';

  @override
  String get logToTime => 'רישום ב-ZT Time';

  @override
  String logToTimeSpan(String start, String end, String length) {
    return '$start עד $end ($length)';
  }

  @override
  String get whatWasIt => 'על מה עבדת?';

  @override
  String get project => 'פרויקט';

  @override
  String get noProject => 'בלי פרויקט';

  @override
  String get logIt => 'רישום';

  @override
  String get loggedToTime => 'נרשם ב-ZT Time';

  @override
  String get couldNotLog => 'לא הצלחנו לרשום. כדאי לבדוק את החיבור ולנסות שוב.';

  @override
  String get offlineEdition => 'מהדורה לא מקוונת';

  @override
  String get offlineEditionHint =>
      'בלי הרשאת אינטרנט. בלי חשבון, בלי סנכרון ובלי הורדות: שום דבר לא יוצא מהטלפון הזה.';

  @override
  String get soundBells => 'פעמונים';

  @override
  String get soundBeeps => 'צפצופים';

  @override
  String get soundSunrise => 'זריחה';

  @override
  String get soundBuzzer => 'זמזם';

  @override
  String get wakeTaskScan => 'סריקת קוד';

  @override
  String get wakeTaskScanSaved => 'הקוד נשמר';

  @override
  String get wakeTaskScanHint =>
      'כדי לכבות סורקים את אותו קוד QR או ברקוד. כדאי שיהיה רחוק מהמיטה. אם אי אפשר להשתמש במצלמה, השעון יבקש תרגילי חשבון.';

  @override
  String get wakeTaskScanAgain => 'סריקת קוד אחר';

  @override
  String get wakeTaskScanNone => 'לא נסרק קוד';

  @override
  String get volumeButtons => 'כפתורי עוצמת הקול';

  @override
  String get volumeButtonsVolume => 'שינוי עוצמת הקול';

  @override
  String get volumeButtonsAbout =>
      'מה עושים כפתורי עוצמת הקול כששעון מעורר מצלצל על המסך שלו. משימת השכמה עדיין נדרשת.';

  @override
  String get minVolume => 'לצלצל לפחות בעוצמה הזו';

  @override
  String get minVolumeOff => 'כבוי: עוצמת השעון המעורר של הטלפון';

  @override
  String minVolumePercent(int percent) {
    return '$percent% מהעוצמה המרבית';
  }

  @override
  String get minVolumeAbout =>
      'אם עוצמת השעון המעורר בטלפון נמוכה יותר, היא מוגברת בזמן הצלצול ומוחזרת אחריו. טיימרים לא משתנים.';

  @override
  String get repeatWeekdays => 'ימים בשבוע';

  @override
  String get repeatShifts => 'סבב משמרות';

  @override
  String shiftText(int on, int length) {
    return 'משמרות: $on מכל $length ימים';
  }

  @override
  String get shiftLength => 'ימים בסבב';

  @override
  String get shiftStart => 'יום 1 בסבב';

  @override
  String get shiftDaysHint =>
      'הקישו על הימים בסבב שבהם השעון מצלצל. הסבב חוזר מיום 1 שוב ושוב.';

  @override
  String shiftDay(int day) {
    return 'יום $day';
  }

  @override
  String shiftOnOff(int on, int off) {
    return '$on עבודה, $off חופש';
  }

  @override
  String get shiftTwoShiftsHint =>
      'שתי משמרות בשעות שונות, כמו 2 בוקר, 2 לילה, 4 חופש? צרו שעון מעורר לכל אחת, עם אותו יום 1.';

  @override
  String shiftToday(int day, int length) {
    return 'היום הוא יום $day מתוך $length';
  }

  @override
  String get calendarLink => 'לפי ZT Calendar';

  @override
  String get calendarLinkHint =>
      'מצלצל בזמן לאירוע הראשון של היום. ‏ZT Clock קורא את ZT Calendar בכל פעם שהוא נפתח, שבועיים קדימה; בימים שלא נקראו השעון מצלצל בשעה שלו.';

  @override
  String get calendarNeedsAccount => 'התחברו כדי לעקוב אחרי ZT Calendar.';

  @override
  String get calendarNeedsRepeat => 'בחרו קודם ימים חוזרים או סבב משמרות.';

  @override
  String get calendarLead => 'לפני האירוע הראשון';

  @override
  String get calendarEarlier => 'מוקדם יותר כשצריך';

  @override
  String calendarEarlierHint(String time) {
    return 'מצלצל ב־$time, או מוקדם יותר כשהאירוע הראשון דורש.';
  }

  @override
  String get calendarFollow => 'תמיד לפני האירוע הראשון';

  @override
  String calendarFollowHint(String time) {
    return 'מצלצל לפני האירוע הראשון, גם אחרי $time. בלי אירועים: $time.';
  }

  @override
  String get calendarEarliest => 'אף פעם לא לפני';

  @override
  String get calendarOtherDays => 'גם בימים אחרים, לאירוע בבוקר';

  @override
  String get calendarLinkedShort => 'לפי ZT Calendar';

  @override
  String get smartWake => 'חלון השכמה חכמה';

  @override
  String get smartWakeHint =>
      'כשהטלפון על המיטה, הוא מצלצל עד כדי כך מוקדם יותר כשאתם זזים, כדי שתתעוררו בשינה קלה. בלי תנועה הוא מצלצל בזמן.';

  @override
  String get smartWakeOff => 'כבוי';

  @override
  String get morningScreen => 'אחרי סגירת שעון מעורר';

  @override
  String get morningOff => 'שום דבר';

  @override
  String get morningCounts => 'היום שלפניכם, מספרים בלבד';

  @override
  String get morningDetails => 'היום שלפניכם, עם שמות';

  @override
  String get morningHint =>
      'האירועים של היום מ־ZT Calendar, המשימות מ־ZT Tasks וה־Quests מ־ZT Quests, כפי ש־ZT Clock קרא אותם לאחרונה (כשמחוברים). השמות מוצגים גם מעל מסך הנעילה.';

  @override
  String questGoal(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'fitness': 'כושר',
      'productivity': 'פרודוקטיביות',
      'nutrition': 'תזונה',
      'sleep': 'שינה',
      'learning': 'למידה',
      'mindfulness': 'מיינדפולנס',
      'other': 'מטרה',
    });
    return '$_temp0';
  }
}
