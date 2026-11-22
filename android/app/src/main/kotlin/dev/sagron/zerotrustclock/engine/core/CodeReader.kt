package dev.sagron.zerotrustclock.engine.core

import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.LuminanceSource
import com.google.zxing.MultiFormatReader
import com.google.zxing.PlanarYUVLuminanceSource
import com.google.zxing.ReaderException
import com.google.zxing.common.HybridBinarizer

/**
 * Finds a QR code or a barcode in camera frames, on the phone (ZXing; no
 * picture leaves the app or is kept).
 */
class CodeReader {
    private val reader = MultiFormatReader().apply {
        setHints(
            mapOf(
                // Kinds with a checksum, so a blurry frame is not misread.
                DecodeHintType.POSSIBLE_FORMATS to listOf(
                    BarcodeFormat.QR_CODE,
                    BarcodeFormat.DATA_MATRIX,
                    BarcodeFormat.AZTEC,
                    BarcodeFormat.PDF_417,
                    BarcodeFormat.EAN_13,
                    BarcodeFormat.EAN_8,
                    BarcodeFormat.UPC_A,
                    BarcodeFormat.UPC_E,
                    BarcodeFormat.CODE_128,
                ),
            ),
        )
    }
    private var frame = 0
    private var turned = ByteArray(0)

    /**
     * One frame's brightness ([luma]: [width] × [height] bytes, row by
     * row). The text of the code in it, or null.
     *
     * A barcode is only read when its lines cross the rows, so every other
     * frame is looked at turned a quarter. Now and then a frame is also
     * tried light on dark.
     */
    fun read(luma: ByteArray, width: Int, height: Int): String? {
        if (width <= 0 || height <= 0 || luma.size < width * height) return null
        frame = (frame + 1) % 6
        var source: LuminanceSource = if (frame % 2 == 0) {
            PlanarYUVLuminanceSource(luma, width, height, 0, 0, width, height, false)
        } else {
            PlanarYUVLuminanceSource(turn(luma, width, height), height, width, 0, 0, height, width, false)
        }
        if (frame >= 4) source = source.invert()
        return try {
            reader.decodeWithState(BinaryBitmap(HybridBinarizer(source))).text?.takeIf { it.isNotEmpty() }
        } catch (_: ReaderException) {
            null
        } catch (_: RuntimeException) {
            // A frame the reader trips over is a frame without a code.
            null
        } finally {
            reader.reset()
        }
    }

    /** [luma] turned a quarter clockwise: [height] wide, [width] high. */
    private fun turn(luma: ByteArray, width: Int, height: Int): ByteArray {
        if (turned.size != width * height) turned = ByteArray(width * height)
        for (y in 0 until height) {
            val row = y * width
            val column = height - 1 - y
            for (x in 0 until width) turned[x * height + column] = luma[row + x]
        }
        return turned
    }
}
