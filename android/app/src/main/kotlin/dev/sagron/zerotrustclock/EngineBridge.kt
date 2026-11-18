package dev.sagron.zerotrustclock

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.UserManager
import android.provider.Settings
import dev.sagron.zerotrustclock.engine.AlarmEngine
import dev.sagron.zerotrustclock.engine.AlarmNotifications
import dev.sagron.zerotrustclock.engine.AlarmScheduler
import dev.sagron.zerotrustclock.engine.EnginePrefs
import dev.sagron.zerotrustclock.engine.Loc
import dev.sagron.zerotrustclock.engine.RingService
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
        try {
            AlarmNotifications.ensureChannels(Loc.wrap(activity))
            // Opening the app is one more chance to set every alarm again.
            AlarmScheduler.rescheduleAll(activity)
        } catch (_: Exception) {
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        if (AlarmScheduler.onChanged === changed) AlarmScheduler.onChanged = null
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
                        call.argument<String>("label") ?: "",
                        call.argument<Boolean>("vibrate") ?: true,
                        (call.argument<Int>("snoozeMinutes") ?: 10).coerceIn(1, 60),
                    )
                    result.success(id)
                }
                "setEnabled" -> done(result) {
                    AlarmEngine.setEnabled(activity, id(call), call.argument<Boolean>("enabled") ?: false)
                }
                "skipOnce" -> done(result) { AlarmEngine.skipOnce(activity, id(call)) }
                "undoSkip" -> done(result) { AlarmEngine.undoSkip(activity, id(call)) }
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

    fun onPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_NOTIFICATIONS) return
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermission?.success(granted)
        pendingPermission = null
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
    }
}
