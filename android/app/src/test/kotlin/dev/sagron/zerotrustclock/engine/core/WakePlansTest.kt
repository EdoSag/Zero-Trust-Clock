package dev.sagron.zerotrustclock.engine.core

import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Shift patterns, alarms linked to ZT Calendar and the smart wake window. */
class WakePlansTest {
    private val jerusalem = ZoneId.of("Asia/Jerusalem")

    private fun at(text: String): ZonedDateTime = java.time.LocalDateTime.parse(text).atZone(jerusalem)

    private fun next(a: Alarm, now: ZonedDateTime, holidays: Set<LocalDate> = emptySet()): String? =
        AlarmSchedule.nextRing(a, now, holidays = holidays)?.at?.toLocalDateTime()?.toString()

    // 2026-11-18 is a Wednesday.

    private fun shift(days: String, start: String = "2026-11-18", hour: Int = 6) =
        Alarm(id = "s", code = 1, hour = hour, minute = 0, cycle = days, cycleStart = start)

    @Test
    fun shiftPatternRingsOnItsDaysOnly() {
        // Two days on, two off.
        val a = shift("1100")
        assertTrue(a.repeats)
        assertEquals("2026-11-18T06:00", next(a, at("2026-11-17T12:00")))
        assertEquals("2026-11-19T06:00", next(a, at("2026-11-18T06:00")))
        assertEquals("2026-11-22T06:00", next(a, at("2026-11-19T06:00")))
        assertEquals("2026-11-23T06:00", next(a, at("2026-11-22T06:00")))
    }

    @Test
    fun shiftPatternWorksBeforeItsStartAndFarAhead() {
        val p = ShiftPattern.of("11000000", "2026-11-18")!!
        assertEquals(8, p.dayOfCycle(LocalDate.parse("2026-11-17")))
        assertEquals(1, p.dayOfCycle(LocalDate.parse("2026-11-26")))
        assertTrue(p.ringsOn(LocalDate.parse("2027-11-18").minusDays(365L % 8)))
        // A long cycle with its only ring day skipped still finds the next one.
        val a = shift("1" + "0".repeat(55)).copy(skipDate = "2026-11-18")
        assertEquals("2027-01-13T06:00", next(a, at("2026-11-17T12:00")))
    }

    @Test
    fun badShiftPatternsAreIgnored() {
        assertNull(ShiftPattern.of("0000", "2026-11-18"))
        assertNull(ShiftPattern.of("1", "2026-11-18"))
        assertNull(ShiftPattern.of("1102", "2026-11-18"))
        assertNull(ShiftPattern.of("1100", "soon"))
    }

    @Test
    fun withTimeKeepsWeekdaysOrAPatternNeverBoth() {
        val now = at("2026-11-18T05:00")
        val a = AlarmSchedule.withTime(
            Alarm(id = "a", code = 1, hour = 7, minute = 0, days = setOf(1, 2)),
            6, 30, setOf(1, 2), now, cycle = "1100", cycleStart = "2026-11-18",
        )
        assertEquals(emptySet<Int>(), a.days)
        assertEquals("1100", a.cycle)
        assertNull(a.date)
        val back = AlarmSchedule.withTime(a, 6, 30, setOf(3), now, cycle = null, cycleStart = null)
        assertNull(back.cycle)
        assertEquals(setOf(3), back.days)
    }

    @Test
    fun shiftAlarmSkipsOnceAndPauses() {
        val a = shift("1100")
        val skipped = AlarmSchedule.skipOnce(a, at("2026-11-17T12:00"))
        assertEquals("2026-11-18", skipped.skipDate)
        assertEquals("2026-11-19T06:00", next(skipped, at("2026-11-17T12:00")))
        val paused = AlarmSchedule.pause(a, LocalDate.parse("2026-11-22"))
        assertEquals("2026-11-23T06:00", next(paused, at("2026-11-17T12:00")))
    }

    @Test
    fun shiftAlarmJsonRoundTrips() {
        val a = shift("11000000").copy(smartWake = 20, servedUntil = 5L)
        val back = Alarm.fromJson(JSONObject(a.toJson().toString()))
        assertEquals(a, back)
    }

    // --- ZT Calendar ---

    private fun linked(
        link: CalendarLink = CalendarLink(),
        plan: Map<String, Int> = emptyMap(),
        through: String? = "2026-11-30",
        days: Set<Int> = setOf(7, 1, 2, 3, 4),
    ) = Alarm(
        id = "c", code = 2, hour = 7, minute = 30, days = days,
        calendar = link, calendarPlan = plan, calendarThrough = through,
    )

    @Test
    fun earlierWhenTheFirstEventNeedsIt() {
        // Thursday's first event at 08:00: an hour before, so 07:00.
        val a = linked(plan = mapOf("2026-11-19" to 8 * 60))
        assertEquals("2026-11-19T07:00", next(a, at("2026-11-18T08:00")))
        // A first event at 11:00 leaves the usual 07:30.
        val late = linked(plan = mapOf("2026-11-19" to 11 * 60))
        assertEquals("2026-11-19T07:30", next(late, at("2026-11-18T08:00")))
    }

    @Test
    fun followRingsBeforeTheEventLaterToo() {
        val a = linked(CalendarLink(lead = 90, follow = true), mapOf("2026-11-19" to 11 * 60))
        assertEquals("2026-11-19T09:30", next(a, at("2026-11-18T08:00")))
        // No event that day: the usual time.
        assertEquals("2026-11-22T07:30", next(a, at("2026-11-19T10:00")))
    }

    @Test
    fun neverEarlierThanTheEarliestTime() {
        val a = linked(CalendarLink(lead = 60, earliest = 6 * 60), mapOf("2026-11-19" to 6 * 60 + 30))
        assertEquals("2026-11-19T06:00", next(a, at("2026-11-18T08:00")))
        // An event before the earliest time doesn't count.
        val night = linked(CalendarLink(earliest = 6 * 60), mapOf("2026-11-19" to 5 * 60))
        assertEquals("2026-11-19T07:30", next(night, at("2026-11-18T08:00")))
    }

    @Test
    fun otherDaysRingForMorningEventsOnly() {
        // Friday (not a ring day) at 09:00.
        val plan = mapOf("2026-11-20" to 9 * 60)
        assertEquals("2026-11-22T07:30", next(linked(plan = plan), at("2026-11-19T08:00")))
        val extra = linked(CalendarLink(otherDays = true), plan)
        assertEquals("2026-11-20T08:00", next(extra, at("2026-11-19T08:00")))
        // An afternoon event on a day off is no reason to ring.
        val afternoon = linked(CalendarLink(otherDays = true), mapOf("2026-11-20" to 14 * 60))
        assertEquals("2026-11-22T07:30", next(afternoon, at("2026-11-19T08:00")))
    }

    @Test
    fun beyondWhatWasReadTheUsualTimeRings() {
        val a = linked(plan = mapOf("2026-12-03" to 8 * 60), through = "2026-11-30")
        assertEquals("2026-12-03T07:30", next(a, at("2026-12-02T08:00")))
        val never = linked(plan = mapOf("2026-11-19" to 8 * 60), through = null)
        assertEquals("2026-11-19T07:30", next(never, at("2026-11-18T08:00")))
    }

    @Test
    fun linkedAlarmSkipsOnceAndHolidaysOnTheMovedTime() {
        val a = linked(plan = mapOf("2026-11-19" to 8 * 60))
        val skipped = AlarmSchedule.skipOnce(a, at("2026-11-18T08:00"))
        assertEquals("2026-11-19", skipped.skipDate)
        assertTrue(AlarmSchedule.skipActive(skipped, at("2026-11-19T06:59")))
        assertFalse(AlarmSchedule.skipActive(skipped, at("2026-11-19T07:00")))
        val holiday = a.copy(skipHolidays = true)
        assertEquals(
            "2026-11-22T07:30",
            next(holiday, at("2026-11-18T08:00"), setOf(LocalDate.parse("2026-11-19"))),
        )
    }

    @Test
    fun linkedJsonRoundTrips() {
        val a = linked(CalendarLink(lead = 45, follow = true, earliest = 330, otherDays = true), mapOf("2026-11-19" to 480))
        assertEquals(a, Alarm.fromJson(JSONObject(a.toJson().toString())))
    }

    @Test
    fun linkToShiftPattern() {
        val a = shift("1100").copy(calendar = CalendarLink(), calendarPlan = mapOf("2026-11-19" to 6 * 60 + 30), calendarThrough = "2026-11-30")
        assertEquals("2026-11-19T05:30", next(a, at("2026-11-18T07:00")))
    }

    // --- Smart wake ---

    @Test
    fun servedEarlyMovesToTheNextRing() {
        val a = Alarm(id = "w", code = 3, hour = 7, minute = 0, days = (1..7).toSet(), smartWake = 20)
        val now = at("2026-11-18T06:45")
        val window = AlarmSchedule.smartWindow(a, now)!!
        assertEquals(at("2026-11-18T06:40").toInstant().toEpochMilli(), window.first)
        assertEquals(at("2026-11-18T07:00").toInstant().toEpochMilli(), window.second)
        val served = AlarmSchedule.servedEarly(a, window.second)
        assertEquals("2026-11-19T07:00", next(served, now))
        // Once that moment is gone, nothing is left of it.
        assertNull(AlarmSchedule.tidy(served, at("2026-11-18T07:01")).servedUntil)
    }

    @Test
    fun noWindowWhileSnoozedOrOff() {
        val a = Alarm(id = "w", code = 3, hour = 7, minute = 0, days = (1..7).toSet(), smartWake = 20)
        assertNull(AlarmSchedule.smartWindow(a.copy(snoozeUntil = 1L), at("2026-11-18T06:45")))
        assertNull(AlarmSchedule.smartWindow(a.copy(smartWake = 0), at("2026-11-18T06:45")))
        assertNull(AlarmSchedule.smartWindow(a.copy(enabled = false), at("2026-11-18T06:45")))
    }

    @Test
    fun editingForgetsAnEarlyRing() {
        val a = Alarm(id = "w", code = 3, hour = 7, minute = 0, days = (1..7).toSet(), servedUntil = 99L)
        assertNull(AlarmSchedule.withTime(a, 7, 5, a.days, at("2026-11-18T06:45")).servedUntil)
    }

    @Test
    fun smartWakeChoices() {
        assertEquals(20, SmartWake.parse(20))
        assertEquals(0, SmartWake.parse(25))
    }

    private fun feed(d: MotionDetector, fromMs: Long, toMs: Long, moving: (Long) -> Boolean): Long? {
        var t = fromMs
        var flip = false
        while (t <= toMs) {
            flip = !flip
            val shake = if (moving(t)) (if (flip) 3f else -3f) else 0f
            if (d.add(t, shake, 0f, 9.81f)) return t
            t += 200
        }
        return null
    }

    @Test
    fun stillPhoneNeverWakes() {
        val d = MotionDetector()
        assertNull(feed(d, 0, 30 * 60_000L) { false })
    }

    @Test
    fun oneJoltIsNotEnough() {
        val d = MotionDetector()
        assertNull(feed(d, 0, 30 * 60_000L) { it in 300_000L..302_000L })
    }

    @Test
    fun stirringInSeveralSlotsWakes() {
        val d = MotionDetector()
        val moves = listOf(300_000L, 330_000L, 365_000L)
        val woke = feed(d, 0, 30 * 60_000L) { t -> moves.any { t in it..it + 1_000L } }
        assertTrue(woke != null && woke in 365_000L..366_000L)
    }

    @Test
    fun movesTooFarApartDoNotAddUp() {
        val d = MotionDetector()
        val moves = listOf(60_000L, 400_000L, 800_000L)
        assertNull(feed(d, 0, 30 * 60_000L) { t -> moves.any { t in it..it + 1_000L } })
    }

    @Test
    fun theFirstSecondsAreIgnored() {
        val d = MotionDetector()
        assertNull(feed(d, 0, 29_000L) { true })
    }
}
