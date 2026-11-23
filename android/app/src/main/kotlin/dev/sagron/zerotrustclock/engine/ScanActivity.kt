package dev.sagron.zerotrustclock.engine

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.params.OutputConfiguration
import android.hardware.camera2.params.SessionConfiguration
import android.media.Image
import android.media.ImageReader
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Size
import android.view.Gravity
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.TextView
import android.widget.Toast
import dev.sagron.zerotrustclock.R
import dev.sagron.zerotrustclock.engine.core.CodeReader
import dev.sagron.zerotrustclock.engine.core.WakeTasks
import java.util.concurrent.Executor
import kotlin.math.abs

/**
 * The camera for the "scan a code" wake-up task. Two uses:
 *
 * - Saving (from the alarm editor): the first code seen twice is the
 *   answer, as its hash (WakeTasks.codeHash). The code's text is not kept.
 * - Waking (from the ring screen, over the lock screen): it looks for the
 *   alarm's saved code and dismisses the alarm when it sees it. When the
 *   camera can't be used the ring screen is told, and asks for sums
 *   instead, so an alarm can always be dismissed.
 *
 * Plain Android views and Camera2 (no Flutter, no Google services), so it
 * also works before the phone's first unlock. Frames are read on the
 * phone and never stored.
 */
class ScanActivity : Activity(), TextureView.SurfaceTextureListener {
    /** Waking: the saved code to find, and the alarm it dismisses. Null: saving. */
    private var expected: String? = null
    private var alarmId: String? = null

    private val main = Handler(Looper.getMainLooper())
    private var thread: HandlerThread? = null
    private var worker: Handler? = null
    private var camera: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var reader: ImageReader? = null
    private var request: CaptureRequest.Builder? = null
    private var size = Size(1280, 960)
    private var hasLight = false
    private var light = false

    @Volatile
    private var resumed = false

    @Volatile
    private var finished = false
    private var opening = false
    private var askedPermission = false

    private val codes = CodeReader()
    private var luma = ByteArray(0)

    /** Saving: the code seen last, to take it only when seen twice. */
    private var seen: String? = null

    private val showHint = Runnable { hint().setText(hintText()) }

    /** Waking: closes when the ring ended some other way (snoozed, timed out). */
    private val watchRing: Runnable = object : Runnable {
        override fun run() {
            if (RingService.ringingId != alarmId) {
                finished = true
                finish()
            } else {
                main.postDelayed(this, 1_000L)
            }
        }
    }

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(Loc.wrap(base))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        expected = WakeTasks.parseCode(intent?.getStringExtra(EXTRA_EXPECT))
        alarmId = intent?.getStringExtra(EXTRA_ALARM)
        if (expected != null) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(R.layout.activity_scan)
        askedPermission = savedInstanceState?.getBoolean(STATE_ASKED) ?: false
        hint().setText(hintText())
        findViewById<View>(R.id.scan_cancel).setOnClickListener { finish() }
        findViewById<View>(R.id.scan_light).setOnClickListener { toggleLight() }
        preview().surfaceTextureListener = this
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putBoolean(STATE_ASKED, askedPermission)
    }

    private fun hint(): TextView = findViewById(R.id.scan_hint)

    private fun preview(): TextureView = findViewById(R.id.scan_preview)

    private fun hintText(): Int = if (expected != null) R.string.scan_hint_wake else R.string.scan_hint_save

    override fun onResume() {
        super.onResume()
        resumed = true
        if (expected != null) main.post(watchRing)
        thread = HandlerThread("ztclock-scan").also {
            it.start()
            worker = Handler(it.looper)
        }
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            // Waking is no time to ask: the ring screen has sums instead.
            if (expected != null || askedPermission) {
                unavailable()
            } else {
                askedPermission = true
                requestPermissions(arrayOf(Manifest.permission.CAMERA), REQUEST_CAMERA)
            }
            return
        }
        if (preview().isAvailable) open()
    }

    override fun onPause() {
        resumed = false
        main.removeCallbacks(watchRing)
        main.removeCallbacks(showHint)
        close()
        thread?.quitSafely()
        thread = null
        worker = null
        super.onPause()
    }

    override fun onStop() {
        super.onStop()
        // Waking: never left open behind the ring screen, where it could
        // come back later looking for another alarm's code.
        if (expected != null && !isChangingConfigurations) finish()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, results: IntArray) {
        if (requestCode != REQUEST_CAMERA) return
        if (results.isNotEmpty() && results[0] == PackageManager.PERMISSION_GRANTED) {
            if (resumed && preview().isAvailable) open()
        } else {
            unavailable()
        }
    }

    override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
        if (resumed && checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) open()
    }

    override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {}

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
        close()
        return true
    }

    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {}

    /** The camera can't be used. Waking: the ring screen asks for sums instead. */
    private fun unavailable() {
        if (finished) return
        finished = true
        if (expected != null) {
            unavailableFor = alarmId
        } else {
            Toast.makeText(this, R.string.scan_no_camera, Toast.LENGTH_LONG).show()
        }
        setResult(RESULT_CANCELED)
        finish()
    }

    private fun open() {
        if (opening || camera != null || finished) return
        val handler = worker ?: return
        try {
            val manager = getSystemService(CameraManager::class.java) ?: return unavailable()
            val ids = manager.cameraIdList
            val id = ids.firstOrNull {
                manager.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) ==
                    CameraMetadata.LENS_FACING_BACK
            } ?: ids.firstOrNull() ?: return unavailable()
            val about = manager.getCameraCharacteristics(id)
            size = pickSize(about)
            hasLight = about.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            fitPreview()
            opening = true
            manager.openCamera(
                id,
                object : CameraDevice.StateCallback() {
                    override fun onOpened(device: CameraDevice) {
                        main.post {
                            opening = false
                            if (!resumed || finished) {
                                device.close()
                            } else {
                                camera = device
                                startSession(device)
                            }
                        }
                    }

                    override fun onDisconnected(device: CameraDevice) {
                        device.close()
                        main.post {
                            opening = false
                            if (camera === device) camera = null
                            // Taken by another app or switched off by a
                            // policy, also instead of ever opening: no
                            // frames will come. The alarm asks for sums.
                            // Not when this screen itself is leaving.
                            if (resumed) unavailable()
                        }
                    }

                    override fun onError(device: CameraDevice, error: Int) {
                        device.close()
                        main.post {
                            opening = false
                            if (camera === device) camera = null
                            unavailable()
                        }
                    }
                },
                handler,
            )
        } catch (_: Exception) {
            // No permission after all, or the camera is in use or switched off.
            opening = false
            unavailable()
        }
    }

    /**
     * A 4:3 size near 1280 × 960 that both the preview and the frames can
     * use: sharp enough for a small code, light enough to read every frame.
     */
    private fun pickSize(about: CameraCharacteristics): Size {
        val map = about.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP) ?: return size
        val frames = map.getOutputSizes(ImageFormat.YUV_420_888)?.toSet() ?: return size
        val both = (map.getOutputSizes(SurfaceTexture::class.java) ?: emptyArray())
            .filter { it in frames && it.width in 640..1920 && it.height <= 1440 }
        val wide = both.filter { it.width * 3 == it.height * 4 }
        return (wide.ifEmpty { both }).minByOrNull { abs(it.width * it.height - 1280 * 960) } ?: size
    }

    /** The picture keeps its shape: as large as fits the box, never stretched. */
    private fun fitPreview() {
        val box = findViewById<View>(R.id.scan_box)
        box.post {
            if (box.width == 0 || box.height == 0) return@post
            // Held upright, the picture's long side is its height.
            val long = maxOf(size.width, size.height).toFloat()
            val short = minOf(size.width, size.height).toFloat()
            var w = box.width
            var h = (w * long / short).toInt()
            if (h > box.height) {
                h = box.height
                w = (h * short / long).toInt()
            }
            preview().layoutParams = FrameLayout.LayoutParams(w, h, Gravity.CENTER)
        }
    }

    private fun startSession(device: CameraDevice) {
        val handler = worker ?: return
        val texture = preview().surfaceTexture ?: return
        try {
            texture.setDefaultBufferSize(size.width, size.height)
            val surface = Surface(texture)
            val frames = ImageReader.newInstance(size.width, size.height, ImageFormat.YUV_420_888, 2)
            frames.setOnImageAvailableListener({ onFrame(it) }, handler)
            reader = frames
            val builder = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                addTarget(surface)
                addTarget(frames.surface)
                set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
            }
            request = builder
            device.createCaptureSession(
                SessionConfiguration(
                    SessionConfiguration.SESSION_REGULAR,
                    listOf(OutputConfiguration(surface), OutputConfiguration(frames.surface)),
                    Executor { handler.post(it) },
                    object : CameraCaptureSession.StateCallback() {
                        override fun onConfigured(started: CameraCaptureSession) {
                            try {
                                started.setRepeatingRequest(builder.build(), null, handler)
                            } catch (_: Exception) {
                                main.post { unavailable() }
                                return
                            }
                            main.post {
                                if (camera !== device) return@post
                                session = started
                                findViewById<View>(R.id.scan_light).visibility =
                                    if (hasLight) View.VISIBLE else View.GONE
                            }
                        }

                        override fun onConfigureFailed(failed: CameraCaptureSession) {
                            main.post { unavailable() }
                        }
                    },
                ),
            )
        } catch (_: Exception) {
            unavailable()
        }
    }

    /** On the camera's thread: one frame, read for a code. */
    private fun onFrame(frames: ImageReader) {
        val image = try {
            frames.acquireLatestImage()
        } catch (_: Exception) {
            null
        } ?: return
        try {
            if (finished) return
            val text = codes.read(brightness(image), image.width, image.height) ?: return
            main.post { onCode(text) }
        } catch (_: Exception) {
            // A frame that can't be read is skipped.
        } finally {
            image.close()
        }
    }

    /** The frame's brightness, row by row without the rows' padding. */
    private fun brightness(image: Image): ByteArray {
        val w = image.width
        val h = image.height
        if (luma.size != w * h) luma = ByteArray(w * h)
        val plane = image.planes[0]
        val buffer = plane.buffer
        val stride = plane.rowStride
        if (stride == w) {
            buffer.position(0)
            buffer.get(luma, 0, minOf(buffer.remaining(), w * h))
        } else {
            for (row in 0 until h) {
                buffer.position(row * stride)
                buffer.get(luma, row * w, w)
            }
        }
        return luma
    }

    private fun onCode(text: String) {
        if (finished) return
        val hash = WakeTasks.codeHash(text)
        val want = expected
        if (want == null) {
            // Saving: only a code read the same twice, so a misread is never saved.
            if (hash != seen) {
                seen = hash
                return
            }
            finished = true
            setResult(RESULT_OK, Intent().putExtra(EXTRA_CODE, hash))
            finish()
        } else if (hash == want) {
            finished = true
            // Only the alarm this camera was opened for.
            if (RingService.ringingId == alarmId) {
                RingService.send(this, RingService.ACTION_DISMISS, taskDone = true)
            }
            finish()
        } else {
            hint().setText(R.string.scan_wrong)
            main.removeCallbacks(showHint)
            main.postDelayed(showHint, 2_000L)
        }
    }

    private fun toggleLight() {
        val builder = request ?: return
        val running = session ?: return
        val handler = worker ?: return
        light = !light
        findViewById<Button>(R.id.scan_light).setText(if (light) R.string.scan_light_off else R.string.scan_light)
        val on = light
        handler.post {
            try {
                builder.set(
                    CaptureRequest.FLASH_MODE,
                    if (on) CameraMetadata.FLASH_MODE_TORCH else CameraMetadata.FLASH_MODE_OFF,
                )
                running.setRepeatingRequest(builder.build(), null, handler)
            } catch (_: Exception) {
            }
        }
    }

    private fun close() {
        try {
            session?.close()
        } catch (_: Exception) {
        }
        session = null
        try {
            camera?.close()
        } catch (_: Exception) {
        }
        camera = null
        try {
            reader?.close()
        } catch (_: Exception) {
        }
        reader = null
        request = null
        light = false
    }

    companion object {
        /** Saving: the answer, the scanned code's hash. */
        const val EXTRA_CODE = "code"
        private const val EXTRA_EXPECT = "expect"
        private const val EXTRA_ALARM = "alarm"
        private const val STATE_ASKED = "asked"
        private const val REQUEST_CAMERA = 7402

        /** The ringing alarm whose scan the camera could not do. */
        @Volatile
        private var unavailableFor: String? = null

        /** True, once, when the camera could not be used for the alarm [ringingId]. */
        fun takeUnavailable(ringingId: String?): Boolean {
            val id = unavailableFor ?: return false
            unavailableFor = null
            return id == ringingId
        }

        /** Whether the scan task can be asked for: a camera, and leave to use it. */
        fun canScan(context: Context): Boolean =
            context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY) &&
                context.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

        /** Saving a code for an alarm (started for its result). */
        fun saveIntent(context: Context): Intent = Intent(context, ScanActivity::class.java)

        /** Waking: looks for [code] and dismisses the alarm [alarmId]. */
        fun wakeIntent(context: Context, alarmId: String, code: String): Intent =
            Intent(context, ScanActivity::class.java)
                // A screen of its own, always opened afresh for this alarm.
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK or
                        Intent.FLAG_ACTIVITY_NO_USER_ACTION,
                )
                .putExtra(EXTRA_ALARM, alarmId)
                .putExtra(EXTRA_EXPECT, code)
    }
}
