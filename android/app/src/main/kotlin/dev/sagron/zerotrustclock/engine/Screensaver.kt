package dev.sagron.zerotrustclock.engine

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.service.dreams.DreamService
import android.text.format.DateFormat
import android.view.View
import android.widget.TextClock
import android.widget.TextView
import dev.sagron.zerotrustclock.R
import java.util.Locale
import kotlin.random.Random

/** The screensaver's one setting, kept with the engine's other settings. */
object Screensaver {
    private fun prefs(context: Context) =
        AlarmStore.deviceContext(context).getSharedPreferences("screensaver", Context.MODE_PRIVATE)

    /** Dim red on black, easy on the eyes in a dark bedroom. On by default. */
    fun night(context: Context): Boolean = prefs(context).getBoolean("night", true)

    fun setNight(context: Context, on: Boolean) {
        prefs(context).edit().putBoolean("night", on).apply()
    }
}

/**
 * The night clock: Android's screensaver while the phone charges or sits
 * in a dock. The time, the date and the next alarm, on black. Every
 * minute it moves a little, so nothing burns into the screen.
 */
class ClockScreensaver : DreamService() {
    private val handler = Handler(Looper.getMainLooper())
    private val random = Random.Default
    private val move = object : Runnable {
        override fun run() {
            shift()
            handler.postDelayed(this, 60_000L)
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        isInteractive = false
        isFullscreen = true
        val night = Screensaver.night(this)
        isScreenBright = !night
        val text = Loc.wrap(this)
        setContentView(R.layout.dream_clock)
        val color = getColor(if (night) R.color.dream_night else R.color.dream_day)
        val soft = getColor(if (night) R.color.dream_night_soft else R.color.dream_day_soft)
        val locale = text.resources.configuration.locales[0] ?: Locale.getDefault()
        findViewById<TextClock>(R.id.dream_time).apply {
            setTextColor(color)
            val h24 = DateFormat.getBestDateTimePattern(locale, "Hmm")
            val h12 = DateFormat.getBestDateTimePattern(locale, "hmm")
            format24Hour = h24
            format12Hour = h12
        }
        findViewById<TextClock>(R.id.dream_date).apply {
            setTextColor(soft)
            val day = DateFormat.getBestDateTimePattern(locale, "EEEEMMMMd")
            format24Hour = day
            format12Hour = day
        }
        findViewById<TextView>(R.id.dream_alarm).apply {
            setTextColor(soft)
            val next = Tiles.nextAlarmText(text)
            visibility = if (next == null) View.GONE else View.VISIBLE
            this.text = next ?: ""
            compoundDrawablesRelative[0]?.setTint(soft)
        }
    }

    override fun onDreamingStarted() {
        super.onDreamingStarted()
        handler.post(move)
    }

    override fun onDreamingStopped() {
        handler.removeCallbacks(move)
        super.onDreamingStopped()
    }

    override fun onDetachedFromWindow() {
        handler.removeCallbacks(move)
        super.onDetachedFromWindow()
    }

    /** A small random step from the middle, within the screen. */
    private fun shift() {
        val box = findViewById<View>(R.id.dream_box) ?: return
        val root = box.parent as? View ?: return
        val roomX = ((root.width - box.width) / 2f).coerceAtLeast(0f)
        val roomY = ((root.height - box.height) / 2f).coerceAtLeast(0f)
        box.animate()
            .translationX((random.nextFloat() * 2 - 1) * roomX * 0.8f)
            .translationY((random.nextFloat() * 2 - 1) * roomY * 0.8f)
            .setDuration(1500)
            .start()
    }
}
