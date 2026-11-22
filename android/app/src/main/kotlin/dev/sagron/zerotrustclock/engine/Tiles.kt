package dev.sagron.zerotrustclock.engine

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.text.format.DateFormat
import dev.sagron.zerotrustclock.R
import dev.sagron.zerotrustclock.engine.core.TimerMath
import java.util.Date

/**
 * Quick Settings tiles: the next alarm (opens the alarms), the timer
 * (opens a new timer, or the timers when one is going), and the stopwatch
 * (starts and pauses it).
 */
object Tiles {
    /** Asks Android to redraw the tiles (after an alarm, a timer or the stopwatch changed). */
    fun refresh(context: Context) {
        for (cls in listOf(NextAlarmTile::class.java, TimerTile::class.java, StopwatchTile::class.java)) {
            try {
                TileService.requestListeningState(context, ComponentName(context, cls))
            } catch (_: Exception) {
            }
        }
    }

    /** Opens the app on [tab] and closes the Quick Settings panel. */
    @SuppressLint("StartActivityAndCollapseDeprecated")
    fun open(service: TileService, tab: String) {
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                service.startActivityAndCollapse(
                    PendingIntent.getActivity(
                        service,
                        tab.hashCode(),
                        Tabs.intent(service, tab),
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            } else {
                @Suppress("DEPRECATION")
                service.startActivityAndCollapse(Tabs.intent(service, tab))
            }
        } catch (_: Exception) {
        }
    }

    /** "Tue 07:00": when the next alarm of this app rings, or null. */
    fun nextAlarmText(context: Context): String? {
        val next = AlarmStore.load(context).filter { it.enabled && !it.test }.mapNotNull { it.armedFor }.minOrNull()
            ?: return null
        val pattern = DateFormat.getBestDateTimePattern(
            context.resources.configuration.locales[0],
            if (DateFormat.is24HourFormat(context)) "EEEHHmm" else "EEEhmma",
        )
        return DateFormat.format(pattern, Date(next)).toString()
    }
}

class NextAlarmTile : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        val tile = qsTile ?: return
        val text = Loc.wrap(this)
        val next = Tiles.nextAlarmText(text)
        tile.icon = Icon.createWithResource(this, R.drawable.ic_stat_alarm)
        tile.label = text.getString(R.string.tile_next_alarm)
        tile.state = if (next == null) Tile.STATE_INACTIVE else Tile.STATE_ACTIVE
        if (Build.VERSION.SDK_INT >= 29) {
            tile.subtitle = next ?: text.getString(R.string.tile_no_alarm)
        }
        tile.updateTile()
    }

    override fun onClick() {
        super.onClick()
        Tiles.open(this, Tabs.ALARMS)
    }
}

/**
 * The timer that ends next: "Until 14:35" while it runs (a time of day,
 * so it stays right while the panel is open). A tap opens the keypad for
 * a new timer, or the timers when one is going.
 */
class TimerTile : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        val tile = qsTile ?: return
        val text = Loc.wrap(this)
        val t = TimerMath.featured(TimerStore.load(this))
        tile.icon = Icon.createWithResource(this, R.drawable.ic_stat_timer)
        tile.label = text.getString(R.string.tile_timer)
        tile.state = if (t != null && (t.running || t.ringing)) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        if (Build.VERSION.SDK_INT >= 29) {
            tile.subtitle = when {
                t == null -> text.getString(R.string.tile_timer_set)
                t.ringing -> text.getString(R.string.timer_times_up)
                t.running -> text.getString(
                    R.string.tile_timer_until,
                    DateFormat.getTimeFormat(this).format(Date(t.endsAt!!)),
                )
                t.paused -> text.getString(
                    R.string.timer_paused_left,
                    TimerNotifications.durationText(t.left(TimerEngine.now())),
                )
                else -> TimerNotifications.name(text, t, withLabel = false)
            }
        }
        tile.updateTile()
    }

    override fun onClick() {
        super.onClick()
        val any = TimerStore.load(this).any { it.running || it.paused || it.ringing }
        Tiles.open(this, if (any) Tabs.TIMERS else "newTimer")
    }
}

class StopwatchTile : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        val tile = qsTile ?: return
        val text = Loc.wrap(this)
        val s = TimerStore.stopwatch(this)
        tile.icon = Icon.createWithResource(this, R.drawable.ic_stat_timer)
        tile.label = text.getString(R.string.stopwatch)
        tile.state = if (s.running) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        if (Build.VERSION.SDK_INT >= 29) {
            tile.subtitle = when {
                s.running -> text.getString(R.string.timer_running)
                s.zero -> text.getString(R.string.tile_tap_to_start)
                else -> text.getString(
                    R.string.stopwatch_paused,
                    TimerNotifications.durationText(s.elapsed(TimerEngine.now()), roundUp = false),
                )
            }
        }
        tile.updateTile()
    }

    override fun onClick() {
        super.onClick()
        TimerEngine.stopwatch(this) { s, now -> if (s.running) s.pause(now) else s.start(now) }
        onStartListening()
    }
}
