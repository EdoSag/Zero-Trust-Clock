package dev.sagron.zerotrustclock.engine.core

import java.time.LocalDate
import java.time.LocalTime
import org.json.JSONObject

/**
 * A rotating shift pattern ("2 days, 2 nights, 4 off"): a cycle of days,
 * each one a ring day or a day off, counted from [start]. The cycle runs
 * on forever, backwards too, so any day has its place in it.
 */
data class ShiftPattern(val days: String, val start: LocalDate) {
    val length: Int get() = days.length

    /** Day 1 .. [length] of the cycle that [day] is. */
    fun dayOfCycle(day: LocalDate): Int {
        val diff = day.toEpochDay() - start.toEpochDay()
        return Math.floorMod(diff, length.toLong()).toInt() + 1
    }

    fun ringsOn(day: LocalDate): Boolean = days[dayOfCycle(day) - 1] == '1'

    companion object {
        const val MIN_DAYS = 2
        const val MAX_DAYS = 56

        /** The pattern, or null when it isn't a valid one (then the alarm has none). */
        fun of(days: String?, start: String?): ShiftPattern? {
            if (days == null || days.length !in MIN_DAYS..MAX_DAYS) return null
            if (days.any { it != '0' && it != '1' } || '1' !in days) return null
            val first = AlarmSchedule.parseDay(start) ?: return null
            return ShiftPattern(days, first)
        }
    }
}

/**
 * "Ring in time for my first event": how an alarm follows ZT Calendar.
 *
 * - [lead]: minutes between the ring and the day's first event.
 * - [follow]: false ("earlier when needed") keeps the alarm's own time
 *   unless the first event needs an earlier ring; true rings [lead]
 *   minutes before the first event, later than the alarm's time too.
 *   On a ring day without an event, the alarm's own time rings.
 * - [earliest]: never earlier than this (minutes after midnight). Events
 *   that start before it don't count (a night shift that ends at 06:00).
 * - [otherDays]: also rings on days that aren't ring days, when an event
 *   starts before noon.
 */
data class CalendarLink(
    val lead: Int = 60,
    val follow: Boolean = false,
    val earliest: Int = 5 * 60,
    val otherDays: Boolean = false,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("lead", lead)
        put("follow", follow)
        put("earliest", earliest)
        put("otherDays", otherDays)
    }

    /**
     * The ring time on a day: [usual] is the alarm's own time when it is a
     * ring day (else null); [first] the day's first event in minutes after
     * midnight, null without one; [known] false when the calendar wasn't
     * read that far ahead, so only the usual time rings.
     */
    fun timeOn(usual: LocalTime?, first: Int?, known: Boolean): LocalTime? {
        if (!known || first == null || first < earliest) return usual
        val want = maxOf(first - lead, earliest)
        if (usual == null) return if (otherDays && first < NOON) at(want) else null
        val usualMinutes = usual.hour * 60 + usual.minute
        return if (follow || want < usualMinutes) at(want) else usual
    }

    companion object {
        const val NOON = 12 * 60
        val LEADS = listOf(15, 30, 45, 60, 75, 90, 120, 150, 180)

        fun at(minutes: Int): LocalTime = LocalTime.of(minutes / 60, minutes % 60)

        fun fromJson(o: JSONObject): CalendarLink = CalendarLink(
            lead = o.optInt("lead", 60).coerceIn(0, 6 * 60),
            follow = o.optBoolean("follow", false),
            earliest = o.optInt("earliest", 5 * 60).coerceIn(0, 23 * 60 + 59),
            otherDays = o.optBoolean("otherDays", false),
        )
    }
}

/**
 * Sets or clears an alarm's link to ZT Calendar. What was read from the
 * calendar stays while the alarm stays linked (the app reads it again at
 * the next unlock); unlinked, it is dropped. Only repeating alarms link.
 */
fun Alarm.withCalendar(link: CalendarLink?): Alarm =
    if (link == null || !repeats) {
        copy(calendar = null, calendarPlan = emptyMap(), calendarThrough = null)
    } else {
        copy(calendar = link)
    }

/** The smart wake window's lengths. */
object SmartWake {
    val CHOICES = listOf(0, 10, 20, 30)

    fun parse(minutes: Int): Int = if (minutes in CHOICES) minutes else 0
}

/**
 * Notices someone stirring in bed from the accelerometer, for the smart
 * wake window. A single jolt (a truck outside, a partner turning over
 * once) is not enough: movement has to show up in [needSlots] separate
 * [slotMs] slots within [spanMs]. The first [settleMs] are ignored while
 * the sensor settles.
 *
 * No Android here, so it is tested on any machine.
 */
class MotionDetector(
    private val threshold: Float = 0.6f,
    private val slotMs: Long = 20_000L,
    private val needSlots: Int = 3,
    private val spanMs: Long = 180_000L,
    private val settleMs: Long = 30_000L,
) {
    private var startedAt = -1L
    private var gx = 0f
    private var gy = 0f
    private var gz = 0f
    private var haveGravity = false
    private val moved = ArrayDeque<Long>()

    /** Slots with movement in the current span, for the screens and tests. */
    val slots: Int get() = moved.size

    /**
     * One reading at [timeMs] (any steady clock). True once enough
     * movement was seen to wake now.
     */
    fun add(timeMs: Long, x: Float, y: Float, z: Float): Boolean {
        if (startedAt < 0) startedAt = timeMs
        if (!haveGravity) {
            gx = x
            gy = y
            gz = z
            haveGravity = true
            return false
        }
        // Low-pass for gravity, the rest is the phone being moved.
        gx = gx * 0.9f + x * 0.1f
        gy = gy * 0.9f + y * 0.1f
        gz = gz * 0.9f + z * 0.1f
        val lx = x - gx
        val ly = y - gy
        val lz = z - gz
        if (timeMs - startedAt < settleMs) return false
        while (moved.isNotEmpty() && (timeMs / slotMs - moved.first()) * slotMs > spanMs) moved.removeFirst()
        if (lx * lx + ly * ly + lz * lz < threshold * threshold) return false
        val slot = timeMs / slotMs
        if (moved.lastOrNull() != slot) moved.addLast(slot)
        return moved.size >= needSlots
    }
}
