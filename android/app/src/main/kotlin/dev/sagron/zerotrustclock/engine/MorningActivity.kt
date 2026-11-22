package dev.sagron.zerotrustclock.engine

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.UserManager
import android.text.format.DateFormat
import android.util.AtomicFile
import android.util.TypedValue
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import dev.sagron.zerotrustclock.R
import dev.sagron.zerotrustclock.engine.core.MorningDay
import java.io.File
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Calendar

/**
 * What the morning screen shows: today's events from ZT Calendar, tasks
 * from ZT Tasks and quests from ZT Quests, worked out by the app at its
 * last unlock (the engine can't open the other apps' data on its own).
 * In the phone's normal storage, so it is unreadable before the first
 * unlock, and then there is simply no morning screen.
 */
object MorningBrief {
    private const val FILE = "morning_brief.json"

    private fun file(context: Context): AtomicFile? {
        val users = context.getSystemService(UserManager::class.java)
        if (users?.isUserUnlocked != true) return null
        return AtomicFile(File(context.applicationContext.filesDir, FILE))
    }

    /** Keeps the brief the app worked out; null forgets it (signed out). */
    fun save(context: Context, json: String?) {
        val f = file(context) ?: return
        if (json == null) {
            f.delete()
            return
        }
        val out = f.startWrite()
        try {
            out.write(json.toByteArray())
            f.finishWrite(out)
        } catch (e: Exception) {
            f.failWrite(out)
            throw e
        }
    }

    fun today(context: Context): MorningDay? {
        val f = file(context) ?: return null
        val text = try {
            String(f.readFully())
        } catch (_: Exception) {
            return null
        }
        return MorningDay.of(text, LocalDate.now(ZoneId.systemDefault()))
    }

    /** True when a dismissed alarm is followed by the morning screen. */
    fun shouldShow(context: Context): Boolean =
        EnginePrefs.morning(context) != "off" && today(context) != null
}

/**
 * The day ahead, right after an alarm is dismissed on its ring screen:
 * how many events, tasks and quests today has, and with "details" on in
 * Settings, what they are. A row opens its app (after the phone's unlock).
 */
class MorningActivity : Activity() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(Loc.wrap(base))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setShowWhenLocked(true)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(R.layout.activity_morning)
        findViewById<View>(R.id.morning_close).setOnClickListener { finish() }
        val day = MorningBrief.today(this)
        if (day == null) {
            finish()
            return
        }
        show(day, EnginePrefs.morning(this) == "details")
    }

    private fun show(day: MorningDay, details: Boolean) {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        findViewById<TextView>(R.id.morning_hello).setText(
            when {
                hour < 12 -> R.string.morning_hello
                hour < 18 -> R.string.morning_hello_afternoon
                else -> R.string.morning_hello_evening
            },
        )
        findViewById<TextView>(R.id.morning_date).text =
            LocalDate.now().format(DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL).withLocale(resources.configuration.locales[0]))
        val rows = findViewById<LinearLayout>(R.id.morning_rows)
        rows.removeAllViews()
        if (day.empty) {
            rows.addView(line(getString(R.string.morning_nothing), big = true))
        } else {
            val events = if (day.events == 0) {
                getString(R.string.morning_no_events)
            } else {
                val count = resources.getQuantityString(R.plurals.morning_events, day.events, day.events)
                day.firstEvent?.let { getString(R.string.morning_first_at, count, time(it)) } ?: count
            }
            section(rows, events, CALENDAR) {
                if (details) {
                    for ((t, title) in day.eventList) {
                        rows.addView(line(if (t == null) title else "${time(t)}  $title"))
                    }
                    more(rows, day.events - day.eventList.size)
                }
            }
            val tasks = when {
                day.tasks == 0 && day.overdue == 0 -> getString(R.string.morning_no_tasks)
                day.overdue == 0 -> resources.getQuantityString(R.plurals.morning_tasks, day.tasks, day.tasks)
                else -> getString(
                    R.string.morning_tasks_overdue,
                    resources.getQuantityString(R.plurals.morning_tasks, day.tasks, day.tasks),
                    resources.getQuantityString(R.plurals.morning_overdue, day.overdue, day.overdue),
                )
            }
            section(rows, tasks, TASKS) {
                if (details) {
                    day.taskList.forEach { rows.addView(line(it)) }
                    more(rows, day.tasks + day.overdue - day.taskList.size)
                }
            }
            if (day.quests > 0) {
                section(rows, resources.getQuantityString(R.plurals.morning_quests, day.quests, day.quests), QUESTS) {
                    if (details) {
                        day.questList.forEach { rows.addView(line(it)) }
                        more(rows, day.quests - day.questList.size)
                    }
                }
            }
        }
        findViewById<TextView>(R.id.morning_note).setText(
            if (details) R.string.morning_note_details else R.string.morning_note_counts,
        )
    }

    private fun time(minutes: Int): String {
        val c = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, minutes / 60)
            set(Calendar.MINUTE, minutes % 60)
        }
        return DateFormat.getTimeFormat(this).format(c.time)
    }

    private fun section(rows: LinearLayout, title: String, app: String, then: () -> Unit) {
        val head = line(title, big = true)
        val launch = packageManager.getLaunchIntentForPackage(app)
        if (launch != null) {
            head.setOnClickListener { open(launch) }
            head.isClickable = true
            head.contentDescription = title
        }
        head.setPadding(0, dp(16), 0, dp(4))
        rows.addView(head)
        then()
    }

    private fun more(rows: LinearLayout, n: Int) {
        if (n > 0) rows.addView(line(getString(R.string.morning_more, n)))
    }

    private fun line(text: String, big: Boolean = false): TextView = TextView(this).apply {
        this.text = text
        setTextColor(getColor(if (big) R.color.ring_text else R.color.ring_text_soft))
        setTextSize(TypedValue.COMPLEX_UNIT_SP, if (big) 20f else 16f)
        setPadding(0, dp(2), 0, dp(2))
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    /** Opens another ZT app; on a locked phone, once it is unlocked. */
    private fun open(intent: Intent) {
        val keyguard = getSystemService(KeyguardManager::class.java)
        if (keyguard?.isKeyguardLocked == true) {
            keyguard.requestDismissKeyguard(
                this,
                object : KeyguardManager.KeyguardDismissCallback() {
                    override fun onDismissSucceeded() = launch(intent)
                },
            )
        } else {
            launch(intent)
        }
    }

    private fun launch(intent: Intent) {
        try {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            finish()
        } catch (_: Exception) {
        }
    }

    private companion object {
        const val CALENDAR = "dev.sagron.zerotrustcalendar"
        const val TASKS = "dev.sagron.zerotrusttasks"
        const val QUESTS = "dev.sagron.zerotrustquests"
    }
}
