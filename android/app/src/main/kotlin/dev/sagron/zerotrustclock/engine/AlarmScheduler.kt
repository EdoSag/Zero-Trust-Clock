package dev.sagron.zerotrustclock.engine

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import dev.sagron.zerotrustclock.MainActivity
import dev.sagron.zerotrustclock.engine.core.Alarm
import dev.sagron.zerotrustclock.engine.core.AlarmSchedule
import java.time.ZoneId

/**
 * Hands every alarm's next ring to Android. Safe to call at any time and
 * as often as needed: after a change, after a restart (before unlock
 * too), after an update, and when the clock or time zone changes.
 */
object AlarmScheduler {
    const val ACTION_FIRE = "dev.sagron.zerotrustclock.action.FIRE"

    /** Told (on the main thread) whenever the alarms changed, while the app is open. */
    @Volatile
    var onChanged: (() -> Unit)? = null

    fun rescheduleAll(context: Context) {
        val nowMs = System.currentTimeMillis()
        val now = AlarmSchedule.at(nowMs, ZoneId.systemDefault())
        val ringing = RingService.ringingId
        val pauseAll = EnginePrefs.pauseAllUntil(context)
        val missed = ArrayList<Alarm>()
        val alarms = AlarmStore.update(context) { list ->
            val it = list.listIterator()
            while (it.hasNext()) {
                var a = it.next()
                if (a.id == ringing && !a.repeats) {
                    // Ringing right now: what happens next is decided when it ends.
                    continue
                }
                if (a.id != ringing && AlarmSchedule.wasMissed(a, nowMs)) {
                    missed.add(a)
                    if (a.test) {
                        cancel(context, a)
                        it.remove()
                        continue
                    }
                    a = AlarmSchedule.afterRing(a, now)
                }
                a = AlarmSchedule.tidy(a, now)
                val trigger = if (a.id != ringing && AlarmSchedule.dueNow(a, nowMs)) {
                    a.armedFor // Late, but recent enough: ring now.
                } else {
                    AlarmSchedule.nextTrigger(a, now, pauseAll)
                }
                if (trigger == null) {
                    cancel(context, a)
                    a = a.copy(armedFor = null)
                    // Rings once and its time is gone: it is off.
                    if (a.enabled && !a.repeats) a = AlarmSchedule.afterRing(a, now)
                } else {
                    arm(context, a, trigger)
                    a = a.copy(armedFor = trigger)
                }
                it.set(a)
            }
            list.toList()
        }
        try {
            UpcomingAlarms.refresh(context, alarms, now, pauseAll)
        } catch (_: Exception) {
            // Only the notification; the rings themselves are set.
        }
        for (a in missed) AlarmNotifications.showMissed(Loc.wrap(context), a)
        Tiles.refresh(context)
        Widgets.refresh(context)
        notifyChanged()
    }

    fun notifyChanged() {
        val listener = onChanged ?: return
        Handler(Looper.getMainLooper()).post { listener() }
    }

    private fun arm(context: Context, alarm: Alarm, triggerAt: Long) {
        val manager = context.getSystemService(AlarmManager::class.java) ?: return
        val fire = firePendingIntent(context, alarm)
        val show = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        try {
            // The API made for alarm clocks: exact, rings in Doze, and may
            // start the ring service from the background.
            manager.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAt, show), fire)
        } catch (_: SecurityException) {
            // Android 12 with "Alarms & reminders" switched off: best effort.
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, fire)
        }
    }

    fun cancel(context: Context, alarm: Alarm) {
        val manager = context.getSystemService(AlarmManager::class.java) ?: return
        manager.cancel(firePendingIntent(context, alarm))
    }

    private fun firePendingIntent(context: Context, alarm: Alarm): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            alarm.code,
            Intent(context, AlarmReceiver::class.java)
                .setAction(ACTION_FIRE)
                .setData(Uri.parse("ztclock://alarm/${alarm.id}")),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}
