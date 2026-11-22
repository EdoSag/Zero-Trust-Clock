package dev.sagron.zerotrustclock.engine.core

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MorningDayTest {
    private val brief = """
        {"through": "2026-11-20", "days": {
          "2026-11-19": {"events": 6, "first": 540,
            "eventList": [{"t": 540, "title": "Team"}, {"t": 780, "title": " Lunch "},
              {"t": 900, "title": "a"}, {"t": 960, "title": "b"}, {"t": 990, "title": "c"}],
            "tasks": 1, "overdue": 2, "taskList": ["Pay rent", "", "Old one"],
            "quests": 1, "questList": ["Sleep"]}
        }}
    """.trimIndent()

    @Test
    fun aListedDay() {
        val d = MorningDay.of(brief, LocalDate.of(2026, 11, 19))!!
        assertEquals(6, d.events)
        assertEquals(540, d.firstEvent)
        assertEquals(MorningDay.LIST_MAX, d.eventList.size)
        assertEquals(Pair<Int?, String>(780, "Lunch"), d.eventList[1])
        assertEquals(1, d.tasks)
        assertEquals(2, d.overdue)
        assertEquals(listOf("Pay rent", "Old one"), d.taskList)
        assertEquals(listOf("Sleep"), d.questList)
    }

    @Test
    fun anUnlistedDayHasNothing() {
        val d = MorningDay.of(brief, LocalDate.of(2026, 11, 20))!!
        assertTrue(d.empty)
    }

    @Test
    fun beyondTheBriefOrUnreadable() {
        assertNull(MorningDay.of(brief, LocalDate.of(2026, 11, 21)))
        assertNull(MorningDay.of(null, LocalDate.of(2026, 11, 19)))
        assertNull(MorningDay.of("{not json", LocalDate.of(2026, 11, 19)))
        assertNull(MorningDay.of("""{"days": {}}""", LocalDate.of(2026, 11, 19)))
    }

    @Test
    fun badNumbersAreIgnored() {
        val d = MorningDay.of(
            """{"through": "2026-11-19", "days": {"2026-11-19": {"events": -3, "first": 5000,
              "eventList": [{"t": null, "title": "All day"}]}}}""",
            LocalDate.of(2026, 11, 19),
        )!!
        assertEquals(0, d.events)
        assertNull(d.firstEvent)
        assertEquals(Pair<Int?, String>(null, "All day"), d.eventList.single())
    }
}
