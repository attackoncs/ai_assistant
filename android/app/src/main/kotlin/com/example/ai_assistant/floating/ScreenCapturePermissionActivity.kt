package com.example.ai_assistant.floating

import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionConfig
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle

/**
 * 截屏授权 Activity（透明主题，镜像原应用 ScreenCapturePermissionActivity 的流程）：
 * createScreenCaptureIntent → 用户授权/拒绝 → 带 capture_result_code + capture_data
 * 以 ACTION_CAPTURE 重启 FloatingWindowService → finish
 */
class ScreenCapturePermissionActivity : Activity() {

    private companion object {
        const val REQUEST_CODE = 2001
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val intent = if (Build.VERSION.SDK_INT >= 34)
            manager.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay())
        else manager.createScreenCaptureIntent()
        startActivityForResult(intent, REQUEST_CODE)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        android.util.Log.d("CompAI", "onActivityResult req=$requestCode resultCode=$resultCode dataNull=${data == null}")
        if (requestCode != REQUEST_CODE) {
            finish()
            return
        }
        val service = Intent(this, FloatingWindowService::class.java)
            .setAction(FloatingWindowService.ACTION_CAPTURE)
            // 注意：RESULT_OK == -1，不能用 resultCode 数值判断成败，
            // 单独传 granted 标志（resultCode 原样传给 getMediaProjection）
            .putExtra(FloatingWindowService.KEY_GRANTED, resultCode == RESULT_OK)
        if (resultCode == RESULT_OK && data != null) {
            service.putExtra(FloatingWindowService.KEY_CAPTURE_CODE, resultCode)
            service.putExtra(FloatingWindowService.KEY_CAPTURE_DATA, data)
        }
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(service)
        else startService(service)
        finish()
    }
}
