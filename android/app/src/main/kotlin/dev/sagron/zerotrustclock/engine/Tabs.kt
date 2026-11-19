package dev.sagron.zerotrustclock.engine

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import dev.sagron.zerotrustclock.MainActivity

/** Opening the app on one of its tabs (from a notification or a shortcut). */
object Tabs {
    const val EXTRA = "dev.sagron.zerotrustclock.tab"
    const val ALARMS = "alarms"
    const val TIMERS = "timers"
    const val STOPWATCH = "stopwatch"
    const val CLOCK = "clock"

    fun intent(context: Context, tab: String): Intent =
        Intent(context, MainActivity::class.java)
            .putExtra(EXTRA, tab)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)

    fun open(context: Context, tab: String): PendingIntent = PendingIntent.getActivity(
        context,
        tab.hashCode(),
        intent(context, tab),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
