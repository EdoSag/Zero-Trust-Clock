package dev.sagron.zerotrustclock.engine

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * A timer's end, and the buttons of the timer and stopwatch notifications
 * and widgets.
 */
class TimerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.data?.lastPathSegment
        when (intent.action) {
            TimerEngine.ACTION_FIRE -> TimerEngine.fire(context)
            ACTION_START -> id?.let { TimerEngine.start(context, it) }
            ACTION_PAUSE -> id?.let { TimerEngine.pause(context, it) }
            ACTION_ADD_MINUTE -> id?.let { TimerEngine.addMinute(context, it) }
            ACTION_RESET -> id?.let { TimerEngine.reset(context, it) }
            // The widget's quick starts: ztclock://timer-new/<seconds>.
            ACTION_NEW -> id?.toLongOrNull()?.takeIf { it > 0 }?.let {
                TimerEngine.add(context, it * 1000, "", start = true)
            }
            ACTION_STOP_RINGING -> TimerEngine.stopRinging(context)
            ACTION_STOPWATCH_START -> TimerEngine.stopwatch(context) { s, now -> s.start(now) }
            ACTION_STOPWATCH_PAUSE -> TimerEngine.stopwatch(context) { s, now -> s.pause(now) }
            ACTION_STOPWATCH_LAP -> TimerEngine.stopwatch(context) { s, now -> s.lap(now) }
            ACTION_STOPWATCH_RESET -> TimerEngine.stopwatch(context) { s, _ -> s.reset() }
        }
    }

    companion object {
        const val ACTION_START = "dev.sagron.zerotrustclock.action.TIMER_START"
        const val ACTION_PAUSE = "dev.sagron.zerotrustclock.action.TIMER_PAUSE"
        const val ACTION_ADD_MINUTE = "dev.sagron.zerotrustclock.action.TIMER_ADD_MINUTE"
        const val ACTION_RESET = "dev.sagron.zerotrustclock.action.TIMER_RESET"
        const val ACTION_NEW = "dev.sagron.zerotrustclock.action.TIMER_NEW"
        const val ACTION_STOP_RINGING = "dev.sagron.zerotrustclock.action.TIMER_STOP_RINGING"
        const val ACTION_STOPWATCH_START = "dev.sagron.zerotrustclock.action.STOPWATCH_START"
        const val ACTION_STOPWATCH_PAUSE = "dev.sagron.zerotrustclock.action.STOPWATCH_PAUSE"
        const val ACTION_STOPWATCH_LAP = "dev.sagron.zerotrustclock.action.STOPWATCH_LAP"
        const val ACTION_STOPWATCH_RESET = "dev.sagron.zerotrustclock.action.STOPWATCH_RESET"
    }
}
