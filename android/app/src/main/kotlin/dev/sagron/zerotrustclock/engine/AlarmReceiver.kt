package dev.sagron.zerotrustclock.engine

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.UserManager

/**
 * Android calls this at an alarm's time, when an upcoming-alarm window or
 * the sunrise starts, and for the snoozed and upcoming notifications'
 * buttons.
 */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.data?.lastPathSegment ?: return
        when (intent.action) {
            AlarmScheduler.ACTION_FIRE -> RingService.ring(context, id)
            ACTION_CANCEL_SNOOZE -> AlarmEngine.cancelSnooze(context, id)
            // The upcoming alarm's window starts: rescheduling shows it.
            UpcomingAlarms.ACTION_WINDOW -> AlarmScheduler.rescheduleAll(context)
            // The sunrise before the wake-up alarm starts: the same.
            Sunrise.ACTION_START -> AlarmScheduler.rescheduleAll(context)
            UpcomingAlarms.ACTION_SKIP -> AlarmEngine.skipOnce(context, id)
            UpcomingAlarms.ACTION_OFF -> AlarmEngine.setEnabled(context, id, false)
        }
    }

    companion object {
        const val ACTION_CANCEL_SNOOZE = "dev.sagron.zerotrustclock.action.CANCEL_SNOOZE"
    }
}

/**
 * Sets every alarm and timer again after a restart (AlarmManager forgets them),
 * after an app update, and when the clock or time zone changes.
 *
 * It also runs on LOCKED_BOOT_COMPLETED, which arrives before the first
 * unlock: that is what lets an alarm ring on a phone that restarted
 * overnight and is still waiting for its PIN.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_LOCKED_BOOT_COMPLETED, Intent.ACTION_BOOT_COMPLETED -> {
                val unlocked = context.getSystemService(UserManager::class.java)?.isUserUnlocked == true
                // Keep the first report after a restart: the one from before unlock.
                if (intent.action == Intent.ACTION_LOCKED_BOOT_COMPLETED || !unlocked ||
                    !recentlyRecorded(context)
                ) {
                    EnginePrefs.recordBoot(context, System.currentTimeMillis(), !unlocked)
                }
            }
        }
        try {
            AlarmScheduler.rescheduleAll(context)
        } catch (_: Exception) {
            // Tried again on the next of these events, and when the app opens.
        }
        try {
            // A timer that ended while the phone was off rings now.
            TimerEngine.refresh(context)
            TimerEngine.refreshStopwatch(context)
        } catch (_: Exception) {
        }
        try {
            BedtimeEngine.refresh(context)
        } catch (_: Exception) {
        }
    }

    /** True when a restart was already recorded since the phone booted. */
    private fun recentlyRecorded(context: Context): Boolean {
        val bootedAt = System.currentTimeMillis() - android.os.SystemClock.elapsedRealtime()
        return EnginePrefs.bootAt(context) >= bootedAt
    }
}
