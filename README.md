# Zero-Trust Clock

Alarms that ring, with **Turn off once** (on the phone: **ZT Clock**), plus
timers, a stopwatch, a world clock and bedtime. Same settings and look as
the other Zero-Trust apps, built on
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core).

Work happens on the `Dev` branch; `main` holds releases.

## What is in it now (0.7.0)

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
- **Pause until** a date (a repeating alarm is silent through that day and
  on again after it, by itself), and **Pause all alarms until** for a trip
  (repeating alarms only; one set for a single day still rings).
- **Alarm on a date**: an alarm without repeat days can ring on a picked day.
- **Sounds**: the app's chime, the phone's alarm sound, a phone sound or any
  audio file. A picked sound is copied into the app, so it plays before the
  first unlock too; if it can't play, the chime rings, never silence.
- **Gradually louder** and **Silence after** (1 to 30 minutes), per alarm.
- **Slide to dismiss** on the ring screen, so a sleepy tap can't silence it.
- **"Set an alarm for 7"** from assistants and other apps (Android's
  standard alarm request).
- **Upcoming alarm notification**, from two hours before a ring, with
  **Turn off once** (or **Dismiss** on an alarm that rings once). Silent,
  and the label is not shown on the lock screen.
- **Timers.** Several at once, each with a label, Pause, +1:00 and Reset.
  Type a length on the keypad or tap a quick timer (1, 3, 5, 10, 15, 30
  minutes, plus your own). Timers run and ring in the engine, so they ring
  with the app closed; each has a notification counting down with its
  buttons, and "Time's up" opens over the lock screen.
- **Stopwatch** with laps (newest on top, fastest and slowest marked) and
  "Copy laps". It keeps counting with the app closed, in a notification
  with Pause and Lap.
- **"Set a timer for 5 minutes"** from assistants and other apps.
- **World clock** (Clock tab): the time here, then your cities with their
  time, day and distance ("Tomorrow, 7 h ahead"). Every city Android knows,
  named in the app's language, found by city or country, offline. Long-press
  to reorder, swipe to remove (with Undo).
- **Quick Settings tiles**: Next alarm (opens the alarms) and Stopwatch
  (starts and pauses it).
- **Home screen widgets**, in the shared Zero-Trust widget look: Clock and
  next alarm (with Turn off once, and + for a new alarm), World clock (the
  first four cities of the Clock tab, each with a live time) and an Analog
  clock. No alarm labels on the home screen.
- **Bedtime** tab: when your nights start and end and which nights, with
  the length of sleep. A reminder before bed (15, 30 or 60 minutes), Do Not
  Disturb through the night (alarms still ring; it is only turned off again
  if the app turned it on), and a wake-up alarm on the mornings after your
  nights that follows the schedule when you change it.
- **Sleep sounds**: white, pink or deep noise made on the phone (no files,
  no network), with a sleep timer and a 30-second fade-out.
- **Shortcuts** on the app icon (long-press): New alarm, New timer, Start
  stopwatch.
- **No account needed.** Alarms stay on the phone and ring without one.
- **Optional sign-in** (Settings > Sign in or create an account) adds
  end-to-end encrypted backup and sync through the shared Zero-Trust
  account. An alarm arrives switched **off** on another phone until it is
  switched on there: each phone has its own switch. Edits (time, days,
  label, Turn off once) sync; the newer edit wins. Like every Zero-Trust
  app, a signed-in Clock asks to unlock after a restart or auto-lock; the
  alarms ring either way.
- English and Hebrew, also on the ring screen and in notifications.

## How it is built

| Part | Where | What it does |
| --- | --- | --- |
| Scheduler | `android/.../engine/core` | Plain Kotlin, no Android: when an alarm rings next (repeat days, Turn off once, snooze, clock and time zone changes), what each timer and stopwatch button does. Unit tested. |
| Engine | `android/.../engine` | Stores the alarms, hands them to Android (`setAlarmClock`), rings them (sound, vibration, ring screen), sets them again after a restart. Timers (`TimerEngine`, exact AlarmManager wake-ups) and the stopwatch live here too, with their notifications. |
| Bridge | `android/.../EngineBridge.kt`, `lib/engine` | How the screens talk to the engine. |
| Screens | `lib/ui` | Flutter, on the shared core: Alarms, Clock, Timers and Stopwatch tabs, alarm editor, Alarm check, settings. |
| Sync | `lib/sync` | Compares the engine's alarms with the account's encrypted copy (`app = 'clock'`, `kind = 'alarm'`) and hands each side the other's newer edits. |
| Account | `lib/app` | Optional sign-in, unlock, password-reset links (`zerotrust.bz/auth/clock/`). |

The engine is the only thing that decides when an alarm rings; the screens
show what it reports. That is why it does not need Flutter, the account or
an unlocked phone to ring.

Where things are kept on the phone:

- Alarm times and days: device-protected storage, readable before the first
  unlock, so alarms can be set again right after a restart.
- Timers (with their labels) and the stopwatch: device-protected storage,
  so a timer that ends before the first unlock still rings. Timer labels
  stay off the lock screen.
- Alarm labels: the normal encrypted storage. A label is not readable, and not
  shown, until the phone has been unlocked.

## Testing on a phone

1. Settings > Alarm check: fix anything marked.
2. "Test alarm in 10 seconds", once with the phone unlocked and once after
   locking it.
3. "Restart test": restart the phone, do not unlock it, and wait for the
   alarm (3 minutes after you tapped).
4. Set a repeating alarm a few minutes ahead, choose "Turn off once" and
   check it stays silent and shows the next day.
5. Set an alarm less than two hours ahead: the "Upcoming alarm"
   notification appears; its button skips that ring.
6. Sign in from Settings on two phones: an alarm made on one arrives on
   the other switched off; switching it on there leaves the first as it
   was; a time change on either reaches the other.
7. Timers tab: start a 1-minute timer, lock the phone and wait for
   "Time's up" over the lock screen; try +1:00 and Stop there. Start two
   timers and pause one from its notification.
8. "Hey Google, set a timer for 2 minutes": it starts in ZT Clock.
9. Stopwatch: start, take laps, close the app (swipe it away), wait, open
   it again from the notification: the time kept going.
10. Clock tab: add Tokyo and New York; switch the app to Hebrew and check
    the names follow.
11. Add the Next alarm and Stopwatch tiles to Quick Settings; long-press the
    app icon for the shortcuts.
12. Add the three widgets; tap Turn off once on the Clock widget and check
    the alarm list; add a city and check the World clock widget.
13. Bedtime tab: switch the schedule on with bedtime 16 minutes ahead and
    the 15-minute reminder, and wait for the reminder. Switch on Do Not
    Disturb, allow the access, and check it turns on at bedtime and off at
    wake-up. Switch on the wake-up alarm and find it on the Alarms tab.
14. Sleep sounds: play each for 15 minutes with the phone locked; the
    sound fades out and stops.

## Development

```
flutter pub get
flutter analyze
flutter test test/
cd android && ./gradlew :app:testDebugUnitTest   # the scheduler's tests
```

Flutter 3.47.9 (the suite's pinned version). Strings are in
`lib/l10n/app_en.arb` and `app_he.arb`; the native ring screen and
notifications keep theirs in `android/app/src/main/res/values*/strings.xml`.
The launcher icons are drawn from the suite's brand mark with
`flutter test tool/launcher_icon_test.dart`.

The Google Play listing (English and Hebrew: title, descriptions, icon,
feature graphic, release notes) is in `fastlane/metadata/android/`. A push
to `main` also builds the `.aab` that Play takes. Phone screenshots still
need to be added under `images/phoneScreenshots/`.

Licence: AGPL-3.0 (see `LICENSE`).
