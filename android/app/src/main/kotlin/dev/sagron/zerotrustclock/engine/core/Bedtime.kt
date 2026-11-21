package dev.sagron.zerotrustclock.engine.core

import org.json.JSONArray
import org.json.JSONObject
import java.time.Duration
import java.time.LocalTime
import java.time.ZonedDateTime

/**
 * The bedtime schedule: when the night starts and ends, on which nights,
 * the reminder before it, and whether Do Not Disturb is on through it.
 *
 * [nights] are the evenings the schedule starts on, ISO numbers
 * (1 = Monday .. 7 = Sunday). A night that ends after midnight ends on
 * the next day's morning.
 */
data class Bedtime(
    val enabled: Boolean = false,
    val bedHour: Int = 23,
    val bedMinute: Int = 0,
    val wakeHour: Int = 7,
    val wakeMinute: Int = 0,
    val nights: Set<Int> = setOf(1, 2, 3, 4, 5, 6, 7),
    /** Minutes before bedtime for the reminder; 0: none. */
    val reminderMinutes: Int = 15,
    val doNotDisturb: Boolean = false,
    /** The alarm that wakes the user, made from this schedule, if any. */
    val wakeAlarmId: String? = null,
    /** The screen lights up slowly before the wake-up alarm (SunriseMath). */
    val sunrise: Boolean = false,
    /** Each night is saved to Health Connect as sleep (SleepMath). */
    val saveSleep: Boolean = false,
) {
    private val bed: LocalTime get() = LocalTime.of(bedHour, bedMinute)
    private val wake: LocalTime get() = LocalTime.of(wakeHour, wakeMinute)

    /** How long a night is: 23:00 to 07:00 is 8 hours. */
    val length: Duration
        get() {
            val d = Duration.between(bed, wake)
            return if (d.isNegative || d.isZero) d.plusDays(1) else d
        }

    /** The mornings the night ends on (the next day when it crosses midnight). */
    val wakeDays: Set<Int>
        get() = if (wake <= bed) nights.map { it % 7 + 1 }.toSet() else nights

    /** The night under way at [now], as (start, end), or null. */
    fun current(now: ZonedDateTime): Pair<ZonedDateTime, ZonedDateTime>? {
        if (!enabled || nights.isEmpty()) return null
        // Tonight's, or last night's if it is still going.
        for (back in 0L..1L) {
            val day = now.toLocalDate().minusDays(back)
            if (day.dayOfWeek.value !in nights) continue
            val start = day.atTime(bed).atZone(now.zone)
            // The wake-up time on the clock, also on a night the clocks change.
            val end = (if (wake <= bed) day.plusDays(1) else day).atTime(wake).atZone(now.zone)
            if (!now.isBefore(start) && now.isBefore(end)) return start to end
        }
        return null
    }

    /**
     * The night that started last before [now], as (start, end), over or
     * not: the night a morning's wake-up belongs to. Null when none
     * started in the last [withinHours].
     */
    fun lastNight(now: ZonedDateTime, withinHours: Long = SleepMath.MAX_HOURS): Pair<ZonedDateTime, ZonedDateTime>? {
        if (!enabled || nights.isEmpty()) return null
        for (back in 0L..1L) {
            val day = now.toLocalDate().minusDays(back)
            if (day.dayOfWeek.value !in nights) continue
            val start = day.atTime(bed).atZone(now.zone)
            if (start.isAfter(now) || Duration.between(start, now).toHours() >= withinHours) continue
            val end = (if (wake <= bed) day.plusDays(1) else day).atTime(wake).atZone(now.zone)
            return start to end
        }
        return null
    }

    /** The next night's start after [now], or null. */
    fun nextStart(now: ZonedDateTime): ZonedDateTime? {
        if (!enabled || nights.isEmpty()) return null
        for (ahead in 0L..7L) {
            val day = now.toLocalDate().plusDays(ahead)
            if (day.dayOfWeek.value !in nights) continue
            val start = day.atTime(bed).atZone(now.zone)
            if (start.isAfter(now)) return start
        }
        return null
    }

    /** When the next reminder is due, or null (none, or its time is gone). */
    fun nextReminder(now: ZonedDateTime): ZonedDateTime? {
        if (reminderMinutes <= 0) return null
        var from = now
        // A reminder whose time passed belongs to a night about to start:
        // the one after it is next.
        repeat(8) {
            val start = nextStart(from) ?: return null
            val at = start.minusMinutes(reminderMinutes.toLong())
            if (at.isAfter(now)) return at
            from = start
        }
        return null
    }

    fun toJson(): String = JSONObject().apply {
        put("enabled", enabled)
        put("bedHour", bedHour)
        put("bedMinute", bedMinute)
        put("wakeHour", wakeHour)
        put("wakeMinute", wakeMinute)
        put("nights", JSONArray().also { a -> nights.sorted().forEach { a.put(it) } })
        put("reminderMinutes", reminderMinutes)
        put("doNotDisturb", doNotDisturb)
        if (wakeAlarmId != null) put("wakeAlarmId", wakeAlarmId)
        put("sunrise", sunrise)
        put("saveSleep", saveSleep)
    }.toString()

    companion object {
        fun fromJson(text: String?): Bedtime {
            if (text.isNullOrEmpty()) return Bedtime()
            return try {
                val o = JSONObject(text)
                val a = o.optJSONArray("nights") ?: JSONArray()
                Bedtime(
                    enabled = o.optBoolean("enabled", false),
                    bedHour = o.optInt("bedHour", 23).coerceIn(0, 23),
                    bedMinute = o.optInt("bedMinute", 0).coerceIn(0, 59),
                    wakeHour = o.optInt("wakeHour", 7).coerceIn(0, 23),
                    wakeMinute = o.optInt("wakeMinute", 0).coerceIn(0, 59),
                    nights = (0 until a.length()).map { a.getInt(it) }.filter { it in 1..7 }.toSet(),
                    reminderMinutes = o.optInt("reminderMinutes", 15).coerceIn(0, 240),
                    doNotDisturb = o.optBoolean("doNotDisturb", false),
                    wakeAlarmId = if (o.has("wakeAlarmId") && !o.isNull("wakeAlarmId")) o.getString("wakeAlarmId") else null,
                    sunrise = o.optBoolean("sunrise", false),
                    saveSleep = o.optBoolean("saveSleep", false),
                )
            } catch (_: Exception) {
                Bedtime()
            }
        }
    }
}

/**
 * The sunrise screen: for [MINUTES] before the wake-up alarm the screen
 * goes from a dark red to a warm white, getting brighter all the way.
 */
object SunriseMath {
    const val MINUTES = 15
    private const val LENGTH_MS = MINUTES * 60_000L

    /** When the sunrise for a ring at [ringAt] starts (epoch milliseconds). */
    fun startFor(ringAt: Long): Long = ringAt - LENGTH_MS

    /** 0 at the start, 1 at the ring. */
    fun progress(now: Long, ringAt: Long): Float =
        ((now - startFor(ringAt)).toFloat() / LENGTH_MS).coerceIn(0f, 1f)

    /** The screen's brightness, 0.02 to 1: slow at first, like a real dawn. */
    fun brightness(progress: Float): Float {
        val p = progress.coerceIn(0f, 1f)
        return 0.02f + 0.98f * p * p
    }

    /** The sky, dark to light: (progress, red, green, blue). */
    private val sky = listOf(
        intArrayOf(0, 0x14, 0x06, 0x02),
        intArrayOf(35, 0x8A, 0x2A, 0x0A),
        intArrayOf(70, 0xF5, 0x9E, 0x42),
        intArrayOf(100, 0xFF, 0xF3, 0xD6),
    )

    /** The sky's colour (opaque ARGB). */
    fun color(progress: Float): Int {
        val p = progress.coerceIn(0f, 1f) * 100f
        var from = sky.first()
        var to = sky.last()
        for (i in 0 until sky.size - 1) {
            if (p >= sky[i][0] && p <= sky[i + 1][0]) {
                from = sky[i]
                to = sky[i + 1]
                break
            }
        }
        val t = if (to[0] == from[0]) 0f else (p - from[0]) / (to[0] - from[0])
        fun mix(i: Int) = (from[i] + (to[i] - from[i]) * t).toInt().coerceIn(0, 255)
        return (0xFF shl 24) or (mix(1) shl 16) or (mix(2) shl 8) or mix(3)
    }

    /** The sky is light enough for dark text. */
    fun lightSky(progress: Float): Boolean = progress >= 0.6f
}

/** A night as it is saved to Health Connect. */
object SleepMath {
    /** A night is at least this long, and at most [MAX_HOURS]. */
    const val MIN_MINUTES = 60L
    const val MAX_HOURS = 18L

    /**
     * The sleep for a night that started at [start] (bedtime) and ended at
     * [end] (the wake-up alarm dismissed, or the schedule's wake-up time),
     * in epoch milliseconds; null when that is no night at all.
     */
    fun session(start: Long, end: Long): Pair<Long, Long>? {
        val minutes = (end - start) / 60_000L
        return if (minutes < MIN_MINUTES || minutes > MAX_HOURS * 60) null else start to end
    }
}
