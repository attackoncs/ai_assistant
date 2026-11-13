package com.example.ai_assistant

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.example.ai_assistant.floating.FloatingWindowService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        // 服务需要与 Dart 通信，静态持有通道（Dart 侧只有一个引擎实例）
        @Volatile
        var channel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FloatingWindowService.CHANNEL_NAME)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "start_service" -> {
                    startFloating(FloatingWindowService.ACTION_START)
                    result.success(true)
                }
                "stop_service" -> {
                    startFloating(FloatingWindowService.ACTION_STOP)
                    result.success(true)
                }
                "check_overlay_permission" -> result.success(hasOverlayPermission())
                "request_overlay_permission" -> {
                    // 跳到系统「显示在其他应用上层」设置页
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }
                "request_capture" -> {
                    // 由服务发起（隐藏气泡 → 授权 Activity）
                    FloatingWindowService.instance?.startCapture()
                    result.success(FloatingWindowService.instance != null)
                }
                "show_status" -> {
                    FloatingWindowService.instance?.showStatus(call.argument<String>("text") ?: "")
                    result.success(true)
                }
                "show_reply" -> {
                    val lines = call.argument<List<Any>>("lines")
                        ?.map { it.toString() } ?: emptyList()
                    FloatingWindowService.instance?.showReplyLines(lines)
                    result.success(true)
                }
                "hide_panel" -> {
                    FloatingWindowService.instance?.hidePanel()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasOverlayPermission(): Boolean =
        Build.VERSION.SDK_INT >= 23 && Settings.canDrawOverlays(this)

    private fun startFloating(action: String) {
        val intent = Intent(this, FloatingWindowService::class.java).setAction(action)
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent)
        else startService(intent)
    }

    override fun onDestroy() {
        channel = null
        super.onDestroy()
    }
}
