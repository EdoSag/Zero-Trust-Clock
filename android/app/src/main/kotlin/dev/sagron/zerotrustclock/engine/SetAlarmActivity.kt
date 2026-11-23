package dev.sagron.zerotrustclock.engine

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.provider.AlarmClock
import android.widget.Toast
import dev.sagron.zerotrustclock.R
import java.util.Calendar

/**
 * Android's standard alarm and timer requests, from voice assistants and
 * other apps: "set an alarm for 7", "set a timer", "dismiss my alarm",
 * "snooze", "stop the timer". No screen of its own: it is done in the
 * engine at once, and the app opens unless the caller asked to skip it.
 * Callers need the SET_ALARM permission (manifest).
 */
class SetAlarmActivity : Activity() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(Loc.wrap(base))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            handle(intent)
        } catch (_: Exception) {
            open()
        }
        finish()
    }

    private fun handle(intent: Intent) {
        when (intent.action) {
            AlarmClock.ACTION_SET_ALARM -> setAlarm(intent)
            AlarmClock.ACTION_SET_TIMER -> setTimer(intent)
            AlarmClock.ACTION_SHOW_TIMERS -> open(Tabs.TIMERS)
            AlarmClock.ACTION_DISMISS_ALARM -> dismissAlarm()
            AlarmClock.ACTION_SNOOZE_ALARM -> snoozeAlarm(intent)
            AlarmClock.ACTION_DISMISS_TIMER -> dismissTimer()
            else -> open()
        }
    }

    private fun setAlarm(intent: Intent) {
        if (!intent.hasExtra(AlarmClock.EXTRA_HOUR)) {
            // No time given: the app, to pick one there.
            open()
            return
        }
        val hour = intent.getIntExtra(AlarmClock.EXTRA_HOUR, 0).coerceIn(0, 23)
        val minute = intent.getIntExtra(AlarmClock.EXTRA_MINUTES, 0).coerceIn(0, 59)
        val days = (intent.getIntegerArrayListExtra(AlarmClock.EXTRA_DAYS) ?: arrayListOf())
            .mapNotNull { isoDay(it) }.toSet()
        val label = intent.getStringExtra(AlarmClock.EXTRA_MESSAGE)?.take(60) ?: ""
        val vibrate = intent.getBooleanExtra(AlarmClock.EXTRA_VIBRATE, true)
        // The same alarm already there: switched on rather than a second one.
        val existing = AlarmStore.load(this).firstOrNull {
            !it.test && it.cycle == null && it.hour == hour && it.minute == minute && it.days == days
        }
        if (existing != null) {
            if (!existing.enabled) AlarmEngine.setEnabled(this, existing.id, true)
        } else {
            AlarmEngine.save(this, null, hour, minute, days, AlarmEngine.Options(label = label, vibrate = vibrate))
        }
        Toast.makeText(
            this,
            getString(R.string.alarm_set_for, AlarmNotifications.timeText(this, hour, minute)),
            Toast.LENGTH_SHORT,
        ).show()
        if (!intent.getBooleanExtra(AlarmClock.EXTRA_SKIP_UI, false)) open()
    }

    /** "Set a timer for 5 minutes": started at once. */
    private fun setTimer(intent: Intent) {
        val seconds = intent.getIntExtra(AlarmClock.EXTRA_LENGTH, 0)
        if (seconds <= 0) {
            // No length given: the app, to pick one there.
            open(Tabs.TIMERS)
            return
        }
        val label = intent.getStringExtra(AlarmClock.EXTRA_MESSAGE)?.take(60) ?: ""
        TimerEngine.add(this, seconds * 1000L, label, start = true)
        Toast.makeText(
            this,
            getString(R.string.timer_set_for, TimerNotifications.durationText(seconds * 1000L)),
            Toast.LENGTH_SHORT,
        ).show()
        if (!intent.getBooleanExtra(AlarmClock.EXTRA_SKIP_UI, false)) open(Tabs.TIMERS)
    }

    /**
     * "Dismiss my alarm": the ringing alarm, else the snoozed ones. An
     * alarm with a wake-up task still asks for it (the ring screen opens
     * on the task). With nothing ringing or snoozed the app opens: which
     * coming alarm to skip is picked there, never guessed from a voice.
     */
    private fun dismissAlarm() {
        if (RingService.ringingId != null) {
            RingService.send(this, RingService.ACTION_DISMISS)
            return
        }
        val snoozed = AlarmStore.load(this).filter { it.snoozeUntil != null }
        if (snoozed.isNotEmpty()) {
            snoozed.forEach { AlarmEngine.cancelSnooze(this, it.id) }
            toast(R.string.snooze_ended)
            return
        }
        toast(R.string.no_alarm_ringing)
        open()
    }

    /** "Snooze": the ringing alarm, for its own snooze length or the one asked for. */
    private fun snoozeAlarm(intent: Intent) {
        if (RingService.ringingId == null) {
            toast(R.string.no_alarm_ringing)
            return
        }
        val minutes = intent.getIntExtra(AlarmClock.EXTRA_ALARM_SNOOZE_DURATION, 0)
        RingService.send(this, RingService.ACTION_SNOOZE, minutes = minutes.coerceIn(0, 60))
    }

    /** "Stop the timer": every ringing timer. */
    private fun dismissTimer() {
        if (TimerStore.load(this).any { it.ringing }) {
            TimerEngine.stopRinging(this)
        } else {
            toast(R.string.no_timer_ringing)
            open(Tabs.TIMERS)
        }
    }

    private fun toast(text: Int) = Toast.makeText(this, getString(text), Toast.LENGTH_SHORT).show()

    private fun open(tab: String = Tabs.ALARMS) {
        try {
            startActivity(Tabs.intent(this, tab))
        } catch (_: Exception) {
        }
    }

    /** Calendar's SUNDAY = 1 .. SATURDAY = 7, as ISO 1 = Monday .. 7 = Sunday. */
    private fun isoDay(calendarDay: Int): Int? = when (calendarDay) {
        Calendar.SUNDAY -> 7
        in Calendar.MONDAY..Calendar.SATURDAY -> calendarDay - 1
        else -> null
    }
}
