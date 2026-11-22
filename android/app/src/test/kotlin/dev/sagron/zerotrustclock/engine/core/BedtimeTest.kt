package dev.sagron.zerotrustclock.engine.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
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
        val b = weeknights.copy(
            doNotDisturb = true,
            wakeAlarmId = "w1",
            reminderMinutes = 30,
            sunrise = true,
            saveSleep = true,
        )
        assertEquals(b, Bedtime.fromJson(b.toJson()))
        // A schedule saved before these switches were added: both off.
        val old = Bedtime.fromJson("""{"enabled":true,"bedHour":23,"wakeHour":7,"nights":[1]}""")
        assertFalse(old.sunrise)
        assertFalse(old.saveSleep)
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

    @Test
    fun theLastNightIsTheOneAMorningBelongsTo() {
        // Thursday morning, at the alarm and well after it: Wednesday's night.
        assertEquals(at(18, 23) to at(19, 7), weeknights.lastNight(at(19, 7)))
        assertEquals(at(18, 23), weeknights.lastNight(at(19, 7, 40))?.first)
        // Still Wednesday's night at noon; by Thursday evening it is too far back.
        assertEquals(at(18, 23), weeknights.lastNight(at(19, 12))?.first)
        assertNull(weeknights.lastNight(at(19, 17)))
        // The night that just started counts too.
        assertEquals(at(19, 23), weeknights.lastNight(at(19, 23, 30))?.first)
        // Saturday morning: Friday evening is not a bedtime night.
        assertNull(weeknights.lastNight(at(21, 7)))
        assertNull(weeknights.copy(enabled = false).lastNight(at(19, 7)))
        // A night that starts after midnight ends the same day.
        val late = weeknights.copy(bedHour = 1, wakeHour = 8, nights = setOf(4))
        assertEquals(at(19, 1) to at(19, 8), late.lastNight(at(19, 8)))
    }

    @Test
    fun aNightIsSavedAsSleepOnlyWhenItIsANight() {
        val start = at(18, 23).toInstant().toEpochMilli()
        fun end(day: Int, hour: Int, minute: Int = 0) = at(day, hour, minute).toInstant().toEpochMilli()
        assertEquals(start to end(19, 7, 20), SleepMath.session(start, end(19, 7, 20)))
        // The alarm dismissed minutes after bedtime, or a clock set wrong.
        assertNull(SleepMath.session(start, end(18, 23, 30)))
        assertNull(SleepMath.session(start, end(18, 22)))
        assertNull(SleepMath.session(start, end(19, 18)))
        assertEquals(start to end(19, 0), SleepMath.session(start, end(19, 0)))
    }

    @Test
    fun theSunriseStartsFifteenMinutesBeforeTheRingAndOnlyGetsBrighter() {
        val ring = at(19, 7).toInstant().toEpochMilli()
        assertEquals(at(19, 6, 45).toInstant().toEpochMilli(), SunriseMath.startFor(ring))
        assertEquals(0f, SunriseMath.progress(SunriseMath.startFor(ring), ring), 0.0001f)
        assertEquals(0f, SunriseMath.progress(ring - 60 * 60_000L, ring), 0.0001f)
        assertEquals(0.5f, SunriseMath.progress(ring - 450_000L, ring), 0.0001f)
        assertEquals(1f, SunriseMath.progress(ring + 5_000L, ring), 0.0001f)

        assertEquals(0.02f, SunriseMath.brightness(0f), 0.0001f)
        assertEquals(1f, SunriseMath.brightness(1f), 0.0001f)
        // Slow at first: a quarter of the way is still dim.
        assertTrue(SunriseMath.brightness(0.25f) < 0.1f)
        var last = -1f
        var lastLight = -1
        for (step in 0..100) {
            val p = step / 100f
            val b = SunriseMath.brightness(p)
            assertTrue(b > last)
            last = b
            // The sky never gets darker: red + green + blue only rises.
            val c = SunriseMath.color(p)
            assertEquals(0xFF, c ushr 24)
            val light = ((c shr 16) and 0xFF) + ((c shr 8) and 0xFF) + (c and 0xFF)
            assertTrue(light >= lastLight)
            lastLight = light
        }
        assertEquals(0xFF140602.toInt(), SunriseMath.color(0f))
        assertEquals(0xFFFFF3D6.toInt(), SunriseMath.color(1f))
        // Light text on the dark sky, dark text once it is light.
        assertFalse(SunriseMath.lightSky(0.3f))
        assertTrue(SunriseMath.lightSky(0.8f))
    }
}
