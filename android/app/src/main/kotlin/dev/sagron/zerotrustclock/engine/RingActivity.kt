package dev.sagron.zerotrustclock.engine

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.text.Editable
import android.text.TextWatcher
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.TextView
import android.window.OnBackInvokedDispatcher
import dev.sagron.zerotrustclock.R
import dev.sagron.zerotrustclock.engine.core.Alarm
import dev.sagron.zerotrustclock.engine.core.MathProblem
import dev.sagron.zerotrustclock.engine.core.ShakeCounter
import dev.sagron.zerotrustclock.engine.core.VolumeButtons
import dev.sagron.zerotrustclock.engine.core.WakeTasks

/**
 * The full-screen ring screen, shown over the lock screen. Plain Android
 * views (no Flutter), so it also opens before the phone's first unlock.
 */
class RingActivity : Activity(), SensorEventListener {
    private val closeWhenEnded: () -> Unit = { finish() }

    /** The wake-up task on screen (WakeTasks), or null. */
    private var task: String? = null
    private var solved = 0
    private var problem: MathProblem? = null
    private var shakes = ShakeCounter()

    /** Shakes counted before the screen was recreated. */
    private var shakesDone = 0

    /** The alarm the task on screen belongs to. */
    private var taskFor: String? = null
    private var listening = false

    /** The camera could not be used for the scan task: sums instead. */
    private var scanFailed = false

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(Loc.wrap(base))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(R.layout.activity_ring)
        // The volume buttons change the alarm volume, not the music's.
        volumeControlStream = AudioManager.STREAM_ALARM
        // Back does not silence an alarm: only Snooze and Dismiss do.
        if (Build.VERSION.SDK_INT >= 33) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
            ) { }
        }
        findViewById<View>(R.id.ring_snooze).setOnClickListener {
            RingService.send(this, RingService.ACTION_SNOOZE)
        }
        // Dismiss is a slide, so a sleepy tap can't silence the alarm.
        findViewById<SlideToDismiss>(R.id.ring_dismiss).onDismiss = { dismiss() }
        findViewById<View>(R.id.ring_task_scan).setOnClickListener { openScanner() }
        findViewById<EditText>(R.id.ring_task_answer).addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) = checkAnswer(s?.toString().orEmpty())
        })
        if (savedInstanceState?.getBoolean(STATE_TASK) == true) {
            // Progress only counts for the alarm it was made on.
            if (savedInstanceState.getString(STATE_FOR) == RingService.ringingId) {
                solved = savedInstanceState.getInt(STATE_SOLVED)
                shakesDone = savedInstanceState.getInt(STATE_SHAKES)
                scanFailed = savedInstanceState.getBoolean(STATE_SCAN_FAILED)
            }
            // Not straight back into the camera: its button is on screen.
            startTask(openScanner = false)
        } else if (intent?.getBooleanExtra(EXTRA_TASK, false) == true) {
            startTask()
        }
        show()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra(EXTRA_TASK, false)) startTask()
        show()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putBoolean(STATE_TASK, task != null)
        outState.putInt(STATE_SOLVED, solved)
        outState.putInt(STATE_SHAKES, shakes.count)
        outState.putString(STATE_FOR, taskFor)
        outState.putBoolean(STATE_SCAN_FAILED, scanFailed)
    }

    private fun ringingAlarm(): Alarm? {
        val id = RingService.ringingId ?: return null
        return AlarmStore.load(this).firstOrNull { it.id == id }
    }

    private fun ringingTask(): String? = ringingAlarm()?.task

    /** The slider, or a volume button set to dismiss: the task first, when there is one. */
    private fun dismiss() {
        if (ringingTask() != null) startTask() else RingService.send(this, RingService.ACTION_DISMISS)
    }

    /**
     * The volume buttons snooze or dismiss when the settings say so; a
     * dismiss still goes through the wake-up task.
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val volume = event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
            event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
        val what = if (volume) EnginePrefs.volumeButtons(this) else VolumeButtons.VOLUME
        if (what == VolumeButtons.VOLUME) return super.dispatchKeyEvent(event)
        if (event.action == KeyEvent.ACTION_UP && !event.isCanceled) {
            if (what == VolumeButtons.SNOOZE) RingService.send(this, RingService.ACTION_SNOOZE) else dismiss()
        }
        return true
    }

    /** Swaps the slider for the alarm's wake-up task. */
    private fun startTask(openScanner: Boolean = true) {
        var kind = ringingTask() ?: return
        val sensors = getSystemService(SensorManager::class.java)
        if (kind == WakeTasks.SHAKE && sensors?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) == null) {
            kind = WakeTasks.MATH // No motion sensor: sums instead.
        }
        if (kind == WakeTasks.SCAN && (scanFailed || !ScanActivity.canScan(this))) {
            kind = WakeTasks.MATH // No camera to scan with: sums instead.
        }
        if (task == kind && taskFor == RingService.ringingId) {
            if (kind == WakeTasks.SCAN && openScanner) openScanner()
            return
        }
        if (task != null) resetTask()
        task = kind
        taskFor = RingService.ringingId
        findViewById<View>(R.id.ring_dismiss).visibility = View.GONE
        findViewById<View>(R.id.ring_task).visibility = View.VISIBLE
        val title = findViewById<TextView>(R.id.ring_task_title)
        val answer = findViewById<EditText>(R.id.ring_task_answer)
        val scan = findViewById<View>(R.id.ring_task_scan)
        val sum = findViewById<View>(R.id.ring_task_problem)
        scan.visibility = if (kind == WakeTasks.SCAN) View.VISIBLE else View.GONE
        sum.visibility = if (kind == WakeTasks.SCAN) View.GONE else View.VISIBLE
        if (kind == WakeTasks.SCAN) {
            title.text = getString(R.string.ring_task_scan)
            answer.visibility = View.GONE
            findViewById<TextView>(R.id.ring_task_progress).text = ""
            if (openScanner) openScanner()
        } else if (kind == WakeTasks.MATH) {
            title.text = getString(R.string.ring_task_math, WakeTasks.MATH_PROBLEMS)
            answer.visibility = View.VISIBLE
            nextProblem(wrong = false)
            answer.requestFocus()
            answer.post {
                getSystemService(InputMethodManager::class.java)
                    ?.showSoftInput(answer, InputMethodManager.SHOW_IMPLICIT)
            }
        } else {
            title.text = getString(R.string.ring_task_shake)
            answer.visibility = View.GONE
            shakes = ShakeCounter(start = shakesDone)
            showShakes()
            listen()
        }
    }

    /**
     * The camera, to scan the alarm's saved code. It dismisses the alarm
     * itself when it sees the code; this screen then closes with the ring.
     */
    private fun openScanner() {
        val alarm = ringingAlarm()
        val code = alarm?.taskCode
        if (task != WakeTasks.SCAN || code == null) return
        try {
            startActivity(ScanActivity.wakeIntent(this, alarm.id, code))
        } catch (_: Exception) {
            scanUnavailable()
        }
    }

    /** The camera can't be used: the task becomes sums, so the alarm can still be dismissed. */
    private fun scanUnavailable() {
        if (task != WakeTasks.SCAN) return
        scanFailed = true
        task = null
        startTask()
    }

    private fun nextProblem(wrong: Boolean) {
        problem = MathProblem.next()
        findViewById<TextView>(R.id.ring_task_problem).text = problem?.text
        findViewById<EditText>(R.id.ring_task_answer).text.clear()
        findViewById<TextView>(R.id.ring_task_progress).text = if (wrong) {
            getString(R.string.ring_task_wrong)
        } else {
            getString(R.string.ring_task_progress, solved + 1, WakeTasks.MATH_PROBLEMS)
        }
    }

    /** Checked as it is typed: right moves on, a full wrong answer starts a new sum. */
    private fun checkAnswer(typed: String) {
        val p = problem ?: return
        if (task != WakeTasks.MATH || typed.isEmpty()) return
        val want = p.answer.toString()
        if (typed == want) {
            solved++
            if (solved >= WakeTasks.MATH_PROBLEMS) done() else nextProblem(wrong = false)
        } else if (typed.length >= want.length) {
            nextProblem(wrong = true)
        }
    }

    private fun showShakes() {
        findViewById<TextView>(R.id.ring_task_problem).text =
            getString(R.string.ring_task_progress, shakes.count, WakeTasks.SHAKES)
        findViewById<TextView>(R.id.ring_task_progress).text = ""
    }

    private fun listen() {
        if (listening || task != WakeTasks.SHAKE) return
        val sensors = getSystemService(SensorManager::class.java) ?: return
        val accel = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) ?: return
        listening = sensors.registerListener(this, accel, SensorManager.SENSOR_DELAY_GAME)
    }

    private fun unlisten() {
        if (!listening) return
        listening = false
        getSystemService(SensorManager::class.java)?.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (task != WakeTasks.SHAKE) return
        val v = event.values
        if (!shakes.add(SystemClock.elapsedRealtime(), v[0], v[1], v[2])) return
        showShakes()
        if (shakes.count >= WakeTasks.SHAKES) done()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun done() {
        unlisten()
        task = null
        RingService.send(this, RingService.ACTION_DISMISS, taskDone = true)
    }

    override fun onStart() {
        super.onStart()
        listen()
        RingService.onEnded = closeWhenEnded
        // Opened from an old notification after the ring ended.
        if (RingService.ringingId == null) finish()
        // Back on screen, maybe on a phone locked in the meantime: the
        // label is read again, and stays away while the phone is locked.
        show()
    }

    override fun onResume() {
        super.onResume()
        // Back from a camera that could not be used: sums instead.
        if (ScanActivity.takeUnavailable(RingService.ringingId)) scanUnavailable()
    }

    override fun onStop() {
        unlisten()
        if (RingService.onEnded === closeWhenEnded) RingService.onEnded = null
        super.onStop()
    }

    /**
     * Back to the slider with no progress: another alarm took over the
     * ring screen, and its own task (if any) starts from the beginning.
     */
    private fun resetTask() {
        unlisten()
        task = null
        taskFor = null
        solved = 0
        shakesDone = 0
        scanFailed = false
        problem = null
        shakes = ShakeCounter()
        val answer = findViewById<EditText>(R.id.ring_task_answer)
        answer.text.clear()
        getSystemService(InputMethodManager::class.java)?.hideSoftInputFromWindow(answer.windowToken, 0)
        findViewById<View>(R.id.ring_task).visibility = View.GONE
        findViewById<View>(R.id.ring_dismiss).visibility = View.VISIBLE
    }

    private fun show() {
        val id = RingService.ringingId
        if (task != null && taskFor != id) resetTask()
        val alarm = if (id == null) null else AlarmStore.load(this).firstOrNull { it.id == id }
        val label = if (alarm == null) "" else AlarmNotifications.visibleLabel(this, alarm)
        val view = findViewById<TextView>(R.id.ring_label)
        view.text = label.ifEmpty { getString(R.string.ring_alarm) }
    }

    companion object {
        /** Opens on the wake-up task (Dismiss from the notification or the app). */
        const val EXTRA_TASK = "task"
        private const val STATE_TASK = "task"
        private const val STATE_SOLVED = "solved"
        private const val STATE_SHAKES = "shakes"
        private const val STATE_FOR = "taskFor"
        private const val STATE_SCAN_FAILED = "scanFailed"

        fun taskIntent(context: Context): Intent = Intent(context, RingActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
            .putExtra(EXTRA_TASK, true)
    }

    /** The same on Android 12 and older. */
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
    }
}
