package dev.sagron.zerotrustclock.engine.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.Duration
import java.time.ZoneId
import java.time.ZonedDateTime

class BedtimeTest {
    private val zone = ZoneId.of("Asia/Jerusalem")

    // Wednesday 18 November 2026.
    private fun at(day: Int, hour: Int, minute: Int = 0) = ZonedDateTime.of(2026, 11, day, hour, minute, 0, 0, zone)

    private val weeknights = Bedtime(
        enabled = true,
        bedHour = 23,
        bedMinute = 0,
        wakeHour = 7,
        wakeMinute = 0,
        // Sunday to Thursday evenings.
        nights = setOf(7, 1, 2, 3, 4),
    )

    @Test
    fun aNightAcrossMidnightIsEightHoursAndEndsTheNextMorning() {
        assertEquals(Duration.ofHours(8), weeknights.length)
        assertEquals(setOf(1, 2, 3, 4, 5), weeknights.wakeDays)
        val sameDay = weeknights.copy(bedHour = 1, wakeHour = 8)
        assertEquals(Duration.ofHours(7), sameDay.length)
        assertEquals(sameDay.nights, sameDay.wakeDays)
    }

    @Test
    fun theNightUnderWayIncludesTheMorningAfter() {
        // Wednesday 23:30 and Thursday 06:59 are inside; Thursday 07:00 is not.
        assertEquals(at(18, 23), weeknights.current(at(18, 23, 30))?.first)
        assertEquals(at(19, 7), weeknights.current(at(19, 6, 59))?.second)
        assertNull(weeknights.current(at(19, 7)))
        // Friday evening is not a bedtime night.
        assertNull(weeknights.current(at(20, 23, 30)))
        assertNull(weeknights.copy(enabled = false).current(at(18, 23, 30)))
    }

    @Test
    fun theNextStartSkipsNightsOff() {
        assertEquals(at(18, 23), weeknights.nextStart(at(18, 12)))
        // Thursday night, then Sunday (no Friday or Saturday).
        assertEquals(at(19, 23), weeknights.nextStart(at(18, 23, 30)))
        assertEquals(at(22, 23), weeknights.nextStart(at(19, 23, 30)))
    }

    @Test
    fun theReminderComesBeforeEachNight() {
        assertEquals(at(18, 22, 45), weeknights.nextReminder(at(18, 12)))
        // Its time passed for tonight: tomorrow's.
        assertEquals(at(19, 22, 45), weeknights.nextReminder(at(18, 22, 50)))
        assertNull(weeknights.copy(reminderMinutes = 0).nextReminder(at(18, 12)))
    }

    @Test
    fun itRoundTripsAsJson() {
        val b = weeknights.copy(doNotDisturb = true, wakeAlarmId = "w1", reminderMinutes = 30)
        assertEquals(b, Bedtime.fromJson(b.toJson()))
        assertEquals(Bedtime(), Bedtime.fromJson("not json"))
    }

    @Test
    fun aNightTheClocksChangeEndsAtTheWakeUpTimeOnTheClock() {
        val ny = ZoneId.of("America/New_York")
        val saturday = weeknights.copy(nights = setOf(6))
        // Clocks go forward on 14 March 2027: the night is 7 hours, still
        // ending at 07:00.
        val night = saturday.current(ZonedDateTime.of(2027, 3, 14, 6, 30, 0, 0, ny))
        assertEquals(ZonedDateTime.of(2027, 3, 14, 7, 0, 0, 0, ny), night?.second)
        assertNull(saturday.current(ZonedDateTime.of(2027, 3, 14, 7, 30, 0, 0, ny)))
        // And back on 6 November 2027.
        val autumn = saturday.current(ZonedDateTime.of(2027, 11, 7, 6, 30, 0, 0, ny))
        assertEquals(ZonedDateTime.of(2027, 11, 7, 7, 0, 0, 0, ny), autumn?.second)
    }
}
