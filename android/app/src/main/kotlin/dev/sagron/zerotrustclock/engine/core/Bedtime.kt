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
                )
            } catch (_: Exception) {
                Bedtime()
            }
        }
    }
}
