# Zero-Trust Clock

Alarms that ring, with **Turn off once** (on the phone: **ZT Clock**), plus
timers, a stopwatch, a world clock and bedtime. Same settings and look as
the other Zero-Trust apps, built on
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core).

Work happens on the `Dev` branch; `main` holds releases.

## What is in it now (0.16.0)

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
- **Sounds**: five of the app's own (ZT chime, Bells, Beeps, Sunrise and
  Buzzer, each with a button to hear it), the phone's alarm sound, a phone
  sound or any audio file. A picked sound is copied into the app, so it
  plays before the first unlock too; if it can't play, the chime rings,
  never silence. The app's sounds are made by `tool/make_alarm_sounds.py`.
- **Gradually louder** and **Silence after** (1 to 30 minutes), per alarm.
- **Ring at least this loud** (Settings; off, 30, 50, 70 or 100%): if the
  phone's alarm volume is lower, it is raised while an alarm rings and put
  back afterwards. Timers are not changed.
- **Slide to dismiss** on the ring screen, so a sleepy tap can't silence it.
- **Volume buttons** (Settings): while an alarm rings on its screen they
  change the volume, snooze or dismiss. A wake-up task is still asked for.
- **From assistants and other apps** (Android's standard alarm requests):
  "set an alarm for 7", "snooze" (also "snooze for 5 minutes") and
  "dismiss my alarm". Dismiss ends the ringing alarm, or a snooze; an
  alarm with a wake-up task still asks for it. With nothing ringing the
  app opens: which coming alarm to skip is never guessed from a voice.
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
- **Log to ZT Time** (signed in): a paused stopwatch, or a timer that has
  just rung, becomes a time entry in ZT Time, ending now, with what it was
  and a project from ZT Time. It goes to the same account, end-to-end
  encrypted, and is pushed later if the phone is offline.
- **"Set a timer for 5 minutes"** and **"stop the timer"** from assistants
  and other apps.
- **World clock** (Clock tab): the time here, then your cities with their
  time, day and distance ("Tomorrow, 7 h ahead"). Every city Android knows,
  named in the app's language, found by city or country, offline. Long-press
  to reorder, swipe to remove (with Undo).
- **Quick Settings tiles**: Next alarm (opens the alarms), Timer (says
  when the next timer ends; a tap opens the keypad for a new one, or the
  timers when one is going) and Stopwatch (starts and pauses it).
- **Home screen widgets**, in the shared Zero-Trust widget look: Clock and
  next alarm (with Turn off once, and + for a new alarm), World clock (the
  first four cities of the Clock tab, each with a live time), an Analog
  clock, Timer (the timer that ends next, counting down, with Pause, +1:00,
  Resume, Reset or Stop; with no timer, 1:00, 5:00 and 10:00 start one with
  a tap) and Stopwatch (counting, with Start, Pause, Lap and Reset). No
  alarm or timer labels on the home screen.
- **Live status on Android 16**: a running timer or the stopwatch counts in
  a chip in the status bar, and can be switched off in Android's
  notification settings for the app.
- **Skip public holidays** (repeating alarms): pick a holiday calendar in
  Settings > Public holidays (the same public calendars as ZT Calendar,
  downloaded with no account and refreshed weekly). Days off are ticked;
  untick any day an alarm should still ring on. A calendar that doesn't
  mark days off skips nothing until you tick days. This phone only.
- **Wake-up tasks** (in an alarm's editor): solve 3 sums, shake the
  phone 30 times or scan a code before the alarm can be dismissed, so it
  can't be silenced half asleep. Snooze still works, and Dismiss in the
  notification or the app opens the task on the ring screen.
- **Scan a code**: save any QR code or barcode that is away from the bed
  (the toothpaste, a note on the fridge); the alarm is dismissed by
  scanning the same one. Codes are read on the phone (ZXing, no Google
  services), no picture is kept, and only a hash of the code is stored, so
  what it says is never saved. It works over the lock screen and has a
  light for a dark room. If the camera can't be used (no permission, in
  use, broken), the alarm asks for sums instead, so it can always be
  dismissed. The saved code syncs with the alarm.
- **Bedtime** tab: when your nights start and end and which nights, with
  the length of sleep. A reminder before bed (15, 30 or 60 minutes), Do Not
  Disturb through the night (alarms still ring; it is only turned off again
  if the app turned it on), and a wake-up alarm on the mornings after your
  nights that follows the schedule when you change it.
- **Sunrise before the alarm** (Bedtime, off by default): for 15 minutes
  before the wake-up alarm the screen goes from dark red to warm white and
  gets brighter, over the lock screen, with no sound. It follows the
  alarm's real next ring, so a morning that is turned off once, paused or a
  holiday has none. It is not shown when the phone is already in use, and
  Close ends it for that morning.
- **Save sleep to Health Connect** (Bedtime, off by default, Android 14
  and later): each night is written as one sleep entry, from bedtime until
  the wake-up alarm is dismissed, or until the wake-up time when it did
  not ring. It is the schedule, not a measurement, and is marked as entered
  by hand. The app only writes sleep; it never reads health data, and the
  entries are not backed up or synced. A night that can't be written yet
  (phone locked after a restart) is written later.
- **Sleep sounds**: white, pink or deep noise made on the phone (no files,
  no network), with a sleep timer and a 30-second fade-out.
- **Night clock screensaver**: the time, date and next alarm on black
  while the phone charges, dim red by default, moving a little every
  minute so nothing burns in. Settings has a link to Android's screensaver
  settings and the dim red switch.
- **Shortcuts** on the app icon (long-press): New alarm, New timer, Start
  stopwatch.
- **No account needed.** Alarms stay on the phone and ring without one.
- **Optional sign-in** (Settings > Sign in or create an account) adds
  end-to-end encrypted backup and sync through the shared Zero-Trust
  account. An alarm arrives switched **off** on another phone until it is
  switched on there: each phone has its own switch. Edits (time, days,
  label, Turn off once) sync; the newer edit wins. The rest is backed up
  too, so a new phone looks like the old one: the world clock's cities
  (in order), saved quick timers, the bedtime schedule, the holiday
  calendar with its ticked days, and the night clock's dim red. For each
  the newer change wins; a phone that already has its own cities or quick
  timers keeps them next to the account's the first time. Whether bedtime
  is on, its Do Not Disturb, the sunrise and saving sleep stay each
  phone's own, like an alarm's switch. Like every Zero-Trust app, a signed-in Clock asks to unlock
  after a restart or auto-lock; the alarms ring either way.
- English and Hebrew, also on the ring screen and in notifications.
- **Offline edition** (`zero-trust-clock-offline-…apk` in each release):
  the same clock with no internet permission at all, so no account, no
  sync and no downloads (no holiday calendars, no Log to ZT Time). It is
  its own app, "ZT Clock Offline", and can sit next to the full one.
  Settings says which edition is installed.

## How it is built

| Part | Where | What it does |
| --- | --- | --- |
| Scheduler | `android/.../engine/core` | Plain Kotlin, no Android: when an alarm rings next (repeat days, Turn off once, snooze, clock and time zone changes), what each timer and stopwatch button does. Unit tested. |
| Engine | `android/.../engine` | Stores the alarms, hands them to Android (`setAlarmClock`), rings them (sound, vibration, ring screen), sets them again after a restart. Timers (`TimerEngine`, exact AlarmManager wake-ups) and the stopwatch live here too, with their notifications. |
| Bridge | `android/.../EngineBridge.kt`, `lib/engine` | How the screens talk to the engine. |
| Screens | `lib/ui` | Flutter, on the shared core: Alarms, Clock, Timers and Stopwatch tabs, alarm editor, Alarm check, settings. |
| Sync | `lib/sync` | Compares the engine's alarms with the account's encrypted copy (`app = 'clock'`, `kind = 'alarm'`) and hands each side the other's newer edits. The settings groups (`kind = 'settings'`, ids `settings-cities`, `-quick-timers`, `-bedtime`, `-holidays`, `-night-clock`) go the same way, newer change first. |
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
12. Add the five widgets; tap Turn off once on the Clock widget and check
    the alarm list; add a city and check the World clock widget. On the
    Timer widget tap 1:00, then Pause, Resume and +1:00, and let it ring:
    the widget says "Time's up" with Stop. On the Stopwatch widget tap
    Start, Lap, Pause and Reset. Restart the phone with a timer running:
    the widget counts on from the right time.
13. Bedtime tab: switch the schedule on with bedtime 16 minutes ahead and
    the 15-minute reminder, and wait for the reminder. Switch on Do Not
    Disturb, allow the access, and check it turns on at bedtime and off at
    wake-up. Switch on the wake-up alarm and find it on the Alarms tab.
14. Sleep sounds: play each for 15 minutes with the phone locked; the
    sound fades out and stops.
15. Give a test alarm "Solve 3 sums", then "Shake 30 times": slide to
    dismiss shows the task, a wrong answer gives a new sum, Snooze still
    works, and Dismiss in the notification opens the task.
16. Settings > Night clock screensaver: choose "Night clock", put the
    phone on the charger and let the screen time out.
17. Settings > Public holidays: pick Israel, check the list and that a
    weekday alarm with "Skip public holidays" shows the day after a
    holiday as its next ring.
18. Signed in, with a project in ZT Time: run the stopwatch, pause it, tap
    the clock-plus icon, pick the project and Log. Open ZT Time: the entry
    is there with that length. Do the same from a 1-minute timer when it
    rings.
19. Install the Offline APK next to the full one: it appears as "ZT Clock
    Offline", Android's app info shows no network permission, Settings has
    "Offline edition" and no sign-in, and a test alarm rings.
20. Signed in on two phones: add two cities and a quick timer on one,
    change the bedtime times and pick a holiday calendar. They appear on
    the other within a moment; bedtime arrives switched off there.
21. Android 16: start a timer and leave the app. Its time counts down in a
    chip in the status bar. Add the Timer tile to Quick Settings: it says
    "Until" and the end time.

22. Sounds: in an alarm's editor open Sound, play each of the five, pick
    Buzzer and ring a test alarm in Alarm check with that alarm's sound
    (or set the alarm a minute ahead).
23. Settings > Ring at least this loud > 70%. Turn the phone's alarm volume
    all the way down and let an alarm ring: it is loud, and after
    dismissing it the alarm volume is back down.
24. Settings > Volume buttons > Snooze. Let an alarm ring with the phone
    locked and press a volume button: it snoozes. Then Dismiss, with an
    alarm that has a wake-up task: the task opens.
25. Scan a code: in an alarm's editor pick Scan a code, allow the camera
    and scan a barcode twice in view. Let it ring with the phone locked,
    slide to dismiss: the camera opens over the lock screen; another code
    says "This is another code", the saved one dismisses. Try Light. Then
    take the camera permission away in Android's settings and let it ring
    again: it asks for sums.
26. With an alarm ringing say "snooze" and "dismiss my alarm" to the
    assistant; with a timer ringing, "stop the timer".
27. Sunrise: Bedtime > Wake-up alarm on > Sunrise before the alarm on. Set
    the wake-up time 17 minutes ahead, lock the phone and put it down. Two
    minutes later the screen lights up dark red over the lock screen and
    gets lighter and brighter; at the time the alarm's own screen takes
    over. Try again and press Close: it stays closed until the alarm. Try
    again with the phone in your hand and the screen on: no sunrise.
28. Save sleep (Android 14 and later): Bedtime > Save sleep to Health
    Connect > allow. With the schedule on, dismiss the wake-up alarm in
    the morning, then open Health Connect > Data and access > Sleep: one
    entry from bedtime to when you dismissed it, from ZT Clock. In Health
    Connect > App permissions > ZT Clock, the privacy link opens the app's
    own explanation.

## Development

```
flutter pub get
flutter analyze
flutter test test/
cd android && ./gradlew :app:testFullDebugUnitTest   # the scheduler's tests
```

Two editions are built from the one project (`android/app/build.gradle.kts`):
`flutter build apk --flavor full` (the default) and `--flavor offline`. The
Offline edition's manifest (`android/app/src/offline`) takes the INTERNET
permission out, `lib/app/edition.dart` hides what would need it, and CI
checks the built APK has no network permission.

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
