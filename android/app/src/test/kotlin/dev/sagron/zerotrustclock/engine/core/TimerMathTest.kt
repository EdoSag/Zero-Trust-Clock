package dev.sagron.zerotrustclock.engine.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TimerMathTest {
    private val fiveMin = ClockTimer(id = "t", code = 1, lengthMs = 300_000)

    @Test
    fun startPauseAndStartAgainKeepsWhatWasLeft() {
        val running = TimerMath.start(fiveMin, 1_000)
        assertEquals(301_000L, running.endsAt)
        assertTrue(running.running)
        val paused = TimerMath.pause(running, 61_000)
        assertNull(paused.endsAt)
        assertEquals(240_000L, paused.leftMs)
        assertTrue(paused.paused)
        val again = TimerMath.start(paused, 100_000)
        assertEquals(340_000L, again.endsAt)
        assertEquals(240_000L, again.left(100_000))
    }

    @Test
    fun addMinuteInEveryState() {
        assertEquals(360_000L, TimerMath.addMinute(fiveMin, 0).leftMs)
        val running = TimerMath.start(fiveMin, 0)
        assertEquals(360_000L, TimerMath.addMinute(running, 10).endsAt)
        val ringing = TimerMath.ring(TimerMath.start(fiveMin, 0))
        assertTrue(ringing.ringing)
        val more = TimerMath.addMinute(ringing, 400_000)
        assertFalse(more.ringing)
        assertEquals(460_000L, more.endsAt)
        // Reset still goes back to the length it was set to.
        assertEquals(300_000L, TimerMath.reset(more).leftMs)
    }

    @Test
    fun addMinuteStopsAtTheLongestTimer() {
        val almost = fiveMin.copy(lengthMs = ClockTimer.MAX_MS, leftMs = ClockTimer.MAX_MS - 1_000)
        assertEquals(ClockTimer.MAX_MS, TimerMath.addMinute(almost, 0).leftMs)
    }

    @Test
    fun resetStopsRingingAndGoesBackToTheLength() {
        val ringing = TimerMath.ring(TimerMath.start(fiveMin, 0))
        val reset = TimerMath.reset(ringing)
        assertFalse(reset.ringing)
        assertNull(reset.endsAt)
        assertEquals(300_000L, reset.leftMs)
        assertFalse(reset.paused)
    }

    @Test
    fun dueAreOnlyRunningTimersAtTheirEnd() {
        val a = TimerMath.start(fiveMin.copy(id = "a"), 0)
        val b = TimerMath.start(fiveMin.copy(id = "b", leftMs = 600_000), 0)
        val c = fiveMin.copy(id = "c")
        val ringing = TimerMath.ring(a.copy(id = "d"))
        assertEquals(listOf("a"), TimerMath.due(listOf(a, b, c, ringing), 300_000).map { it.id })
        assertEquals(emptyList<String>(), TimerMath.due(listOf(a, b, c), 299_999).map { it.id })
    }

    @Test
    fun timersRoundTripAsJson() {
        val list = listOf(TimerMath.start(fiveMin.copy(label = "Pasta"), 5), fiveMin.copy(id = "b", code = 2))
        assertEquals(list, ClockTimer.listFromJson(ClockTimer.listToJson(list)))
        assertEquals(3, TimerMath.freeCode(listOf(fiveMin, fiveMin.copy(code = 2))))
    }

    @Test
    fun theWidgetShowsTheRingingThenTheSoonestThenPausedThenSet() {
        assertNull(TimerMath.featured(emptyList()))
        val set = fiveMin.copy(id = "set", code = 1, createdAt = 1)
        val newerSet = fiveMin.copy(id = "set2", code = 2, createdAt = 9)
        assertEquals("set2", TimerMath.featured(listOf(set, newerSet))!!.id)
        val paused = TimerMath.pause(TimerMath.start(fiveMin.copy(id = "paused", code = 3), 0), 1_000)
        assertEquals("paused", TimerMath.featured(listOf(set, newerSet, paused))!!.id)
        val late = TimerMath.start(fiveMin.copy(id = "late", code = 4), 50_000)
        val soon = TimerMath.start(fiveMin.copy(id = "soon", code = 5, lengthMs = 60_000, leftMs = 60_000), 50_000)
        assertEquals("soon", TimerMath.featured(listOf(set, paused, late, soon))!!.id)
        val ringing = TimerMath.ring(TimerMath.start(fiveMin.copy(id = "ringing", code = 6), 0))
        assertEquals("ringing", TimerMath.featured(listOf(set, paused, late, soon, ringing))!!.id)
    }

    @Test
    fun stopwatchCountsLapsAndPauses() {
        var s = Stopwatch().start(1_000)
        s = s.lap(3_000)
        s = s.pause(5_000)
        assertEquals(4_000L, s.elapsed(99_000))
        // A lap press while paused does nothing.
        assertEquals(s, s.lap(6_000))
        s = s.start(10_000).lap(11_000)
        assertEquals(listOf(2_000L, 5_000L), s.laps)
        assertEquals(s, Stopwatch.fromJson(s.toJson()))
        assertTrue(s.reset().zero)
    }
}
