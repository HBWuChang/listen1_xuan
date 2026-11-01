package com.xiebian.listen1_xuan

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.AtomicFile
import java.io.File
import java.security.SecureRandom
import java.util.UUID
import org.json.JSONObject
import io.flutter.plugin.common.MethodChannel

/** Foreground FCM display only; background notifications are displayed by FCM. */
class FeedbackPushNotifications(private val activity: Activity) {
    private val manager = activity.getSystemService(NotificationManager::class.java)
    private var pendingTap: Map<String, String>? = null

    fun handle(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "deviceIdentity" -> result.success(deviceIdentity())
            "isConfigured" -> result.success(activity.resources.getIdentifier("google_app_id", "string", activity.packageName) != 0)
            "ensureChannel" -> { ensureChannel(); result.success(null) }
            "getInitialTap" -> {
                val tap = pendingTap ?: takeTap(activity.intent)
                pendingTap = null
                result.success(tap)
            }
            "cancel" -> {
                val issue = call.argument<String>("issue_id")
                manager.activeNotifications.filter { it.tag?.startsWith("feedback:") == true &&
                    (issue == null || it.tag == "feedback:$issue") }.forEach { manager.cancel(it.tag, it.id) }
                result.success(null)
            }
            "show" -> {
                show(call.arguments as? Map<*, *> ?: emptyMap<Any, Any>())
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun deviceIdentity(): Map<String, String> {
        // A restored Android backup must not clone another device's binding.
        val file = AtomicFile(File(activity.noBackupFilesDir, "feedback_push_identity.json"))
        val identity = try {
            JSONObject(file.openRead().bufferedReader().use { it.readText() })
        } catch (_: Exception) {
            val bytes = ByteArray(32).also { SecureRandom().nextBytes(it) }
            val generated = JSONObject().put("installation_id", UUID.randomUUID().toString())
                .put("secret", bytes.joinToString("") { "%02x".format(it.toInt() and 255) })
            val output = file.startWrite()
            try {
                output.write(generated.toString().toByteArray(Charsets.UTF_8))
                file.finishWrite(output)
            } catch (error: Exception) {
                file.failWrite(output)
                throw error
            }
            generated
        }
        return mapOf("installation_id" to identity.getString("installation_id"), "secret" to identity.getString("secret"))
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel("feedback_messages", "在线反馈", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "关注的问题中的新消息"
            })
        }
    }

    private fun show(data: Map<*, *>) {
        if (Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val issue = data["issue_id"] as? String ?: return
        val intent = Intent(activity, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            action = "com.xiebian.listen1_xuan.FEEDBACK_$issue"
            putExtra("feedback_local_push", true)
            for (key in arrayOf("kind", "issue_id", "user_id", "message_id")) putExtra(key, data[key] as? String)
        }
        val pending = PendingIntent.getActivity(activity, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        ensureChannel()
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(activity, "feedback_messages") else Notification.Builder(activity)
        val notification = builder.setSmallIcon(R.drawable.ic_feedback_notification)
            .setContentTitle(data["title"] as? String ?: "在线反馈有新消息")
            .setContentText("你关注的问题有新消息，点击查看")
            .setContentIntent(pending).setAutoCancel(true).setOnlyAlertOnce(true).build()
        manager.notify("feedback:$issue", 0, notification)
    }

    fun takeTap(intent: Intent?): Map<String, String>? {
        if (intent?.getBooleanExtra("feedback_local_push", false) != true) return null
        intent.removeExtra("feedback_local_push")
        return arrayOf("kind", "issue_id", "user_id", "message_id").associateWith { intent.getStringExtra(it) ?: "" }.also { pendingTap = it }
    }
}
