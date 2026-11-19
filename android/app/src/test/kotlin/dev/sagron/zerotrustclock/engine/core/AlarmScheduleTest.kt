package dev.sagron.zerotrustclock.engine.core

import java.time.ZoneId
import java.time.ZonedDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AlarmScheduleTest {
    private val jerusalem = ZoneId.of("Asia/Jerusalem")

    private fun at(text: String, zone: ZoneId = jerusalem): ZonedDateTime =
        java.time.LocalDateTime.parse(text).atZone(zone)

    private fun alarm(
        hour: Int = 7,
        minute: Int = 0,
        days: Set<Int> = emptySet(),
        date: String? = null,
    ) = Alarm(id = "a", code = 1, hour = hour, minute = minute, days = days, date = date)

    private val weekdaysIL = setOf(7, 1, 2, 3, 4) // Sunday to Thursday
    private val everyDay = (1..7).toSet()

    private fun next(a: Alarm, now: ZonedDateTime): String? =
        AlarmSchedule.nextRing(a, now)?.at?.toLocalDateTime()?.toString()

    // 2026-11-18 is a Wednesday.

    @Test
    fun onceRingsTodayWhenTheTimeIsStillAhead() {
        val now = at("2026-11-18T06:00")
        val a = AlarmSchedule.withTime(alarm(), 7, 0, emptySet(), now)
        assertEquals("2026-11-18", a.date)
        assertEquals("2026-11-18T07:00", next(a, now))
    }

    @Test
    fun onceRingsTomorrowWhenTheTimeHasPassed() {
        val now = at("2026-11-18T07:00")
        val a = AlarmSchedule.withTime(alarm(), 7, 0, emptySet(), now)
        assertEquals("2026-11-19", a.date)
        assertEquals("2026-11-19T07:00", next(a, now))
    }

    @Test
    fun onceIsOverAfterItsTime() {
        val a = alarm(date = "2026-11-18")
        assertNull(AlarmSchedule.nextRing(a, at("2026-11-18T07:00")))
        assertNull(AlarmSchedule.nextTrigger(a, at("2026-11-18T07:00:01")))
    }

    @Test
    fun repeatingPicksTheNextChosenDay() {
        val a = alarm(days = weekdaysIL)
        assertEquals("2026-11-18T07:00", next(a, at("2026-11-18T06:59")))
        assertEquals("2026-11-19T07:00", next(a, at("2026-11-18T07:00")))
        // Thursday after the ring: Friday and Saturday are off, so Sunday.
        assertEquals("2026-11-22T07:00", next(a, at("2026-11-19T08:00")))
    }

    @Test
    fun offAlarmNeverRings() {
        val a = alarm(days = everyDay).copy(enabled = false)
        assertNull(AlarmSchedule.nextRing(a, at("2026-11-18T06:00")))
        assertNull(AlarmSchedule.nextTrigger(a.copy(snoozeUntil = 5), at("2026-11-18T06:00")))
    }

    @Test
    fun turnOffOnceSkipsOnlyTheNextRing() {
        val now = at("2026-11-18T22:00")
        val a = AlarmSchedule.skipOnce(alarm(days = everyDay), now)
        assertTrue(a.enabled)
        assertEquals("2026-11-19", a.skipDate)
        assertTrue(AlarmSchedule.skipActive(a, now))
        assertEquals("2026-11-20T07:00", next(a, now))
        // The morning it would have rung: still skipped, a minute before.
        assertEquals("2026-11-20T07:00", next(a, at("2026-11-19T06:59")))
        // After that morning the skip is over without anything running.
        val later = at("2026-11-19T07:00")
        assertFalse(AlarmSchedule.skipActive(a, later))
        assertEquals("2026-11-20T07:00", next(a, later))
        assertNull(AlarmSchedule.tidy(a, later).skipDate)
        assertEquals("2026-11-21T07:00", next(a, at("2026-11-20T07:00")))
    }

    @Test
    fun turnOffOnceSkipsToTheNextChosenDayNotTomorrow() {
        // Thursday evening, Sunday-to-Thursday alarm: next ring is Sunday.
        val now = at("2026-11-19T20:00")
        val a = AlarmSchedule.skipOnce(alarm(days = weekdaysIL), now)
        assertEquals("2026-11-22", a.skipDate)
        assertEquals("2026-11-23T07:00", next(a, now))
    }

    @Test
    fun turnOffOnceOnAWeeklyAlarmWaitsAWeek() {
        val now = at("2026-11-18T06:00")
        val a = AlarmSchedule.skipOnce(alarm(days = setOf(3)), now)
        assertEquals("2026-11-18", a.skipDate)
        assertEquals("2026-11-25T07:00", next(a, now))
    }

    @Test
    fun turnBackOnUndoesTheSkip() {
        val now = at("2026-11-18T22:00")
        val skipped = AlarmSchedule.skipOnce(alarm(days = everyDay), now)
        val back = AlarmSchedule.undoSkip(skipped, now)
        assertNull(back.skipDate)
        assertEquals("2026-11-19T07:00", next(back, now))
    }

    @Test
    fun turnOffOnceOnAOneTimeAlarmMovesItADay() {
        val now = at("2026-11-18T22:00")
        val once = AlarmSchedule.withTime(alarm(), 7, 0, emptySet(), now)
        assertEquals("2026-11-19", once.date)
        val a = AlarmSchedule.skipOnce(once, now)
        assertTrue(a.enabled)
        assertEquals("2026-11-20", a.date)
        assertEquals("2026-11-19", a.skipDate)
        assertTrue(AlarmSchedule.skipActive(a, now))
        assertEquals("2026-11-20T07:00", next(a, now))
        // Undo while the first morning is still ahead puts it back.
        val back = AlarmSchedule.undoSkip(a, now)
        assertEquals("2026-11-19", back.date)
        assertNull(back.skipDate)
        // Undo after that morning leaves the new day.
        val late = AlarmSchedule.undoSkip(a, at("2026-11-19T08:00"))
        assertEquals("2026-11-20", late.date)
        assertNull(late.skipDate)
    }

    @Test
    fun turnOffOnceDoesNothingToAnOffAlarm() {
        val off = alarm(days = everyDay).copy(enabled = false)
        assertEquals(off, AlarmSchedule.skipOnce(off, at("2026-11-18T22:00")))
    }

    @Test
    fun changingTheTimeForgetsTheSkipAndSnooze() {
        val now = at("2026-11-18T22:00")
        val a = AlarmSchedule.skipOnce(alarm(days = everyDay), now).copy(snoozeUntil = 99)
        val changed = AlarmSchedule.withTime(a, 8, 30, everyDay, now)
        assertNull(changed.skipDate)
        assertNull(changed.snoozeUntil)
        assertEquals("2026-11-19T08:30", next(changed, now))
    }

    @Test
    fun turningOnAgainForgetsTheSkip() {
        val now = at("2026-11-18T22:00")
        val skipped = AlarmSchedule.skipOnce(alarm(days = everyDay), now)
        val on = AlarmSchedule.turnOn(AlarmSchedule.turnOff(skipped), now)
        assertTrue(on.enabled)
        assertNull(on.skipDate)
        assertEquals("2026-11-19T07:00", next(on, now))
    }

    @Test
    fun turningOnAOneTimeAlarmPicksTheNextSuchTime() {
        val stale = alarm(date = "2026-11-01").copy(enabled = false)
        val on = AlarmSchedule.turnOn(stale, at("2026-11-18T22:00"))
        assertEquals("2026-11-19", on.date)
    }

    @Test
    fun snoozeRingsAfterTheSnoozeLength() {
        val now = at("2026-11-18T07:00:30")
        val a = AlarmSchedule.snooze(alarm(days = everyDay).copy(snoozeMinutes = 5), now)
        assertEquals(now.toInstant().toEpochMilli() + 5 * 60_000L, AlarmSchedule.nextTrigger(a, now))
    }

    @Test
    fun afterRingAOneTimeAlarmIsOffAndARepeatingOneStaysOn() {
        val now = at("2026-11-18T07:01")
        val once = AlarmSchedule.afterRing(alarm(date = "2026-11-18").copy(snoozeUntil = 1, armedFor = 2), now)
        assertFalse(once.enabled)
        assertNull(once.date)
        assertNull(once.snoozeUntil)
        assertNull(once.armedFor)
        val daily = AlarmSchedule.afterRing(alarm(days = everyDay).copy(snoozeUntil = 1), now)
        assertTrue(daily.enabled)
        assertNull(daily.snoozeUntil)
        assertEquals("2026-11-19T07:00", next(daily, now))
    }

    @Test
    fun clocksGoForwardInIsrael() {
        // 2027-03-26 (Friday): 02:00 jumps to 03:00, so 02:30 doesn't exist.
        val a = alarm(hour = 2, minute = 30, days = everyDay)
        val ring = AlarmSchedule.nextRing(a, at("2027-03-25T12:00"))!!
        assertEquals("2027-03-26", ring.day.toString())
        assertEquals("2027-03-26T03:30", ring.at.toLocalDateTime().toString())
        // It rang once that day; the next is the day after at 02:30.
        assertEquals("2027-03-27T02:30", next(a, ring.at))
        // A 07:00 alarm is 23 hours after the previous one, not 24.
        val seven = alarm(days = everyDay)
        val before = AlarmSchedule.nextRing(seven, at("2027-03-25T06:00"))!!.at
        val after = AlarmSchedule.nextRing(seven, before)!!.at
        assertEquals("2027-03-26T07:00", after.toLocalDateTime().toString())
        assertEquals(23 * 3600L, after.toEpochSecond() - before.toEpochSecond())
    }

    @Test
    fun clocksGoBackInIsrael() {
        // 2027-10-31 (Sunday): 02:00 comes twice. 01:30 rings the first time only.
        val a = alarm(hour = 1, minute = 30, days = everyDay)
        val first = AlarmSchedule.nextRing(a, at("2027-10-30T12:00"))!!.at
        assertEquals("2027-10-31T01:30", first.toLocalDateTime().toString())
        val second = AlarmSchedule.nextRing(a, first)!!.at
        assertEquals("2027-11-01T01:30", second.toLocalDateTime().toString())
        assertEquals(25 * 3600L, second.toEpochSecond() - first.toEpochSecond())
    }

    @Test
    fun skipStaysOnItsDayAcrossATimeZoneChange() {
        // Skipped in Israel on Wednesday night for Thursday morning...
        val a = AlarmSchedule.skipOnce(alarm(days = everyDay), at("2026-11-18T22:00"))
        assertEquals("2026-11-19", a.skipDate)
        // ...then a flight to New York, where it is still Wednesday.
        val ny = ZoneId.of("America/New_York")
        val landed = at("2026-11-18T18:00", ny)
        // Thursday morning there is still the skipped one.
        assertEquals("2026-11-20T07:00", next(a, landed))
        assertTrue(AlarmSchedule.skipActive(a, landed))
    }

    @Test
    fun aLateRingStillRingsForTenMinutesThenCountsAsMissed() {
        val armed = at("2026-11-18T07:00").toInstant().toEpochMilli()
        val a = alarm(days = everyDay).copy(armedFor = armed)
        // Not yet time.
        assertFalse(AlarmSchedule.dueNow(a, armed - 1))
        assertFalse(AlarmSchedule.wasMissed(a, armed - 1))
        // The phone came back four minutes late: ring now.
        assertTrue(AlarmSchedule.dueNow(a, armed + 4 * 60_000))
        assertFalse(AlarmSchedule.wasMissed(a, armed + 4 * 60_000))
        // An hour late: missed.
        assertFalse(AlarmSchedule.dueNow(a, armed + 3_600_000))
        assertTrue(AlarmSchedule.wasMissed(a, armed + 3_600_000))
        // Nothing armed, or switched off: neither.
        assertFalse(AlarmSchedule.wasMissed(a.copy(armedFor = null), armed + 3_600_000))
        assertFalse(AlarmSchedule.dueNow(a.copy(enabled = false), armed + 1))
        assertFalse(AlarmSchedule.wasMissed(a.copy(enabled = false), armed + 3_600_000))
    }

    @Test
    fun alarmsSurviveBeingSavedAndRead() {
        val all = listOf(
            alarm(days = weekdaysIL).copy(skipDate = "2026-11-19", snoozeUntil = 5, armedFor = 7, vibrate = false),
            alarm(date = "2026-11-20").copy(id = "b", code = 2, test = true, snoozeMinutes = 15),
        )
        assertEquals(all, Alarm.listFromJson(Alarm.listToJson(all)))
    }

    @Test
    fun oneUnreadableAlarmDoesNotLoseTheOthers() {
        val json = """[{"id":"x"},{"id":"ok","code":3,"hour":6,"minute":5,"days":[1,9,"z"]}]"""
        val read = Alarm.listFromJson(json)
        assertEquals(1, read.size)
        assertEquals("ok", read[0].id)
        assertEquals(setOf(1), read[0].days)
    }

    // Pause until, and pause all.

    @Test
    fun pausedAlarmRingsAgainTheDayAfterThePause() {
        val now = at("2026-11-18T06:00")
        val a = AlarmSchedule.pause(alarm(days = everyDay), java.time.LocalDate.parse("2026-11-20"))
        assertTrue(AlarmSchedule.paused(a, now))
        assertEquals("2026-11-21T07:00", next(a, now))
        // After the pause it is over by itself; tidy drops it.
        val later = at("2026-11-21T08:00")
        assertFalse(AlarmSchedule.paused(a, later))
        assertNull(AlarmSchedule.tidy(a, later).pauseUntil)
    }

    @Test
    fun pausingDropsAWaitingSkipAndSwitchingOnEndsThePause() {
        val now = at("2026-11-18T06:00")
        val skipped = AlarmSchedule.skipOnce(alarm(days = everyDay), now)
        val paused = AlarmSchedule.pause(skipped, java.time.LocalDate.parse("2026-11-19"))
        assertNull(paused.skipDate)
        val on = AlarmSchedule.turnOn(AlarmSchedule.turnOff(paused), now)
        assertNull(on.pauseUntil)
        assertEquals("2026-11-18T07:00", next(on, now))
    }

    @Test
    fun pauseAllSilencesRepeatingAlarmsOnly() {
        val now = at("2026-11-18T06:00")
        val until = java.time.LocalDate.parse("2026-11-22")
        val repeating = alarm(days = weekdaysIL)
        assertEquals(
            "2026-11-23T07:00",
            AlarmSchedule.nextRing(repeating, now, until)?.at?.toLocalDateTime()?.toString(),
        )
        assertTrue(AlarmSchedule.paused(repeating, now, until))
        // An alarm set for one day is an explicit choice: it still rings.
        val once = alarm(date = "2026-11-19")
        assertEquals(
            "2026-11-19T07:00",
            AlarmSchedule.nextRing(once, now, until)?.at?.toLocalDateTime()?.toString(),
        )
        assertFalse(AlarmSchedule.paused(once, now, until))
        // A one-time alarm can't be paused by itself either.
        assertNull(AlarmSchedule.pause(once, until).pauseUntil)
    }

    @Test
    fun turnOffOnceAfterAPauseSkipsTheFirstRingAfterIt() {
        val now = at("2026-11-18T06:00")
        val until = java.time.LocalDate.parse("2026-11-20")
        val a = AlarmSchedule.skipOnce(alarm(days = everyDay), now, until)
        assertEquals("2026-11-21", a.skipDate)
        assertEquals(
            "2026-11-22T07:00",
            AlarmSchedule.nextRing(a, now, until)?.at?.toLocalDateTime()?.toString(),
        )
    }

    @Test
    fun newFieldsSurviveTheStore() {
        val a = alarm(days = everyDay).copy(
            pauseUntil = "2026-12-01",
            sound = "file:x.ogg",
            soundName = "Birds",
            gradual = true,
            ringMinutes = 5,
        )
        val back = Alarm.listFromJson(Alarm.listToJson(listOf(a)))[0]
        assertEquals(a, back)
        // Older entries (0.1.0) read with the defaults.
        val old = Alarm.fromJson(org.json.JSONObject("""{"id":"o","code":1,"hour":7,"minute":0}"""))
        assertEquals(Alarm.DEFAULT_RING_MINUTES, old.ringMinutes)
        assertFalse(old.gradual)
        assertNull(old.sound)
    }

    @Test
    fun holidaysAreSkippedOnlyWhenAsked() {
        val now = at("2026-11-18T08:00") // Wednesday, after today's ring.
        val holidays = setOf(java.time.LocalDate.parse("2026-11-19"), java.time.LocalDate.parse("2026-11-22"))
        val plain = AlarmSchedule.withTime(alarm(), 7, 0, weekdaysIL, now)
        assertEquals("2026-11-19T07:00", AlarmSchedule.nextRing(plain, now, null, holidays)?.at?.toLocalDateTime()?.toString())
        val skipping = plain.copy(skipHolidays = true)
        // Thursday is a holiday, Friday and Saturday aren't its days,
        // Sunday is a holiday too: Monday.
        assertEquals("2026-11-23T07:00", AlarmSchedule.nextRing(skipping, now, null, holidays)?.at?.toLocalDateTime()?.toString())
        // Turn off once then skips Monday, the next real ring.
        val once = AlarmSchedule.skipOnce(skipping, now, null, holidays)
        assertEquals("2026-11-23", once.skipDate)
        assertEquals("2026-11-24T07:00", AlarmSchedule.nextRing(once, now, null, holidays)?.at?.toLocalDateTime()?.toString())
    }

    @Test
    fun aWeekOfHolidaysOnAWeeklyAlarmStillFindsTheNextRing() {
        val now = at("2026-11-18T08:00")
        val weekly = AlarmSchedule.withTime(alarm(), 7, 0, setOf(4), now).copy(skipHolidays = true)
        val holidays = (0L..20L).map { java.time.LocalDate.parse("2026-11-19").plusDays(it) }.toSet()
        assertEquals("2026-12-10T07:00", AlarmSchedule.nextRing(weekly, now, null, holidays)?.at?.toLocalDateTime()?.toString())
    }

    @Test
    fun aOneTimeAlarmRingsOnAHoliday() {
        val now = at("2026-11-18T08:00")
        val once = AlarmSchedule.withTime(alarm(), 7, 0, emptySet(), now).copy(skipHolidays = true)
        val holidays = setOf(java.time.LocalDate.parse("2026-11-19"))
        assertEquals("2026-11-19T07:00", AlarmSchedule.nextRing(once, now, null, holidays)?.at?.toLocalDateTime()?.toString())
        assertTrue(Alarm.fromJson(once.toJson()).skipHolidays)
        assertFalse(Alarm.fromJson(alarm().toJson()).skipHolidays)
    }
}
