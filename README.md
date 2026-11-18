# Zero-Trust Clock

Alarms that ring, with **Turn off once** (on the phone: **ZT Clock**).
Timer, stopwatch, world clock and bedtime follow. Same settings and look as
the other Zero-Trust apps, built on
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core).

Work happens on the `Dev` branch; `main` holds releases.

## What is in it now (0.1.0)

- **Alarms.** Add one with +, pick repeat days, a label, vibration and the
  snooze length. The switch turns an alarm off for good.
- **Turn off once.** In an alarm's three-dot menu: the next ring is skipped
  and the alarm is on again by itself. The card says "Off once. Next: ..."
  and "Turn back on" undoes it. Switching an alarm off also offers
  "Just once". On an alarm that rings once, it moves the alarm one day.
- **Rings without the app.** The alarms live in a small native engine. They
  ring with the app closed, after a restart, and before the phone's first
  unlock (GrapheneOS restarts a phone left locked for 18 hours).
- **Alarm check** (Settings, or the warning on the home screen): everything
  on the phone that can stop an alarm, each with a Fix button, a test alarm
  in 10 seconds and a restart test.
- **No account needed.** Alarms stay on the phone. Sign-in for backup and
  sync comes later.
- English and Hebrew, also on the ring screen and in notifications.

## How it is built

| Part | Where | What it does |
| --- | --- | --- |
| Scheduler | `android/.../engine/core` | Plain Kotlin, no Android: when an alarm rings next (repeat days, Turn off once, snooze, clock and time zone changes). Unit tested. |
| Engine | `android/.../engine` | Stores the alarms, hands them to Android (`setAlarmClock`), rings them (sound, vibration, ring screen), sets them again after a restart. |
| Bridge | `android/.../EngineBridge.kt`, `lib/engine` | How the screens talk to the engine. |
| Screens | `lib/ui` | Flutter, on the shared core: alarm list, editor, Alarm check, settings. |

The engine is the only thing that decides when an alarm rings; the screens
show what it reports. That is why it does not need Flutter, the account or
an unlocked phone to ring.

Where things are kept on the phone:

- Alarm times and days: device-protected storage, readable before the first
  unlock, so alarms can be set again right after a restart.
- Labels: the normal encrypted storage. A label is not readable, and not
  shown, until the phone has been unlocked.

## Testing on a phone

1. Settings > Alarm check: fix anything marked.
2. "Test alarm in 10 seconds", once with the phone unlocked and once after
   locking it.
3. "Restart test": restart the phone, do not unlock it, and wait for the
   alarm (3 minutes after you tapped).
4. Set a repeating alarm a few minutes ahead, choose "Turn off once" and
   check it stays silent and shows the next day.

## Development

```
flutter pub get
flutter analyze
flutter test test/
cd android && ./gradlew :app:testReleaseUnitTest   # the scheduler's tests
```

Flutter 3.47.9 (the suite's pinned version). Strings are in
`lib/l10n/app_en.arb` and `app_he.arb`; the native ring screen and
notifications keep theirs in `android/app/src/main/res/values*/strings.xml`.
The launcher icons are drawn from the suite's brand mark with
`flutter test tool/launcher_icon_test.dart`.

Licence: AGPL-3.0 (see `LICENSE`).
