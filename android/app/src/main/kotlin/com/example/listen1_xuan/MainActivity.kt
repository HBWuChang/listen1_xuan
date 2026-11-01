package com.xiebian.listen1_xuan

import android.os.Bundle
import android.content.Intent
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    private var feedbackChannel: MethodChannel? = null
    private val feedbackNotifications by lazy { FeedbackPushNotifications(this) }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        feedbackChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "listen1_xuan/feedback_push").also {
            it.setMethodCallHandler(feedbackNotifications::handle)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "listen1_xuan/build_info")
            .setMethodCallHandler { call, result ->
                if (call.method == "getBuildNumber") {
                    result.success(getString(R.string.app_build_number))
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        feedbackNotifications.takeTap(intent)?.let { feedbackChannel?.invokeMethod("notificationTapped", it) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置沉浸式状态栏和导航栏
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        window.addFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS)       // 设置沉浸式状态栏，在MIUI系统中，状态栏背景透明。原生系统中，状态栏背景半透明。
        window.addFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION)   // 设置沉浸式虚拟键，在MIUI系统中，虚拟键背景透明。原生系统中，虚拟键背景半透明。
    }
}
