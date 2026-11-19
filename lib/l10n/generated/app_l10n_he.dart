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
}
