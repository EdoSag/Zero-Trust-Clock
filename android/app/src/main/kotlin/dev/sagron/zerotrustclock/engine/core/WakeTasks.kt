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

    /** Scan the code saved with the alarm (a QR code or a barcode). */
    const val SCAN = "scan"
    val ALL = setOf(MATH, SHAKE, SCAN)

    /** Problems to solve, and shakes to make. */
    const val MATH_PROBLEMS = 3
    const val SHAKES = 30

    /** Null for anything that isn't a known task. */
    fun parse(value: String?): String? = value?.takeIf { it in ALL }

    /**
     * The task as an alarm can keep it: scanning needs a saved code
     * ([code], see [codeHash]); without one there is no task.
     */
    fun parse(value: String?, code: String?): String? {
        val task = parse(value)
        return if (task == SCAN && parseCode(code) == null) null else task
    }

    /**
     * What is kept of a scanned code: its SHA-256, in hex. Enough to know
     * the same code again, and nothing of what the code says.
     */
    fun codeHash(text: String): String =
        java.security.MessageDigest.getInstance("SHA-256")
            .digest(text.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 0xff) }

    /** [code] when it is a [codeHash], else null. */
    fun parseCode(code: String?): String? =
        code?.takeIf { it.length == 64 && it.all { c -> c in '0'..'9' || c in 'a'..'f' } }
}

/** What the volume buttons do while an alarm rings on its screen. */
object VolumeButtons {
    const val VOLUME = "volume"
    const val SNOOZE = "snooze"
    const val DISMISS = "dismiss"

    /** [VOLUME] for anything unknown. */
    fun parse(value: String?): String = when (value) {
        SNOOZE, DISMISS -> value
        else -> VOLUME
    }
}

/** "Ring at least this loud": the alarm volume a ring starts at. */
object RingVolume {
    /** The choices, in percent of the phone's loudest. 0: off. */
    val CHOICES = listOf(0, 30, 50, 70, 100)

    fun parse(percent: Int): Int = if (percent in CHOICES) percent else 0

    /**
     * The level to ring at, of [max] steps: [current], or the first step
     * that is at least [percent] of the loudest when that is higher.
     */
    fun atLeast(current: Int, max: Int, percent: Int): Int {
        if (max <= 0 || percent <= 0) return current
        val floor = ((max * percent.coerceAtMost(100) + 99) / 100).coerceIn(1, max)
        return maxOf(current, floor)
    }
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
    /** Shakes already counted (the ring screen was recreated). */
    start: Int = 0,
) {
    var count = start
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
