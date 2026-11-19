package dev.sagron.zerotrustclock.engine

import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import dev.sagron.zerotrustclock.R

/**
 * "Time's up", over the lock screen. Plain Android views, like the alarm
 * ring screen, so it also opens before the phone's first unlock.
 */
class TimerRingActivity : Activity() {
    private val closeWhenEnded: () -> Unit = { finish() }

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(Loc.wrap(base))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(R.layout.activity_timer_ring)
        findViewById<View>(R.id.timer_ring_add).setOnClickListener {
            TimerRingService.send(this, TimerRingService.ACTION_ADD_MINUTE)
        }
        findViewById<View>(R.id.timer_ring_stop).setOnClickListener {
            TimerRingService.send(this, TimerRingService.ACTION_STOP)
        }
    }

    override fun onStart() {
        super.onStart()
        TimerRingService.onEnded = closeWhenEnded
        if (!TimerRingService.ringing) {
            finish()
            return
        }
        // No labels on a locked phone.
        val withLabel = !AlarmNotifications.deviceLocked(this)
        val finished = TimerStore.load(this).filter { it.ringing }
        findViewById<TextView>(R.id.timer_ring_label).text =
            finished.joinToString(", ") { TimerNotifications.name(this, it, withLabel) }
    }

    override fun onStop() {
        if (TimerRingService.onEnded === closeWhenEnded) TimerRingService.onEnded = null
        super.onStop()
    }
}
