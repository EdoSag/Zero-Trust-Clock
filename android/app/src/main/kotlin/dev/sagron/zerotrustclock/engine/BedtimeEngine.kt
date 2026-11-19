package dev.sagron.zerotrustclock.engine

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.text.format.DateFormat
import dev.sagron.zerotrustclock.R
import dev.sagron.zerotrustclock.engine.core.Bedtime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.Date

/**
 * Bedtime: the reminder before the night, and Do Not Disturb through it
 * (when the user turned that on and gave the app Do Not Disturb access).
 * The wake-up itself is a normal alarm, made by the Bedtime screen.
 */
object BedtimeEngine {
    const val ACTION_REMIND = "dev.sagron.zerotrustclock.action.BEDTIME_REMIND"
    const val ACTION_START = "dev.sagron.zerotrustclock.action.BEDTIME_START"
    const val ACTION_END = "dev.sagron.zerotrustclock.action.BEDTIME_END"
    private const val CHANNEL = "bedtime"
    private const val REMINDER_ID = 20
    private const val ACCENT = 0xFF6366F1.toInt()

    private fun prefs(context: Context) =
        AlarmStore.deviceContext(context).getSharedPreferences("bedtime", Context.MODE_PRIVATE)

    fun load(context: Context): Bedtime = Bedtime.fromJson(prefs(context).getString("schedule", null))

    fun save(context: Context, bedtime: Bedtime) {
        prefs(context).edit().putString("schedule", bedtime.toJson()).commit()
        refresh(context)
    }

    fun hasDndAccess(context: Context): Boolean =
        context.getSystemService(NotificationManager::class.java)?.isNotificationPolicyAccessGranted == true

    /**
     * Sets the next reminder, start and end with AlarmManager, and puts Do
     * Not Disturb in line with the schedule right now.
     */
    fun refresh(context: Context) {
        val b = load(context)
        val now = ZonedDateTime.now(ZoneId.systemDefault())
        val current = b.current(now)
        arm(context, ACTION_REMIND, b.nextReminder(now)?.toInstant()?.toEpochMilli())
        arm(context, ACTION_START, if (current == null) b.nextStart(now)?.toInstant()?.toEpochMilli() else null)
        arm(context, ACTION_END, current?.second?.toInstant()?.toEpochMilli())
        if (current != null && b.doNotDisturb) startDnd(context) else endDnd(context)
    }

    private fun startDnd(context: Context) {
        val m = context.getSystemService(NotificationManager::class.java) ?: return
        if (!m.isNotificationPolicyAccessGranted) return
        val p = prefs(context)
        if (p.getBoolean("dndOurs", false)) return
        val before = m.currentInterruptionFilter
        // Already silenced by the user: leave it, and don't undo it later.
        if (before != NotificationManager.INTERRUPTION_FILTER_ALL) return
        try {
            m.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            p.edit().putBoolean("dndOurs", true).apply()
        } catch (_: Exception) {
        }
    }

    private fun endDnd(context: Context) {
        val p = prefs(context)
        if (!p.getBoolean("dndOurs", false)) return
        p.edit().putBoolean("dndOurs", false).apply()
        val m = context.getSystemService(NotificationManager::class.java) ?: return
        try {
            // Android 15 keeps the app's Do Not Disturb as its own mode, and
            // this call ends only that one, whatever else is on. Before, it
            // is the phone's setting: only if it is still ours.
            if (m.isNotificationPolicyAccessGranted &&
                (Build.VERSION.SDK_INT >= 35 ||
                    m.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            ) {
                m.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
            }
        } catch (_: Exception) {
        }
    }

    private fun intent(context: Context, action: String): PendingIntent = PendingIntent.getBroadcast(
        context,
        action.hashCode(),
        Intent(context, BedtimeReceiver::class.java).setAction(action),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun arm(context: Context, action: String, at: Long?) {
        val manager = context.getSystemService(AlarmManager::class.java) ?: return
        val pending = intent(context, action)
        if (at == null) {
            manager.cancel(pending)
            return
        }
        try {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
        } catch (_: SecurityException) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
        }
    }

    fun showReminder(context: Context) {
        val b = load(context)
        val now = ZonedDateTime.now(ZoneId.systemDefault())
        val start = b.nextStart(now) ?: return
        val text = Loc.wrap(context)
        val m = context.getSystemService(NotificationManager::class.java) ?: return
        m.createNotificationChannel(
            NotificationChannel(CHANNEL, text.getString(R.string.channel_bedtime), NotificationManager.IMPORTANCE_DEFAULT),
        )
        val time = DateFormat.getTimeFormat(text).format(Date(start.toInstant().toEpochMilli()))
        val notification = Notification.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setColor(ACCENT)
            .setContentTitle(text.getString(R.string.bedtime_reminder_title, time))
            .setContentText(text.getString(R.string.bedtime_reminder_text))
            .setAutoCancel(true)
            .setContentIntent(Tabs.open(context, Tabs.BEDTIME))
            .build()
        try {
            m.notify(REMINDER_ID, notification)
        } catch (_: Exception) {
        }
    }
}

/** The bedtime reminder, and the night's start and end. */
class BedtimeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == BedtimeEngine.ACTION_REMIND) BedtimeEngine.showReminder(context)
        // Every one of them: set the next, and Do Not Disturb as it should be now.
        BedtimeEngine.refresh(context)
    }
}
