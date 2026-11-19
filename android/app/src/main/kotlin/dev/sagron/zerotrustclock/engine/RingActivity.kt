package dev.sagron.zerotrustclock.engine

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.window.OnBackInvokedDispatcher
import android.widget.TextView
import dev.sagron.zerotrustclock.R

/**
 * The full-screen ring screen, shown over the lock screen. Plain Android
 * views (no Flutter), so it also opens before the phone's first unlock.
 */
class RingActivity : Activity() {
    private val closeWhenEnded: () -> Unit = { finish() }

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(Loc.wrap(base))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(R.layout.activity_ring)
        // Back does not silence an alarm: only Snooze and Dismiss do.
        if (Build.VERSION.SDK_INT >= 33) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
            ) { }
        }
        findViewById<View>(R.id.ring_snooze).setOnClickListener {
            RingService.send(this, RingService.ACTION_SNOOZE)
        }
        // Dismiss is a slide, so a sleepy tap can't silence the alarm.
        findViewById<SlideToDismiss>(R.id.ring_dismiss).onDismiss = {
            RingService.send(this, RingService.ACTION_DISMISS)
        }
        show()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        show()
    }

    override fun onStart() {
        super.onStart()
        RingService.onEnded = closeWhenEnded
        // Opened from an old notification after the ring ended.
        if (RingService.ringingId == null) finish()
        // Back on screen, maybe on a phone locked in the meantime: the
        // label is read again, and stays away while the phone is locked.
        show()
    }

    override fun onStop() {
        if (RingService.onEnded === closeWhenEnded) RingService.onEnded = null
        super.onStop()
    }

    private fun show() {
        val id = RingService.ringingId
        val alarm = if (id == null) null else AlarmStore.load(this).firstOrNull { it.id == id }
        val label = if (alarm == null) "" else AlarmNotifications.visibleLabel(this, alarm)
        val view = findViewById<TextView>(R.id.ring_label)
        view.text = label.ifEmpty { getString(R.string.ring_alarm) }
    }

    /** The same on Android 12 and older. */
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
    }
}
