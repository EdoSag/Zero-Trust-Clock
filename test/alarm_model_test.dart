import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_clock/engine/alarm.dart';

void main() {
  test('reads the engine list, earliest time of day first', () {
    final next = DateTime(2026, 11, 19, 7).millisecondsSinceEpoch;
    final list = ClockAlarm.listFromJson('''
[
  {"id":"b","hour":22,"minute":30,"days":[],"enabled":false,"label":""},
  {"id":"a","hour":7,"minute":0,"days":[7,1,2,3,4],"enabled":true,
   "label":"Work","vibrate":false,"snoozeMinutes":5,"nextRing":$next,
   "skipActive":true,"ringing":false,"snoozeUntil":null,"date":null},
  {"id":"c","hour":7,"minute":0,"days":[9,"x",6]}
]''');
    expect(list.map((a) => a.id), ['a', 'c', 'b']);

    final a = list.first;
    expect(a.days, {1, 2, 3, 4, 7});
    expect(a.repeats, isTrue);
    expect(a.label, 'Work');
    expect(a.vibrate, isFalse);
    expect(a.snoozeMinutes, 5);
    expect(a.nextRing, DateTime(2026, 11, 19, 7));
    expect(a.skipActive, isTrue);
    expect(a.snoozeUntil, isNull);

    // Missing fields fall back, and day numbers outside 1..7 are dropped.
    final c = list[1];
    expect(c.days, {6});
    expect(c.enabled, isTrue);
    expect(c.vibrate, isTrue);
    expect(c.snoozeMinutes, 10);
    expect(c.nextRing, isNull);

    expect(list.last.repeats, isFalse);
    expect(list.last.enabled, isFalse);
  });

  test('alarm check counts what needs attention', () {
    expect(const AlarmCheck().problems, 0);
    expect(AlarmCheck.fromMap(const {}).problems, 0);

    final check = AlarmCheck.fromMap({
      'notifications': false,
      // Unreadable while notifications are off: not counted twice.
      'ringChannel': false,
      'fullScreen': false,
      'exactAlarms': true,
      'alarmVolume': 0,
      'alarmVolumeMax': 7,
      'totalSilence': true,
      'ownerProfile': false,
      'bootAt': DateTime(2026, 11, 18, 3).millisecondsSinceEpoch,
      'bootLocked': true,
    });
    expect(check.problems, 5);
    expect(check.volumeZero, isTrue);
    expect(check.bootAt, DateTime(2026, 11, 18, 3));
    expect(check.bootLocked, isTrue);

    expect(AlarmCheck.fromMap({'bootAt': 0}).bootAt, isNull);
    expect(
      const AlarmCheck(notifications: true, ringChannel: false).problems,
      1,
    );
  });
}
