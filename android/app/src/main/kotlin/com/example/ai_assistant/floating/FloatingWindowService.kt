package com.example.ai_assistant.floating

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.hardware.display.DisplayManager
import android.media.Image
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import com.example.ai_assistant.MainActivity
import java.io.ByteArrayOutputStream
import kotlin.concurrent.thread

/**
 * 悬浮窗前台服务（复刻猫小泡 FloatingWindowService 的架构）：
 * - Action: START / STOP / START_CAPTURE（截屏授权后带 capture_result_code + capture_data 回来）
 * - MediaProjection + ImageReader 一次性截屏，JPEG 字节通过 MethodChannel 回传 Dart
 * - 键名对齐逆向结果：state / capture_result_code / capture_data
 */
class FloatingWindowService : Service() {

    companion object {
        const val CHANNEL_NAME = "floating_window_channel"
        const val ACTION_START = "com.example.ai_assistant.FLOATING.ACTION_START"
        const val ACTION_STOP = "com.example.ai_assistant.FLOATING.ACTION_STOP"
        const val ACTION_CAPTURE = "com.example.ai_assistant.FLOATING.ACTION_START_CAPTURE"
        const val KEY_STATE = "state"
        const val KEY_CAPTURE_CODE = "capture_result_code"
        const val KEY_CAPTURE_DATA = "capture_data"
        const val KEY_CAPTURE_ERROR = "capture_error"
        const val KEY_GRANTED = "granted"
        const val NOTIF_ID = 1001
        private const val NOTIF_CHANNEL_ID = "floating_service"
        private const val TAG = "CompAI"

        @Volatile
        var instance: FloatingWindowService? = null
            private set
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var bubble: FrameLayout? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var panel: LinearLayout? = null
    private var panelParams: WindowManager.LayoutParams? = null
    private var statusText: TextView? = null
    private var cardsContainer: LinearLayout? = null
    private var lastLines: List<String> = emptyList()
    private var currentStyle: String = "通用"
    private val styleChips = mutableListOf<Pair<TextView, String>>()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand action=${intent?.action}")
        when (intent?.action) {
            ACTION_START -> {
                startAsForeground(withProjectionType = false)
                mainHandler.post { showBubble() }
                MainActivity.channel?.invokeMethod("onServiceState", mapOf(KEY_STATE to "running"))
            }
            ACTION_CAPTURE -> {
                val granted = intent.getBooleanExtra(KEY_GRANTED, false)
                @Suppress("DEPRECATION")
                val data: Intent? = if (Build.VERSION.SDK_INT >= 33)
                    intent.getParcelableExtra(KEY_CAPTURE_DATA, Intent::class.java)
                else intent.getParcelableExtra(KEY_CAPTURE_DATA)
                Log.d(TAG, "CAPTURE granted=$granted dataNull=${data == null}")
                if (!granted || data == null) {
                    // 用户拒绝了截屏授权
                    MainActivity.channel?.invokeMethod(
                        "onCaptureResult",
                        mapOf(
                            KEY_STATE to "capture_result",
                            KEY_CAPTURE_CODE to -1,
                            KEY_CAPTURE_ERROR to if (granted) "授权数据为空" else "用户取消了截屏授权"
                        )
                    )
                    stopSelf()
                    return START_NOT_STICKY
                }
                startAsForeground(withProjectionType = true)
                Log.d(TAG, "CAPTURE 进入 captureOnce")
                captureOnce(intent.getIntExtra(KEY_CAPTURE_CODE, Int.MIN_VALUE), data)
            }
            ACTION_STOP -> {
                MainActivity.channel?.invokeMethod("onServiceState", mapOf(KEY_STATE to "stopped"))
                stopSelf()
            }
            else -> {
                startAsForeground(withProjectionType = false)
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        mainHandler.post {
            removeBubble()
            removePanel()
        }
        MainActivity.channel?.invokeMethod("onServiceState", mapOf(KEY_STATE to "stopped"))
        instance = null
        super.onDestroy()
    }

    // ─── 前台服务 ─────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(
                NOTIF_CHANNEL_ID, "悬浮窗服务",
                NotificationManager.IMPORTANCE_LOW
            )
            nm.createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification {
        val pi = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= 26)
            Notification.Builder(this, NOTIF_CHANNEL_ID)
        else @Suppress("DEPRECATION") Notification.Builder(this)
        return builder
            .setContentTitle("Companion AI 悬浮窗运行中")
            .setContentText("点击气泡截屏，AI 帮你想回复")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    private fun startAsForeground(withProjectionType: Boolean) {
        if (Build.VERSION.SDK_INT >= 29) {
            // Android 14+ 要求截屏前必须先启动 mediaProjection 类型的前台服务
            val type = if (withProjectionType)
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            else ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            startForeground(NOTIF_ID, buildNotification(), type)
        } else {
            startForeground(NOTIF_ID, buildNotification())
        }
    }

    // ─── 悬浮气泡 ─────────────────────────────────────────────────────────

    private fun hasOverlayPermission(): Boolean =
        Build.VERSION.SDK_INT >= 23 && Settings.canDrawOverlays(this)

    @SuppressLint("ClickableViewAccessibility", "InflateParams")
    private fun showBubble() {
        if (!hasOverlayPermission() || bubble != null) return
        val wm = windowManager ?: return
        val size = dp(52)
        val container = FrameLayout(this)
        val circle = TextView(this).apply {
            text = "AI"
            setTextColor(Color.WHITE)
            textSize = 18f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#7C4DFF"))
            }
        }
        container.addView(
            circle,
            FrameLayout.LayoutParams(size, size)
        )

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(12)
            y = dp(220)
        }

        // 拖动 + 点击（位移小于 touchSlop 视为点击）
        var downRawX = 0f
        var downRawY = 0f
        var startX = 0
        var startY = 0
        var moved = false
        container.setOnTouchListener { _, ev ->
            when (ev.action) {
                MotionEvent.ACTION_DOWN -> {
                    downRawX = ev.rawX; downRawY = ev.rawY
                    startX = params.x; startY = params.y; moved = false
                    false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = ev.rawX - downRawX
                    val dy = ev.rawY - downRawY
                    if (moved || dx * dx + dy * dy > 100) {
                        moved = true
                        params.x = startX + dx.toInt()
                        params.y = startY + dy.toInt()
                        runCatching { wm.updateViewLayout(container, params) }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) startCapture()
                    false
                }
                else -> false
            }
        }

        runCatching {
            wm.addView(container, params)
            bubble = container
            bubbleParams = params
        }
    }

    private fun removeBubble() {
        bubble?.let { runCatching { windowManager?.removeView(it) } }
        bubble = null
        bubbleParams = null
    }

    // ─── 回复面板 ─────────────────────────────────────────────────────────

    private fun showPanel(initialText: String) {
        if (!hasOverlayPermission()) return
        val wm = windowManager ?: return
        removePanel()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), dp(10), dp(14), dp(10))
            background = GradientDrawable().apply {
                cornerRadius = dp(16).toFloat()
                setColor(Color.parseColor("#EE1C1C1E"))
            }
        }
        val title = TextView(this).apply {
            text = "AI 回复建议"
            setTextColor(Color.parseColor("#B39DFF"))
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD
        }
        val scroll = ScrollView(this).apply { isVerticalScrollBarEnabled = true }
        val bodyCol = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        val status = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 15f
            setLineSpacing(dp(3).toFloat(), 1f)
            text = initialText
        }
        val cards = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
        }
        bodyCol.addView(status)
        bodyCol.addView(cards)
        scroll.addView(
            bodyCol,
            ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        )

        // 风格条（对照原应用：松弛/通用/幽默/深度/暧昧升温）
        val styleScroll = HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
        }
        val styleRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        styleChips.clear()
        for (s in STYLE_LIST) {
            val chip = TextView(this).apply {
                text = s
                textSize = 12f
                setPadding(dp(14), dp(5), dp(14), dp(5))
                setOnClickListener {
                    currentStyle = s
                    refreshStyleChips()
                    android.widget.Toast.makeText(
                        this@FloatingWindowService, "风格：$s", android.widget.Toast.LENGTH_SHORT
                    ).show()
                    MainActivity.channel?.invokeMethod("regenerate", mapOf("style" to s))
                }
            }
            styleRow.addView(chip, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { setMargins(0, 0, dp(8), 0) })
            styleChips.add(chip to s)
        }
        refreshStyleChips()
        styleScroll.addView(styleRow)

        val btnRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
        }
        val copyBtn = Button(this).apply {
            setText("复制全部")
            textSize = 12f
            setTextColor(Color.parseColor("#B39DFF"))
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener {
                val cm = getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                cm.setPrimaryClip(
                    android.content.ClipData.newPlainText("reply", lastLines.joinToString("\n"))
                )
                android.widget.Toast.makeText(this@FloatingWindowService, "已复制全部", android.widget.Toast.LENGTH_SHORT).show()
            }
        }
        val closeBtn = Button(this).apply {
            setText("关闭")
            textSize = 12f
            setTextColor(Color.GRAY)
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener { mainHandler.post { removePanel(); showBubble() } }
        }
        btnRow.addView(copyBtn)
        btnRow.addView(closeBtn)

        root.addView(title)
        val scrollLp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(240)
        )
        scrollLp.setMargins(0, dp(6), 0, dp(4))
        root.addView(scroll, scrollLp)
        root.addView(styleScroll, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { setMargins(0, dp(2), 0, dp(2)) })
        root.addView(btnRow)
        statusText = status
        cardsContainer = cards

        val params = WindowManager.LayoutParams(
            resources.displayMetrics.widthPixels - dp(24),
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.CENTER }

        runCatching {
            wm.addView(root, params)
            panel = root
            panelParams = params
            removeBubble()
        }
    }

    private val STYLE_LIST = listOf("松弛", "通用", "幽默", "深度", "暧昧升温", "简短")

    private fun refreshStyleChips() {
        for ((chip, label) in styleChips) {
            val selected = label == currentStyle
            chip.setTextColor(if (selected) Color.parseColor("#111111") else Color.parseColor("#9E9EA3"))
            chip.background = GradientDrawable().apply {
                cornerRadius = dp(14).toFloat()
                setColor(if (selected) Color.parseColor("#B39DFF") else Color.parseColor("#2C2C2E"))
            }
        }
    }

    /** 单条回复卡片：文本 + 独立复制按钮（对照原应用逐条复制） */
    private fun replyCard(content: String): LinearLayout {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(10), dp(8), dp(10))
            background = GradientDrawable().apply {
                cornerRadius = dp(12).toFloat()
                setColor(Color.parseColor("#2A2A2C"))
            }
        }
        val tv = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 14f
            setLineSpacing(dp(2).toFloat(), 1f)
            setTextIsSelectable(true)
            setText(content)
        }
        row.addView(tv, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        val cp = TextView(this).apply {
            setText("复制")
            textSize = 11f
            setTextColor(Color.parseColor("#B39DFF"))
            setPadding(dp(10), dp(6), dp(6), dp(6))
            setOnClickListener {
                val cm = getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                cm.setPrimaryClip(android.content.ClipData.newPlainText("reply", content))
                android.widget.Toast.makeText(this@FloatingWindowService, "已复制", android.widget.Toast.LENGTH_SHORT).show()
            }
        }
        row.addView(cp)
        return row
    }

    private fun removePanel() {
        panel?.let { runCatching { windowManager?.removeView(it) } }
        panel = null
        panelParams = null
        statusText = null
        cardsContainer = null
        styleChips.clear()
    }

    /** Dart 调用：显示状态文本（如"正在分析…"） */
    fun showStatus(text: String) = mainHandler.post {
        if (panel == null) {
            showPanel(text)
        } else {
            statusText?.apply { visibility = View.VISIBLE; this.text = text }
            cardsContainer?.visibility = View.GONE
        }
    }

    /** Dart 调用：流式更新多行回复（每行一张可复制卡片） */
    fun showReplyLines(lines: List<String>) = mainHandler.post {
        if (panel == null) showPanel("")
        val c = cardsContainer ?: return@post
        statusText?.visibility = View.GONE
        c.visibility = View.VISIBLE
        lastLines = lines
        if (c.childCount != lines.size) {
            // 行数变化（新增一条建议）：整体重建
            c.removeAllViews()
            for (line in lines) c.addView(replyCard(line))
        } else {
            // 行数不变（流式中最后一行在增长）：只更新文本，避免闪烁
            for (i in lines.indices) {
                val row = c.getChildAt(i) as? LinearLayout ?: continue
                (row.getChildAt(0) as? TextView)?.text = lines[i]
            }
        }
    }

    /** Dart 调用：隐藏面板，恢复气泡 */
    fun hidePanel() = mainHandler.post {
        removePanel()
        showBubble()
    }

    // ─── 截屏 ─────────────────────────────────────────────────────────────

    /** 点击气泡 → 拉起截屏授权 Activity（授权后系统会带结果重启本服务） */
    fun startCapture() {
        if (!hasOverlayPermission()) {
            showStatus("请先在应用内授予「悬浮窗」权限")
            return
        }
        val intent = Intent(this, ScreenCapturePermissionActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        // 隐藏气泡避免被截进图里
        mainHandler.post { removeBubble() }
    }

    private fun captureOnce(resultCode: Int, data: Intent?) {
        thread {
            var projection: android.media.projection.MediaProjection? = null
            var virtualDisplay: android.hardware.display.VirtualDisplay? = null
            var reader: android.media.ImageReader? = null
            var bytes: ByteArray? = null
            var errorMsg: String? = null
            try {
                val pm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                // data 在 onStartCommand 已确保非空；SDK 36 签名为 (Int, Intent): MediaProjection?
                val p = pm.getMediaProjection(resultCode, data!!)
                    ?: throw IllegalStateException("MediaProjection 为空")
                projection = p
                Log.d(TAG, "captureOnce: projection 获取成功")
                // Android 14+ (targetSdk 34+) 强制：createVirtualDisplay 前必须注册 Callback，
                // 否则抛 IllegalStateException（用于响应投影状态、管理资源）
                p.registerCallback(object : android.media.projection.MediaProjection.Callback() {
                    override fun onStop() {
                        Log.d(TAG, "projection onStop（系统停止了投影）")
                    }
                }, mainHandler)
                val metrics = resources.displayMetrics
                val width = metrics.widthPixels
                val height = metrics.heightPixels
                val dpi = metrics.densityDpi
                val r = android.media.ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 3)
                reader = r
                val vd = p.createVirtualDisplay(
                    "comp_ai_capture", width, height, dpi,
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, r.surface, null, null
                )
                virtualDisplay = vd

                // 等第一帧（最多 8s，部分设备首帧渲染较慢）
                var image: Image? = null
                val deadline = SystemClock.uptimeMillis() + 8000
                while (SystemClock.uptimeMillis() < deadline) {
                    image = r.acquireLatestImage()
                    if (image != null) break
                    SystemClock.sleep(150)
                }

                val img = image
                if (img == null) {
                    errorMsg = "等待屏幕画面超时，请再点一次气泡重试"
                    Log.d(TAG, "captureOnce: 等帧超时(8s)")
                } else {
                    val plane = img.planes[0]
                    val rowStride = plane.rowStride
                    val pixelStride = plane.pixelStride
                    // rowStride 可能带行尾填充，先按带填充宽度建图再裁剪
                    val rowPadding = rowStride - width * pixelStride
                    val paddedWidth = width + rowPadding / pixelStride
                    val padded = Bitmap.createBitmap(paddedWidth, height, Bitmap.Config.ARGB_8888)
                    padded.copyPixelsFromBuffer(plane.buffer)
                    img.close()
                    val bmp = if (paddedWidth > width)
                        Bitmap.createBitmap(padded, 0, 0, width, height)
                    else padded
                    val scaled = if (width > 1080) {
                        Bitmap.createScaledBitmap(bmp, 1080, height * 1080 / width, true)
                    } else bmp
                    val bos = ByteArrayOutputStream()
                    scaled.compress(Bitmap.CompressFormat.JPEG, 85, bos)
                    bytes = bos.toByteArray()
                    Log.d(TAG, "captureOnce: 截屏成功 ${bytes.size} 字节")
                }
            } catch (e: Exception) {
                bytes = null
                errorMsg = "${e.javaClass.simpleName}: ${e.message ?: "截屏异常"}"
                Log.d(TAG, "captureOnce: 异常 $errorMsg", e)
            } finally {
                runCatching { virtualDisplay?.release() }
                runCatching { reader?.close() }
                runCatching { projection?.stop() }
            }

            val result = bytes
            val err = errorMsg
            mainHandler.post {
                val args = if (result != null)
                    mapOf(
                        KEY_STATE to "capture_result",
                        KEY_CAPTURE_CODE to resultCode,
                        KEY_CAPTURE_DATA to result
                    )
                else
                    mapOf(
                        KEY_STATE to "capture_result",
                        KEY_CAPTURE_CODE to -1,
                        KEY_CAPTURE_ERROR to (err ?: "截屏失败")
                    )
                Log.d(TAG, "captureOnce: 回传 Dart result=${result != null} err=$err")
                MainActivity.channel?.invokeMethod("onCaptureResult", args)
                // 截屏完成后把前台类型从 mediaProjection 降回 dataSync，
                // 避免 Android 14+ 因「mediaProjection 类型无活动会话」被系统回收
                if (Build.VERSION.SDK_INT >= 29) {
                    runCatching {
                        startForeground(
                            NOTIF_ID, buildNotification(),
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                        )
                    }
                }
                if (result == null) stopSelf()
            }
        }
    }

    // ─── 工具 ─────────────────────────────────────────────────────────────

    private fun overlayType(): Int =
        if (Build.VERSION.SDK_INT >= 26)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE

    private fun dp(v: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
    ).toInt()
}
