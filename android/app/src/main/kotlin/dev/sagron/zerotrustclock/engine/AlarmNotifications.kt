package dev.sagron.zerotrustclock.engine

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.text.format.DateFormat
import dev.sagron.zerotrustclock.MainActivity
import dev.sagron.zerotrustclock.R
import dev.sagron.zerotrustclock.engine.core.Alarm
import java.util.Calendar
import java.util.Date

/**
 * The engine's notifications: the ringing alarm (which also opens the
 * ring screen over the lock screen), a snoozed alarm and a missed one.
 *
 * Pass a context from [Loc.wrap] so the texts are in the app's language.
 */
object AlarmNotifications {
    const val CHANNEL_RINGING = "ringing"
    private const val CHANNEL_SNOOZED = "snoozed"
    private const val CHANNEL_MISSED = "missed"
    const val RINGING_ID = 1
    private const val SNOOZED_ID = 2
    private const val MISSED_ID = 3
    private const val ACCENT = 0xFF6366F1.toInt()

    private fun manager(context: Context): NotificationManager? =
        context.getSystemService(NotificationManager::class.java)

    fun ensureChannels(context: Context) {
        val m = manager(context) ?: return
        val ringing = NotificationChannel(
            CHANNEL_RINGING,
            context.getString(R.string.channel_ringing),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(R.string.channel_ringing_about)
            // The ring service plays the sound and vibrates, on the alarm volume.
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setBypassDnd(true)
        }
        val snoozed = NotificationChannel(
            CHANNEL_SNOOZED,
            context.getString(R.string.channel_snoozed),
            NotificationManager.IMPORTANCE_LOW,
        )
        val missed = NotificationChannel(
            CHANNEL_MISSED,
            context.getString(R.string.channel_missed),
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        m.createNotificationChannels(listOf(ringing, snoozed, missed))
    }

    /** "07:00" or "7:00 AM", as the phone shows times. */
    fun timeText(context: Context, hour: Int, minute: Int): String {
        val c = Calendar.getInstance()
        c.set(Calendar.HOUR_OF_DAY, hour)
        c.set(Calendar.MINUTE, minute)
        return DateFormat.getTimeFormat(context).format(c.time)
    }

    /** True while the phone is locked: labels are kept off the lock screen. */
    fun deviceLocked(context: Context): Boolean =
        context.getSystemService(KeyguardManager::class.java)?.isDeviceLocked ?: true

    /**
     * The label to show now: none on a locked phone (or with [hidden],
     * for a screen that just went dark), "Test alarm" for the test.
     */
    fun visibleLabel(context: Context, alarm: Alarm, hidden: Boolean = false): String = when {
        alarm.test -> context.getString(R.string.test_alarm)
        hidden || deviceLocked(context) -> ""
        else -> LabelStore.get(context, alarm.id)
    }

    /**
     * The ringing alarm's notification. [update] is for showing it again
     * while it rings (the label goes when the phone is locked): it must
     * not pop up or open the ring screen a second time.
     */
    fun ringing(
        context: Context,
        alarm: Alarm?,
        hideLabel: Boolean = false,
        update: Boolean = false,
    ): Notification {
        ensureChannels(context)
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, RingActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val label = if (alarm == null) "" else visibleLabel(context, alarm, hideLabel)
        val now = Calendar.getInstance()
        val builder = Notification.Builder(context, CHANNEL_RINGING)
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setColor(ACCENT)
            .setContentTitle(label.ifEmpty { context.getString(R.string.ring_alarm) })
            .setContentText(timeText(context, now.get(Calendar.HOUR_OF_DAY), now.get(Calendar.MINUTE)))
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(update)
            .setShowWhen(false)
            .setContentIntent(open)
            // Opens the ring screen over the lock screen; a heads-up
            // notification with the two buttons when the phone is in use.
            .setFullScreenIntent(open, true)
            .addAction(action(context, R.string.ring_snooze, RingService.ACTION_SNOOZE, 1))
            .addAction(action(context, R.string.ring_dismiss, RingService.ACTION_DISMISS, 2))
        if (Build.VERSION.SDK_INT >= 31) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }

    private fun action(context: Context, text: Int, serviceAction: String, code: Int): Notification.Action {
        val pending = PendingIntent.getService(
            context,
            code,
            Intent(context, RingService::class.java).setAction(serviceAction),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Action.Builder(null, context.getString(text), pending).build()
    }

    fun showSnoozed(context: Context, alarm: Alarm) {
        val until = alarm.snoozeUntil ?: return
        ensureChannels(context)
        val cancel = PendingIntent.getBroadcast(
            context,
            alarm.code,
            Intent(context, AlarmReceiver::class.java)
                .setAction(AlarmReceiver.ACTION_CANCEL_SNOOZE)
                .setData(Uri.parse("ztclock://alarm/${alarm.id}")),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val time = DateFormat.getTimeFormat(context).format(Date(until))
        val notification = Notification.Builder(context, CHANNEL_SNOOZED)
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setColor(ACCENT)
            .setContentTitle(context.getString(R.string.snoozed_title, time))
            .setCategory(Notification.CATEGORY_ALARM)
            .setOngoing(true)
            .setShowWhen(false)
            .setContentIntent(openApp(context))
            .addAction(Notification.Action.Builder(null, context.getString(R.string.ring_dismiss), cancel).build())
            .build()
        notify(context, "snooze:${alarm.id}", SNOOZED_ID, notification)
    }

    fun cancelSnoozed(context: Context, id: String) {
        try {
            manager(context)?.cancel("snooze:$id", SNOOZED_ID)
        } catch (_: Exception) {
        }
    }

    /** An alarm that could not ring on time, or rang and was never answered. */
    fun showMissed(context: Context, alarm: Alarm) {
        ensureChannels(context)
        val time = timeText(context, alarm.hour, alarm.minute)
        val notification = Notification.Builder(context, CHANNEL_MISSED)
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setColor(ACCENT)
            .setContentTitle(context.getString(R.string.missed_title))
            .setContentText(
                if (alarm.test) context.getString(R.string.missed_test)
                else context.getString(R.string.missed_text, time),
            )
            .setAutoCancel(true)
            .setContentIntent(openApp(context))
            .build()
        notify(context, "missed:${alarm.id}", MISSED_ID, notification)
    }

    private fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun notify(context: Context, tag: String, id: Int, notification: Notification) {
        try {
            manager(context)?.notify(tag, id, notification)
        } catch (_: Exception) {
            // Notifications switched off: the alarm itself is unaffected.
        }
    }
}
