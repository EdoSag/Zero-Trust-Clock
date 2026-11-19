package dev.sagron.zerotrustclock.engine

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import dev.sagron.zerotrustclock.engine.core.Alarm
import dev.sagron.zerotrustclock.engine.core.AlarmSchedule
import java.time.LocalDate
import java.time.ZonedDateTime

/**
 * The "Upcoming alarm" notification, shown from two hours before a ring
 * until it rings. Its button is "Turn off once" on a repeating alarm and
 * "Dismiss" (switch off) on one that rings once, so a ring that isn't
 * needed can be stopped the evening before without opening the app.
 *
 * Kept in step by [AlarmScheduler.rescheduleAll]: each alarm whose next
 * ring is further away gets a wake-up at the start of its window.
 */
object UpcomingAlarms {
    const val WINDOW_MS = 2 * 60 * 60_000L
    const val ACTION_WINDOW = "dev.sagron.zerotrustclock.action.UPCOMING"
    const val ACTION_SKIP = "dev.sagron.zerotrustclock.action.UPCOMING_SKIP"
    const val ACTION_OFF = "dev.sagron.zerotrustclock.action.UPCOMING_OFF"

    /** Keeps AlarmManager's request codes apart from the rings' own. */
    private const val CODE_OFFSET = 1_000_000

    fun refresh(
        context: Context,
        alarms: List<Alarm>,
        now: ZonedDateTime,
        pauseAll: LocalDate?,
        holidays: Set<LocalDate> = emptySet(),
    ) {
        val nowMs = now.toInstant().toEpochMilli()
        val ringing = RingService.ringingId
        for (a in alarms) {
            val next = if (a.test || a.snoozeUntil != null || a.id == ringing) {
                null
            } else {
                AlarmSchedule.nextRing(a, now, pauseAll, holidays)
            }
            val at = next?.at?.toInstant()?.toEpochMilli()
            when {
                at == null -> forget(context, a)
                at - nowMs <= WINDOW_MS -> {
                    cancelWindow(context, a)
                    AlarmNotifications.showUpcoming(Loc.wrap(context), a, at)
                }
                else -> {
                    AlarmNotifications.cancelUpcoming(context, a.id)
                    armWindow(context, a, at - WINDOW_MS)
                }
            }
        }
    }

    /** The alarm is gone or off: no notification, no wake-up. */
    fun forget(context: Context, alarm: Alarm) {
        cancelWindow(context, alarm)
        AlarmNotifications.cancelUpcoming(context, alarm.id)
    }

    private fun armWindow(context: Context, alarm: Alarm, at: Long) {
        val manager = context.getSystemService(AlarmManager::class.java) ?: return
        val pending = windowIntent(context, alarm)
        try {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
        } catch (_: SecurityException) {
            // Exact alarms refused (Android 12): a few minutes late is fine here.
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
        }
    }

    private fun cancelWindow(context: Context, alarm: Alarm) {
        context.getSystemService(AlarmManager::class.java)?.cancel(windowIntent(context, alarm))
    }

    private fun windowIntent(context: Context, alarm: Alarm): PendingIntent = PendingIntent.getBroadcast(
        context,
        CODE_OFFSET + alarm.code,
        Intent(context, AlarmReceiver::class.java)
            .setAction(ACTION_WINDOW)
            .setData(Uri.parse("ztclock://alarm/${alarm.id}")),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    /** The notification's button. */
    fun buttonIntent(context: Context, alarm: Alarm): PendingIntent = PendingIntent.getBroadcast(
        context,
        2 * CODE_OFFSET + alarm.code,
        Intent(context, AlarmReceiver::class.java)
            .setAction(if (alarm.repeats) ACTION_SKIP else ACTION_OFF)
            .setData(Uri.parse("ztclock://alarm/${alarm.id}")),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
