package dev.sagron.zerotrustclock.engine.core

import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WakeTasksTest {
    @Test
    fun problemsStayInAHeadSizedRange() {
        val random = Random(7)
        repeat(500) {
            val p = MathProblem.next(random)
            assertTrue(p.a in 12..39 && p.b in 3..9 && p.c in 10..89)
            assertEquals(p.a * p.b + p.c, p.answer)
            assertTrue(p.answer in 46..440)
        }
        assertEquals("23 × 7 + 15", MathProblem(23, 7, 15).text)
        assertEquals(176, MathProblem(23, 7, 15).answer)
    }

    @Test
    fun aShakeCountsOnceAndRestingDoesNot() {
        val c = ShakeCounter()
        // Lying still: gravity only.
        for (t in 0L until 1000L step 20) assertFalse(c.add(t, 0f, 0f, 9.81f))
        assertEquals(0, c.count)
        // One jolt, read several times in a row: one shake.
        assertTrue(c.add(1000, 25f, 3f, 9f))
        assertFalse(c.add(1020, 24f, 2f, 9f))
        assertFalse(c.add(1200, 23f, 2f, 9f))
        assertTrue(c.add(1300, -25f, 0f, 9f))
        assertEquals(2, c.count)
    }

    @Test
    fun onlyKnownTasksAreKept() {
        assertEquals("math", WakeTasks.parse("math"))
        assertEquals("shake", WakeTasks.parse("shake"))
        assertNull(WakeTasks.parse("qr"))
        assertNull(WakeTasks.parse(null))
    }

    @Test
    fun anAlarmKeepsItsTaskThroughJson() {
        val a = Alarm(id = "a", code = 1, hour = 7, minute = 0, task = "shake")
        assertEquals("shake", Alarm.fromJson(a.toJson()).task)
        val old = Alarm(id = "b", code = 2, hour = 7, minute = 0).toJson()
        assertNull(Alarm.fromJson(old).task)
        old.put("task", "unknown")
        assertNull(Alarm.fromJson(old).task)
    }
}
