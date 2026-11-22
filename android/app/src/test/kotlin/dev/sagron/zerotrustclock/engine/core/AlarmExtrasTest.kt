package dev.sagron.zerotrustclock.engine.core

import com.google.zxing.BarcodeFormat
import com.google.zxing.MultiFormatWriter
import java.time.ZoneId
import java.time.ZonedDateTime
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AlarmExtrasTest {
    private val hash = WakeTasks.codeHash("https://example.com/bathroom")

    @Test
    fun aCodeIsKeptAsItsHashOnly() {
        assertEquals(64, hash.length)
        assertEquals(hash, WakeTasks.codeHash("https://example.com/bathroom"))
        assertNotEquals(hash, WakeTasks.codeHash("https://example.com/bathroom "))
        // SHA-256 of "abc", from the standard.
        assertEquals(
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            WakeTasks.codeHash("abc"),
        )
        assertEquals(hash, WakeTasks.parseCode(hash))
        assertNull(WakeTasks.parseCode(null))
        assertNull(WakeTasks.parseCode("abc"))
        assertNull(WakeTasks.parseCode(hash.uppercase()))
        assertNull(WakeTasks.parseCode(hash.dropLast(1) + "g"))
    }

    @Test
    fun theScanTaskNeedsASavedCode() {
        assertEquals("scan", WakeTasks.parse("scan", hash))
        assertNull(WakeTasks.parse("scan", null))
        assertNull(WakeTasks.parse("scan", "not a hash"))
        // The others don't care about a code.
        assertEquals("math", WakeTasks.parse("math", null))
        assertEquals("shake", WakeTasks.parse("shake", hash))
        assertNull(WakeTasks.parse("juggle", hash))
    }

    @Test
    fun anAlarmKeepsItsCodeAndDropsAScanTaskWithoutOne() {
        val alarm = Alarm(id = "a", code = 1, hour = 7, minute = 0, task = "scan", taskCode = hash)
        val back = Alarm.fromJson(JSONObject(alarm.toJson().toString()))
        assertEquals("scan", back.task)
        assertEquals(hash, back.taskCode)

        val json = alarm.toJson()
        json.remove("taskCode")
        val without = Alarm.fromJson(json)
        assertNull(without.task)
        assertNull(without.taskCode)
    }

    @Test
    fun volumeButtonsDefaultToTheVolume() {
        assertEquals("volume", VolumeButtons.parse(null))
        assertEquals("volume", VolumeButtons.parse("mute"))
        assertEquals("snooze", VolumeButtons.parse("snooze"))
        assertEquals("dismiss", VolumeButtons.parse("dismiss"))
    }

    @Test
    fun aRingStartsAtLeastAsLoudAsAsked() {
        // Off: as it is, even silent.
        assertEquals(0, RingVolume.atLeast(0, 7, 0))
        // 7 steps: half is step 4 (rounded up), never below one step.
        assertEquals(4, RingVolume.atLeast(0, 7, 50))
        assertEquals(4, RingVolume.atLeast(2, 7, 50))
        assertEquals(6, RingVolume.atLeast(6, 7, 50))
        assertEquals(3, RingVolume.atLeast(1, 7, 30))
        assertEquals(7, RingVolume.atLeast(3, 7, 100))
        assertEquals(1, RingVolume.atLeast(0, 2, 30))
        // A phone that reports no steps is left alone.
        assertEquals(3, RingVolume.atLeast(3, 0, 70))
        assertEquals(0, RingVolume.parse(42))
        assertEquals(70, RingVolume.parse(70))
    }

    @Test
    fun aSnoozeCanHaveAnotherLengthThanTheAlarms() {
        val now = ZonedDateTime.of(2026, 11, 21, 7, 0, 0, 0, ZoneId.of("UTC"))
        val alarm = Alarm(id = "a", code = 1, hour = 7, minute = 0, snoozeMinutes = 10)
        val at = now.toInstant().toEpochMilli()
        assertEquals(at + 10 * 60_000L, AlarmSchedule.snooze(alarm, now).snoozeUntil)
        assertEquals(at + 10 * 60_000L, AlarmSchedule.snooze(alarm, now, 0).snoozeUntil)
        assertEquals(at + 3 * 60_000L, AlarmSchedule.snooze(alarm, now, 3).snoozeUntil)
        assertEquals(at + 60 * 60_000L, AlarmSchedule.snooze(alarm, now, 500).snoozeUntil)
    }

    /** A code as a camera frame: dark on light, [scale] pixels a module, on a grey table. */
    private fun frame(text: String, format: BarcodeFormat, width: Int, height: Int): Triple<ByteArray, Int, Int> {
        val w = 640
        val h = 480
        val code = MultiFormatWriter().encode(text, format, width, height)
        val luma = ByteArray(w * h) { 170.toByte() }
        val left = (w - code.width) / 2
        val top = (h - code.height) / 2
        for (y in 0 until code.height) {
            for (x in 0 until code.width) {
                luma[(top + y) * w + left + x] = if (code.get(x, y)) 20 else 235.toByte()
            }
        }
        return Triple(luma, w, h)
    }

    /** The frame as a phone turned a quarter sees it. */
    private fun turned(luma: ByteArray, w: Int, h: Int): Triple<ByteArray, Int, Int> {
        val out = ByteArray(w * h)
        for (y in 0 until h) for (x in 0 until w) out[x * h + (h - 1 - y)] = luma[y * w + x]
        return Triple(out, h, w)
    }

    /** What the reader finds within a few frames (it tries a frame several ways in turn). */
    private fun read(reader: CodeReader, f: Triple<ByteArray, Int, Int>): String? {
        repeat(6) { reader.read(f.first, f.second, f.third)?.let { return it } }
        return null
    }

    @Test
    fun aQrCodeIsReadWhicheverWayThePhoneIsHeld() {
        val text = "https://example.com/bathroom"
        val f = frame(text, BarcodeFormat.QR_CODE, 240, 240)
        assertEquals(text, read(CodeReader(), f))
        assertEquals(text, read(CodeReader(), turned(f.first, f.second, f.third)))
    }

    @Test
    fun aBarcodeIsReadAlongAndAcross() {
        val text = "7290000066318"
        val f = frame(text, BarcodeFormat.EAN_13, 380, 120)
        assertEquals(text, read(CodeReader(), f))
        // Its lines now run along the rows: only the turned look finds it.
        assertEquals(text, read(CodeReader(), turned(f.first, f.second, f.third)))
    }

    @Test
    fun aLightOnDarkCodeIsReadToo() {
        val text = "wake up"
        val f = frame(text, BarcodeFormat.QR_CODE, 240, 240)
        val inverted = ByteArray(f.first.size) { (255 - (f.first[it].toInt() and 0xff)).toByte() }
        assertEquals(text, read(CodeReader(), Triple(inverted, f.second, f.third)))
    }

    @Test
    fun aFrameWithoutACodeIsNothing() {
        val reader = CodeReader()
        val grey = ByteArray(640 * 480) { 128.toByte() }
        repeat(6) { assertNull(reader.read(grey, 640, 480)) }
        // Too little data for the size it claims.
        assertNull(reader.read(ByteArray(10), 640, 480))
        assertNull(reader.read(ByteArray(0), 0, 0))
    }
}
