package dev.sagron.zerotrustclock.engine.core

import kotlin.math.sqrt
import kotlin.random.Random

/**
 * Wake-up tasks: an alarm with one is only dismissed after the task is
 * done, so it can't be silenced half asleep. Snooze still works.
 */
object WakeTasks {
    const val MATH = "math"
    const val SHAKE = "shake"
    val ALL = setOf(MATH, SHAKE)

    /** Problems to solve, and shakes to make. */
    const val MATH_PROBLEMS = 3
    const val SHAKES = 30

    /** Null for anything that isn't a known task. */
    fun parse(value: String?): String? = value?.takeIf { it in ALL }
}

/** "23 × 7 + 15": needs a little thought, never a pen. */
data class MathProblem(val a: Int, val b: Int, val c: Int) {
    val answer: Int get() = a * b + c
    val text: String get() = "$a × $b + $c"

    companion object {
        fun next(random: Random = Random.Default): MathProblem = MathProblem(
            a = random.nextInt(12, 40),
            b = random.nextInt(3, 10),
            c = random.nextInt(10, 90),
        )
    }
}

/**
 * Counts shakes from accelerometer readings (m/s², gravity included). A
 * shake is a jolt well above gravity; jolts closer together than
 * [gapMs] are one shake, so a phone dropped on a bed counts once.
 */
class ShakeCounter(
    private val threshold: Double = 2.2 * 9.81,
    private val gapMs: Long = 250,
) {
    var count = 0
        private set
    private var last = Long.MIN_VALUE

    /** Returns true when this reading counted as a new shake. */
    fun add(atMs: Long, x: Float, y: Float, z: Float): Boolean {
        val g = sqrt((x * x + y * y + z * z).toDouble())
        if (g < threshold) return false
        if (last != Long.MIN_VALUE && atMs - last < gapMs) return false
        last = atMs
        count++
        return true
    }
}
