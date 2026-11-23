package dev.sagron.zerotrustclock

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.UserManager
import android.provider.Settings
import dev.sagron.zerotrustclock.engine.AlarmEngine
import dev.sagron.zerotrustclock.engine.BedtimeEngine
import dev.sagron.zerotrustclock.engine.SleepLog
import dev.sagron.zerotrustclock.engine.Holidays
import dev.sagron.zerotrustclock.engine.Screensaver
import dev.sagron.zerotrustclock.engine.SleepSoundService
import dev.sagron.zerotrustclock.engine.core.Bedtime
import dev.sagron.zerotrustclock.engine.core.CalendarLink
import dev.sagron.zerotrustclock.engine.AlarmNotifications
import dev.sagron.zerotrustclock.engine.AlarmScheduler
import dev.sagron.zerotrustclock.engine.EnginePrefs
import dev.sagron.zerotrustclock.engine.Loc
import dev.sagron.zerotrustclock.engine.MorningBrief
import dev.sagron.zerotrustclock.engine.RingService
import dev.sagron.zerotrustclock.engine.ScanActivity
import dev.sagron.zerotrustclock.engine.SoundPreview
import dev.sagron.zerotrustclock.engine.Sounds
import dev.sagron.zerotrustclock.engine.Tabs
import dev.sagron.zerotrustclock.engine.TimerEngine
import dev.sagron.zerotrustclock.engine.TimerNotifications
import dev.sagron.zerotrustclock.engine.TimerRingService
import dev.sagron.zerotrustclock.engine.Widgets
import dev.sagron.zerotrustclock.engine.WorldZones
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * How the app's screens (Flutter) talk to the alarm engine (Kotlin). The
 * engine works without this: it rings with the app closed.
 */
class EngineBridge(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "dev.sagron.zerotrustclock/engine")
    private var pendingPermission: MethodChannel.Result? = null
    private val changed: () -> Unit = { channel.invokeMethod("changed", null) }

    init {
        channel.setMethodCallHandler(this)
        AlarmScheduler.onChanged = changed
        TimerEngine.onChanged = changed
        try {
            AlarmNotifications.ensureChannels(Loc.wrap(activity))
            TimerNotifications.ensureChannels(Loc.wrap(activity))
            // Opening the app is one more chance to set every alarm again.
            AlarmScheduler.rescheduleAll(activity)
            TimerEngine.refresh(activity)
            BedtimeEngine.refresh(activity)
            // Nights that could not be written to Health Connect yet.
            SleepLog.flush(activity)
        } catch (_: Exception) {
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        if (AlarmScheduler.onChanged === changed) AlarmScheduler.onChanged = null
        if (TimerEngine.onChanged === changed) TimerEngine.onChanged = null
    }

    /** The tab a notification or shortcut asked for, taken once. */
    private fun takeTab(intent: Intent?): String? {
        val tab = intent?.getStringExtra(Tabs.EXTRA) ?: return null
        intent.removeExtra(Tabs.EXTRA)
        return tab
    }

    fun onNewIntent(intent: Intent) {
        val tab = takeTab(intent) ?: return
        channel.invokeMethod("openTab", tab)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "list" -> result.success(AlarmEngine.listJson(activity))
                "save" -> {
                    val days = (call.argument<List<Int>>("days") ?: emptyList()).filter { it in 1..7 }.toSet()
                    val id = AlarmEngine.save(
                        activity,
                        call.argument<String>("id"),
                        (call.argument<Int>("hour") ?: 0).coerceIn(0, 23),
                        (call.argument<Int>("minute") ?: 0).coerceIn(0, 59),
                        days,
                        AlarmEngine.Options(
                            label = call.argument<String>("label") ?: "",
                            vibrate = call.argument<Boolean>("vibrate") ?: true,
                            snoozeMinutes = (call.argument<Int>("snoozeMinutes") ?: 10).coerceIn(1, 60),
                            sound = call.argument<String>("sound"),
                            soundName = call.argument<String>("soundName"),
                            gradual = call.argument<Boolean>("gradual") ?: false,
                            ringMinutes = (call.argument<Int>("ringMinutes") ?: 10).coerceIn(1, 60),
                            task = call.argument<String>("task"),
                            taskCode = call.argument<String>("taskCode"),
                            skipHolidays = call.argument<Boolean>("skipHolidays") ?: false,
                            date = call.argument<String>("date"),
                            cycle = call.argument<String>("cycle"),
                            cycleStart = call.argument<String>("cycleStart"),
                            calendar = calendarLink(call),
                            smartWake = call.argument<Int>("smartWake") ?: 0,
                        ),
                    )
                    result.success(id)
                }
                "importSynced" -> {
                    val days = (call.argument<List<Int>>("days") ?: emptyList()).filter { it in 1..7 }.toSet()
                    result.success(
                        AlarmEngine.importSynced(
                            activity,
                            id(call),
                            (call.argument<Int>("hour") ?: 0).coerceIn(0, 23),
                            (call.argument<Int>("minute") ?: 0).coerceIn(0, 59),
                            days,
                            call.argument<String>("date"),
                            call.argument<String>("skipDate"),
                            call.argument<String>("label") ?: "",
                            call.argument<Boolean>("vibrate") ?: true,
                            (call.argument<Int>("snoozeMinutes") ?: 10).coerceIn(1, 60),
                            call.argument<Boolean>("enabled") ?: false,
                            (call.argument<Number>("updatedAt") ?: 0).toLong(),
                            call.argument<String>("pauseUntil"),
                            call.argument<Boolean>("gradual") ?: false,
                            (call.argument<Int>("ringMinutes") ?: 10).coerceIn(1, 60),
                            call.argument<String>("task"),
                            call.argument<Boolean>("skipHolidays") ?: false,
                            call.argument<String>("taskCode"),
                            call.argument<String>("cycle"),
                            call.argument<String>("cycleStart"),
                            calendarLink(call),
                            call.argument<Int>("smartWake") ?: 0,
                        ),
                    )
                }
                "setCalendarPlans" -> done(result) {
                    AlarmEngine.setCalendarPlans(activity, call.argument<String>("json") ?: "{}")
                }
                "setMorningBrief" -> done(result) {
                    MorningBrief.save(activity, call.argument<String>("json"))
                }
                "setEnabled" -> done(result) {
                    AlarmEngine.setEnabled(activity, id(call), call.argument<Boolean>("enabled") ?: false)
                }
                "skipOnce" -> done(result) { AlarmEngine.skipOnce(activity, id(call)) }
                "undoSkip" -> done(result) { AlarmEngine.undoSkip(activity, id(call)) }
                "pause" -> done(result) {
                    AlarmEngine.pause(activity, id(call), call.argument<String>("until") ?: "")
                }
                "resume" -> done(result) { AlarmEngine.resume(activity, id(call)) }
                "pauseAllUntil" -> result.success(AlarmEngine.pauseAllUntil(activity))
                "setPauseAll" -> done(result) { AlarmEngine.setPauseAll(activity, call.argument<String>("until")) }
                "pickSound" -> pickSound(call.argument<String>("kind") ?: "file", call.argument<String>("current"), result)
                "previewSound" -> done(result) { SoundPreview.play(activity, call.argument<String>("sound")) }
                "stopPreview" -> done(result) { SoundPreview.stop() }
                "scanCode" -> scanCode(result)
                "ringSettings" -> result.success(
                    mapOf(
                        "volumeButtons" to EnginePrefs.volumeButtons(activity),
                        "minVolume" to EnginePrefs.minVolume(activity),
                        "morning" to EnginePrefs.morning(activity),
                    ),
                )
                "setRingSettings" -> done(result) {
                    EnginePrefs.setVolumeButtons(activity, call.argument<String>("volumeButtons"))
                    EnginePrefs.setMinVolume(activity, call.argument<Int>("minVolume") ?: 0)
                    call.argument<String>("morning")?.let { EnginePrefs.setMorning(activity, it) }
                }
                "cancelSnooze" -> done(result) { AlarmEngine.cancelSnooze(activity, id(call)) }
                "delete" -> done(result) { AlarmEngine.delete(activity, id(call)) }
                "testAlarm" -> done(result) {
                    AlarmEngine.addTest(activity, (call.argument<Int>("seconds") ?: 10).coerceIn(5, 3600))
                }
                "ringSnooze" -> done(result) { RingService.send(activity, RingService.ACTION_SNOOZE) }
                "ringDismiss" -> done(result) { RingService.send(activity, RingService.ACTION_DISMISS) }
                "setLanguage" -> done(result) {
                    EnginePrefs.setLanguage(activity, call.argument<String>("code"))
                    AlarmNotifications.ensureChannels(Loc.wrap(activity))
                    TimerNotifications.ensureChannels(Loc.wrap(activity))
                    Widgets.refresh(activity)
                }
                "launchTab" -> result.success(takeTab(activity.intent))
                "timers" -> result.success(TimerEngine.listJson(activity))
                "timerAdd" -> result.success(
                    TimerEngine.add(
                        activity,
                        (call.argument<Number>("lengthMs") ?: 0).toLong(),
                        call.argument<String>("label") ?: "",
                        call.argument<Boolean>("start") ?: true,
                    ),
                )
                "timerStart" -> done(result) { TimerEngine.start(activity, id(call)) }
                "timerPause" -> done(result) { TimerEngine.pause(activity, id(call)) }
                "timerAddMinute" -> done(result) { TimerEngine.addMinute(activity, id(call)) }
                "timerReset" -> done(result) { TimerEngine.reset(activity, id(call)) }
                "timerLabel" -> done(result) {
                    TimerEngine.setLabel(activity, id(call), call.argument<String>("label") ?: "")
                }
                "timerDelete" -> done(result) { TimerEngine.delete(activity, id(call)) }
                "timerStopRinging" -> done(result) {
                    TimerRingService.send(activity, TimerRingService.ACTION_STOP)
                }
                "stopwatch" -> result.success(TimerEngine.stopwatchJson(activity))
                "stopwatchStart" -> done(result) { TimerEngine.stopwatch(activity) { s, now -> s.start(now) } }
                "stopwatchPause" -> done(result) { TimerEngine.stopwatch(activity) { s, now -> s.pause(now) } }
                "stopwatchLap" -> done(result) { TimerEngine.stopwatch(activity) { s, now -> s.lap(now) } }
                "stopwatchReset" -> done(result) { TimerEngine.stopwatch(activity) { s, _ -> s.reset() } }
                "now" -> result.success(TimerEngine.now())
                "holidays" -> result.success(Holidays.days(activity).map { it.toString() }.sorted())
                "setHolidays" -> done(result) {
                    Holidays.set(activity, (call.argument<List<String>>("days") ?: emptyList()))
                }
                "screensaverNight" -> result.success(Screensaver.night(activity))
                "setScreensaverNight" -> done(result) {
                    Screensaver.setNight(activity, call.argument<Boolean>("on") ?: true)
                }
                "bedtime" -> result.success(BedtimeEngine.load(activity).toJson())
                "setBedtime" -> done(result) {
                    BedtimeEngine.save(activity, Bedtime.fromJson(call.argument<String>("json")))
                }
                "dndAccess" -> result.success(BedtimeEngine.hasDndAccess(activity))
                "sleepAccess" -> result.success(
                    mapOf("available" to SleepLog.available(activity), "allowed" to SleepLog.allowed(activity)),
                )
                "requestSleepAccess" -> requestSleepAccess(result)
                "sleepSound" -> result.success(
                    SleepSoundService.state?.let { mapOf("kind" to it.kind, "endsAt" to it.endsAt) },
                )
                "playSleepSound" -> done(result) {
                    SleepSoundService.play(
                        activity,
                        call.argument<String>("kind") ?: SleepSoundService.WHITE,
                        call.argument<Int>("minutes") ?: 30,
                    )
                }
                "stopSleepSound" -> done(result) { SleepSoundService.stop(activity) }
                "zones" -> result.success(WorldZones.allJson(activity))
                // The phone's own time zone, e.g. "Asia/Jerusalem".
                "localZone" -> result.success(java.util.TimeZone.getDefault().id)
                "zoneOffsets" -> result.success(
                    WorldZones.offsets(call.argument<List<String>>("ids") ?: emptyList()),
                )
                "setWorldCities" -> done(result) {
                    WorldZones.setSaved(activity, call.argument<List<String>>("ids") ?: emptyList())
                }
                "check" -> result.success(check())
                "requestNotifications" -> requestNotifications(result)
                "openSettings" -> done(result) { openSettings(call.argument<String>("which") ?: "") }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("engine", e.message, null)
        }
    }

    /** The alarm's link to ZT Calendar, as the app sends it (a map), or null. */
    private fun calendarLink(call: MethodCall): CalendarLink? {
        val m = call.argument<Map<String, Any?>>("calendar") ?: return null
        return CalendarLink.fromJson(org.json.JSONObject(m))
    }

    private fun id(call: MethodCall): String =
        call.argument<String>("id") ?: throw IllegalArgumentException("id missing")

    private inline fun done(result: MethodChannel.Result, work: () -> Unit) {
        work()
        result.success(null)
    }

    /** Everything the Alarm check screen shows, as plain values. */
    private fun check(): Map<String, Any> {
        val notifications = activity.getSystemService(NotificationManager::class.java)
        val alarms = activity.getSystemService(AlarmManager::class.java)
        val audio = activity.getSystemService(AudioManager::class.java)
        val power = activity.getSystemService(PowerManager::class.java)
        val users = activity.getSystemService(UserManager::class.java)
        val ringChannel = notifications?.getNotificationChannel(AlarmNotifications.CHANNEL_RINGING)
        return mapOf(
            "notifications" to (notifications?.areNotificationsEnabled() ?: false),
            // The ring screen needs the channel at its original (high) level.
            "ringChannel" to (ringChannel == null ||
                ringChannel.importance >= NotificationManager.IMPORTANCE_HIGH),
            "fullScreen" to (Build.VERSION.SDK_INT < 34 ||
                (notifications?.canUseFullScreenIntent() ?: false)),
            "exactAlarms" to (Build.VERSION.SDK_INT < 31 ||
                (alarms?.canScheduleExactAlarms() ?: false)),
            "alarmVolume" to (audio?.getStreamVolume(AudioManager.STREAM_ALARM) ?: 0),
            "alarmVolumeMax" to (audio?.getStreamMaxVolume(AudioManager.STREAM_ALARM) ?: 0),
            // "Total silence" is the one Do Not Disturb mode that mutes alarms.
            "totalSilence" to (notifications?.currentInterruptionFilter ==
                NotificationManager.INTERRUPTION_FILTER_NONE),
            "ownerProfile" to (users?.isSystemUser ?: true),
            "batteryUnrestricted" to (power?.isIgnoringBatteryOptimizations(activity.packageName) ?: false),
            "bootAt" to EnginePrefs.bootAt(activity),
            "bootLocked" to EnginePrefs.bootLocked(activity),
            "ringing" to (RingService.ringingId != null),
            "sdk" to Build.VERSION.SDK_INT,
            // Some makers stop closed apps; the screen says what to switch.
            "maker" to "${Build.MANUFACTURER} ${Build.BRAND}".lowercase(),
        )
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        val granted = Build.VERSION.SDK_INT < 33 ||
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    private var pendingSleep: MethodChannel.Result? = null

    /** Asks to write sleep to Health Connect (Android 14 and later). */
    private fun requestSleepAccess(result: MethodChannel.Result) {
        if (!SleepLog.available(activity)) {
            result.success(false)
            return
        }
        if (SleepLog.allowed(activity)) {
            result.success(true)
            return
        }
        pendingSleep?.success(false)
        pendingSleep = result
        try {
            activity.requestPermissions(arrayOf(SleepLog.PERMISSION), REQUEST_SLEEP)
        } catch (_: Exception) {
            pendingSleep = null
            result.success(false)
        }
    }

    fun onPermissionsResult(requestCode: Int, grantResults: IntArray) {
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        when (requestCode) {
            REQUEST_NOTIFICATIONS -> {
                pendingPermission?.success(granted)
                pendingPermission = null
            }
            REQUEST_SLEEP -> {
                pendingSleep?.success(granted)
                pendingSleep = null
                if (granted) SleepLog.flush(activity)
            }
        }
    }

    private var pendingSound: MethodChannel.Result? = null

    /**
     * Lets the user pick a sound: a phone ringtone ([kind] "ringtone") or
     * any audio file ("file"). It is copied into the app so it plays before
     * the first unlock too. Answers {sound, name}, or null when cancelled.
     */
    private fun pickSound(kind: String, current: String?, result: MethodChannel.Result) {
        pendingSound?.success(null)
        pendingSound = result
        val intent = if (kind == "ringtone") {
            Intent(RingtoneManager.ACTION_RINGTONE_PICKER)
                .putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
                .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, false)
        } else {
            Intent(Intent.ACTION_OPEN_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType("audio/*")
        }
        try {
            activity.startActivityForResult(intent, if (kind == "ringtone") REQUEST_RINGTONE else REQUEST_FILE)
        } catch (_: Exception) {
            pendingSound = null
            result.success(null)
        }
    }

    private var pendingScan: MethodChannel.Result? = null

    /**
     * Opens the camera to save a code for the "scan a code" wake-up task.
     * Answers the code's hash, or null when nothing was scanned.
     */
    private fun scanCode(result: MethodChannel.Result) {
        pendingScan?.success(null)
        pendingScan = result
        try {
            activity.startActivityForResult(ScanActivity.saveIntent(activity), REQUEST_SCAN)
        } catch (_: Exception) {
            pendingScan = null
            result.success(null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_SCAN) {
            val code = if (resultCode == Activity.RESULT_OK) data?.getStringExtra(ScanActivity.EXTRA_CODE) else null
            pendingScan?.success(code)
            pendingScan = null
            return true
        }
        if (requestCode != REQUEST_RINGTONE && requestCode != REQUEST_FILE) return false
        val result = pendingSound ?: return true
        pendingSound = null
        val uri: Uri? = if (resultCode != Activity.RESULT_OK) {
            null
        } else if (requestCode == REQUEST_RINGTONE) {
            @Suppress("DEPRECATION")
            data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        } else {
            data?.data
        }
        if (uri == null) {
            result.success(null)
            return true
        }
        val context = activity.applicationContext
        val main = Handler(Looper.getMainLooper())
        // Copying can take a moment: not on the main thread.
        Thread {
            val name = (if (requestCode == REQUEST_RINGTONE) Sounds.ringtoneTitle(context, uri) else null)
                ?: Sounds.displayName(context, uri)?.substringBeforeLast('.')
                ?: ""
            val sound = Sounds.copyIn(context, uri) ?: Sounds.byUri(uri)
            main.post { result.success(mapOf("sound" to sound, "name" to name)) }
        }.start()
        return true
    }

    /** Opens the system screen where one check can be fixed. */
    private fun openSettings(which: String) {
        val pkg = activity.packageName
        val app = Uri.parse("package:$pkg")
        val intent = when (which) {
            "notifications" -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, pkg)
            "ringChannel" -> Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, pkg)
                .putExtra(Settings.EXTRA_CHANNEL_ID, AlarmNotifications.CHANNEL_RINGING)
            "fullScreen" -> if (Build.VERSION.SDK_INT >= 34) {
                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, app)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, app)
            }
            "exactAlarms" -> if (Build.VERSION.SDK_INT >= 31) {
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, app)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, app)
            }
            "sound" -> Intent(Settings.ACTION_SOUND_SETTINGS)
            "doNotDisturb" -> Intent(Settings.ACTION_ZEN_MODE_PRIORITY_SETTINGS)
            "screensaver" -> Intent(Settings.ACTION_DREAM_SETTINGS)
            "dndAccess" -> Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            // The app's own page in Health Connect (Android 14 and later).
            "healthConnect" -> Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS")
                .putExtra(Intent.EXTRA_PACKAGE_NAME, pkg)
            else -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, app)
        }
        try {
            activity.startActivity(intent)
        } catch (_: Exception) {
            activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, app))
        }
    }

    private companion object {
        const val REQUEST_NOTIFICATIONS = 7301
        const val REQUEST_RINGTONE = 7302
        const val REQUEST_FILE = 7303
        const val REQUEST_SCAN = 7304
        const val REQUEST_SLEEP = 7305
    }
}
