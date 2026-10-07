package com.example.kazumi

import android.app.PendingIntent
import android.app.AlertDialog
import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.app.RemoteAction
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Bundle
import android.os.StatFs
import android.net.Uri
import android.app.PictureInPictureParams
import android.graphics.drawable.Icon
import android.util.Rational
import android.view.View
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.text.InputType
import android.util.Base64
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioService
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.predidit.kazumi/intent"
    private val STORAGE_CHANNEL = "com.predidit.kazumi/storage"
    private val PIP_CHANNEL = "com.predidit.kazumi/pip"
    private var intentChannel: MethodChannel? = null
    private var pipChannel: MethodChannel? = null

    private var pipIsPlaying = false
    private var pipDanmakuEnabled = false
    private var pipActionReceiverRegistered = false
    private var autoEnterPipOnHomeGesture = false
    private var pipInPlayerPage = false
    private var pipAspectWidth = 16
    private var pipAspectHeight = 9
    private var pipSourceRect: Rect? = null
    private var inPipMode = false
    private var systemBarsHidden = false
    private var originalWindowBackground: Drawable? = null
    private var windowBackgroundOverridden = false

    private val actionPipPlayPause = "com.predidit.kazumi.pip.PLAY_PAUSE"
    private val actionPipForward = "com.predidit.kazumi.pip.FORWARD"
    private val actionPipToggleDanmaku = "com.predidit.kazumi.pip.TOGGLE_DANMAKU"

    // Ratios outside [1:2.39, 2.39:1] make enterPictureInPictureMode throw.
    private val maxPipAspectRatio = 2.39f

    private val pipActionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: android.content.Context?, intent: Intent?) {
            val action = intent?.action ?: return
            when (action) {
                actionPipPlayPause -> notifyFlutterPipAction("play_pause")
                actionPipForward -> notifyFlutterPipAction("forward")
                actionPipToggleDanmaku -> notifyFlutterPipAction("toggle_danmaku")
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerPipActionReceiverIfNeeded()
    }

    override fun onDestroy() {
        unregisterPipActionReceiverIfNeeded()
        // audio_service stays bound for the whole activity lifetime, so its
        // own stopSelf() never destroys a service started for playback.
        stopService(Intent(this, AudioService::class.java))
        super.onDestroy()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            applySystemBarsState()
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        syncPictureInPictureMode()
    }

    @Suppress("DEPRECATION")
    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode)
        syncPictureInPictureMode()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TvUpdateBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        intentChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        intentChannel?.setMethodCallHandler { call, result ->
            if (call.method == "openWithMime") {
                val url = call.argument<String>("url")
                val mimeType = call.argument<String>("mimeType")
                if (url != null && mimeType != null) {
                    openWithMime(url, mimeType)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "URL and MIME type required", null)
                }
            } else if (call.method == "getAndroidSdkVersion") {
                val sdkVersion = getAndroidSdkVersion()
                result.success(sdkVersion)
            } else if (call.method == "isTelevision") {
                val uiMode = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                result.success(uiMode.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
                    packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK))
            } else if (call.method == "showTvSearchInput") {
                showTvSearchInput(call.arguments as? String ?: "", result)
            } else if (call.method == "showTvTextInput") {
                showTvSearchInput(call.argument<String>("text") ?: "", result,
                    call.argument<String>("title") ?: "输入文本",
                    call.argument<Boolean>("obscure") ?: false,
                    call.argument<Boolean>("numeric") ?: false, false)
            } else if (call.method == "getTvDanmakuCredentials") {
                val prefs = getSharedPreferences("kazumi_tv_private", Context.MODE_PRIVATE)
                val encrypted = prefs.getString("danmaku_secret", null)
                val iv = prefs.getString("danmaku_iv", null)
                try {
                    if (encrypted == null || iv == null) result.success(null) else {
                        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                        cipher.init(Cipher.DECRYPT_MODE, danmakuKey(), GCMParameterSpec(128, Base64.decode(iv, Base64.NO_WRAP)))
                        val secret = String(cipher.doFinal(Base64.decode(encrypted, Base64.NO_WRAP)), Charsets.UTF_8)
                        result.success(mapOf("id" to prefs.getString("danmaku_id", ""), "value" to secret))
                    }
                } catch (_: Exception) {
                    // Device restores do not restore the Android Keystore key.
                    result.success(null)
                }
            } else if (call.method == "setTvDanmakuCredentials") {
                val id = call.argument<String>("id") ?: ""
                val secret = call.argument<String>("value") ?: ""
                val prefs = getSharedPreferences("kazumi_tv_private", Context.MODE_PRIVATE).edit()
                try {
                    if (id.isEmpty() || secret.isEmpty()) {
                        prefs.remove("danmaku_id").remove("danmaku_secret").remove("danmaku_iv")
                    } else {
                        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                        cipher.init(Cipher.ENCRYPT_MODE, danmakuKey())
                        val encrypted = cipher.doFinal(secret.toByteArray(Charsets.UTF_8))
                        prefs.putString("danmaku_id", id)
                            .putString("danmaku_secret", Base64.encodeToString(encrypted, Base64.NO_WRAP))
                            .putString("danmaku_iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
                    }
                    if (prefs.commit()) result.success(null) else result.error("SAVE_FAILED", "无法保存弹幕凭证", null)
                } catch (_: Exception) {
                    result.error("SAVE_FAILED", "无法保存弹幕凭证", null)
                }
            } else if (call.method == "setSystemBarsHidden") {
                systemBarsHidden = call.arguments as? Boolean ?: false
                applySystemBarsState()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getAvailableStorage") {
                val path = call.argument<String>("path") ?: filesDir.absolutePath
                val availableBytes = getAvailableStorage(path)
                result.success(availableBytes)
            } else {
                result.notImplemented()
            }
        }

        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
        pipChannel?.setMethodCallHandler { call, result ->
            if (call.method == "isPictureInPictureSupported") {
                result.success(isPictureInPictureSupported())
            } else if (call.method == "enterPictureInPictureMode") {
                pipAspectWidth = call.argument<Int>("width") ?: pipAspectWidth
                pipAspectHeight = call.argument<Int>("height") ?: pipAspectHeight
                val entered = enterPictureInPicture()
                result.success(entered)
            } else if (call.method == "updatePictureInPictureActions") {
                val playing = call.argument<Boolean>("playing") ?: false
                val danmakuEnabled = call.argument<Boolean>("danmakuEnabled") ?: false
                pipAspectWidth = call.argument<Int>("width") ?: pipAspectWidth
                pipAspectHeight = call.argument<Int>("height") ?: pipAspectHeight
                updatePipSourceRect(call)
                updatePictureInPictureActions(playing, danmakuEnabled)
                result.success(true)
            } else if (call.method == "setAndroidAutoEnterPIPEnabled") {
                autoEnterPipOnHomeGesture = call.argument<Boolean>("enabled") ?: false
                refreshPictureInPictureParamsIfNeeded()
                result.success(true)
            } else if (call.method == "setAndroidPIPInPlayerPage") {
                pipInPlayerPage = call.argument<Boolean>("inPlayerPage") ?: false
                if (!pipInPlayerPage) {
                    pipSourceRect = null
                }
                refreshWindowBackground()
                refreshPictureInPictureParamsIfNeeded()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun danmakuKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val alias = "kazumi_tv_danmaku"
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }

    private fun showTvSearchInput(initialText: String, result: MethodChannel.Result,
        title: String = "番剧搜索", obscure: Boolean = false,
        numeric: Boolean = false, search: Boolean = true) {
        val editor = EditText(this).apply {
            inputType = if (numeric) InputType.TYPE_CLASS_NUMBER else
                InputType.TYPE_CLASS_TEXT or (if (obscure) InputType.TYPE_TEXT_VARIATION_PASSWORD else InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS)
            setSingleLine(true)
            imeOptions = if (search) EditorInfo.IME_ACTION_SEARCH else EditorInfo.IME_ACTION_DONE
            hint = title
            setText(initialText)
            setSelection(text.length)
            setPadding(32, 24, 32, 24)
        }
        var completed = false
        fun finish(value: String?) {
            if (!completed) {
                completed = true
                result.success(value)
            }
        }
        val dialog = AlertDialog.Builder(this)
            .setTitle(title)
            .setView(editor)
            .setPositiveButton(if (search) "搜索" else "确定") { _, _ -> finish(editor.text.toString()) }
            .setNegativeButton("取消") { _, _ -> finish(null) }
            .create()
        dialog.setOnDismissListener { finish(null) }
        editor.setOnEditorActionListener { _, action, _ ->
            if (action == EditorInfo.IME_ACTION_SEARCH || action == EditorInfo.IME_ACTION_DONE) {
                finish(editor.text.toString())
                dialog.dismiss()
                true
            } else false
        }
        dialog.setOnShowListener {
            editor.requestFocus()
            editor.post {
                val input = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                input.showSoftInput(editor, 0)
            }
        }
        dialog.window?.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE or
                WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        dialog.show()
    }

    private fun openWithMime(url: String, mimeType: String) {
        val intent = Intent()
        intent.action = Intent.ACTION_VIEW
        intent.setDataAndType(Uri.parse(url), mimeType)
        startActivity(intent)
    }

    private fun getAndroidSdkVersion(): Int {
        return Build.VERSION.SDK_INT
    }

    // System bars belong to the full size window; replayed on leaving PiP.
    private fun applySystemBarsState() {
        if (inPipMode) {
            return
        }
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        if (systemBarsHidden) {
            controller.systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            controller.hide(WindowInsetsCompat.Type.systemBars())
        } else {
            controller.show(WindowInsetsCompat.Type.systemBars())
        }
    }

    // Either PiP callback may arrive first, depending on the device.
    private fun syncPictureInPictureMode() {
        val current = isInPictureInPictureMode
        if (current != inPipMode) {
            inPipMode = current
            pipChannel?.invokeMethod("onModeChanged", mapOf("isInPipMode" to current))
            refreshWindowBackground()
        }
        applySystemBarsState()
    }

    // Cover the surface with black until Flutter renders the resized frame.
    private fun refreshWindowBackground() {
        val blackBackground = inPipMode || pipInPlayerPage
        if (blackBackground == windowBackgroundOverridden) {
            return
        }
        if (blackBackground) {
            originalWindowBackground = window.decorView.background
            window.setBackgroundDrawable(ColorDrawable(Color.BLACK))
        } else {
            window.setBackgroundDrawable(originalWindowBackground)
            originalWindowBackground = null
        }
        windowBackgroundOverridden = blackBackground
    }

    private fun isPictureInPictureSupported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return false
        }
        return packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun enterPictureInPicture(): Boolean {
        if (!isPictureInPictureSupported()) {
            return false
        }
        if (isInPictureInPictureMode) {
            return true
        }
        return try {
            enterPictureInPictureMode(buildPictureInPictureParams())
        } catch (e: Exception) {
            false
        }
    }

    private fun updatePictureInPictureActions(
        playing: Boolean,
        danmakuEnabled: Boolean
    ) {
        if (!isPictureInPictureSupported()) {
            return
        }
        pipIsPlaying = playing
        pipDanmakuEnabled = danmakuEnabled
        refreshPictureInPictureParamsIfNeeded()
    }

    // In picture in picture the rect would describe the small window, so the
    // pre-PiP one is kept as the expand back target.
    private fun updatePipSourceRect(call: MethodCall) {
        if (inPipMode) {
            return
        }
        val left = call.argument<Int>("sourceLeft") ?: return
        val top = call.argument<Int>("sourceTop") ?: return
        val right = call.argument<Int>("sourceRight") ?: return
        val bottom = call.argument<Int>("sourceBottom") ?: return
        if (right <= left || bottom <= top) {
            return
        }
        pipSourceRect = Rect(left, top, right, bottom)
    }

    private fun buildPipSourceRectHint(): Rect? {
        val rect = pipSourceRect ?: return null
        val contentView = window.decorView.findViewById<View>(android.R.id.content) ?: return null
        val contentBounds = Rect()
        if (!contentView.getGlobalVisibleRect(contentBounds)) {
            return null
        }
        val hint = Rect(rect)
        hint.offset(contentBounds.left, contentBounds.top)
        if (!hint.intersect(contentBounds) || hint.isEmpty) {
            return null
        }
        return hint
    }

    private fun buildPipAspectRatio(): Rational {
        val width = if (pipAspectWidth > 0) pipAspectWidth else 16
        val height = if (pipAspectHeight > 0) pipAspectHeight else 9
        val ratio = width.toFloat() / height.toFloat()
        return when {
            ratio > maxPipAspectRatio -> Rational(239, 100)
            ratio < 1f / maxPipAspectRatio -> Rational(100, 239)
            else -> Rational(width, height)
        }
    }

    private fun buildPictureInPictureParams(): PictureInPictureParams {
        val actions = buildPipActions()
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(buildPipAspectRatio())
        buildPipSourceRectHint()?.let { builder.setSourceRectHint(it) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(autoEnterPipOnHomeGesture && pipInPlayerPage)
            // The crossfade alternative is driven by a window snapshot, which
            // holds no video surface and fades through an empty window.
            builder.setSeamlessResizeEnabled(true)
        }
        if (actions.isNotEmpty()) {
            builder.setActions(actions)
        }
        return builder.build()
    }

    private fun refreshPictureInPictureParamsIfNeeded() {
        if (!isPictureInPictureSupported()) {
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                setPictureInPictureParams(buildPictureInPictureParams())
            } catch (e: Exception) {
                // The activity can reject params while it is not resumed.
            }
        }
    }

    private fun buildPipActions(): List<RemoteAction> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return emptyList()
        }

        val allActions = mutableListOf<RemoteAction>(
            createPipAction(
                action = actionPipToggleDanmaku,
                requestCode = 1003,
                iconRes = if (pipDanmakuEnabled) R.drawable.ic_pip_danmaku_on else R.drawable.ic_pip_danmaku_off,
                title = if (pipDanmakuEnabled) "Danmaku On" else "Danmaku Off",
                description = if (pipDanmakuEnabled) "Turn off danmaku" else "Turn on danmaku",
                enabled = true
            ),
            createPipAction(
                action = actionPipPlayPause,
                requestCode = 1001,
                iconRes = if (pipIsPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                title = if (pipIsPlaying) "Pause" else "Play",
                description = if (pipIsPlaying) "Pause playback" else "Play playback",
                enabled = true
            ),
            createPipAction(
                action = actionPipForward,
                requestCode = 1002,
                iconRes = R.drawable.ic_pip_forward_80,
                title = "Forward",
                description = "Forward by custom seconds",
                enabled = true
            )
        )

        val maxActions = maxNumPictureInPictureActions
        if (allActions.size > maxActions) {
            allActions.subList(maxActions, allActions.size).clear()
        }
        return allActions
    }

    private fun createPipAction(
        action: String,
        requestCode: Int,
        iconRes: Int,
        title: String,
        description: String,
        enabled: Boolean
    ): RemoteAction {
        val intent = Intent(action).setPackage(packageName)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return RemoteAction(
            Icon.createWithResource(this, iconRes),
            title,
            description,
            pendingIntent
        ).apply {
            setEnabled(enabled)
        }
    }

    private fun notifyFlutterPipAction(action: String) {
        pipChannel?.invokeMethod("onAction", mapOf("action" to action))
    }

    private fun registerPipActionReceiverIfNeeded() {
        if (pipActionReceiverRegistered || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val filter = IntentFilter().apply {
            addAction(actionPipPlayPause)
            addAction(actionPipForward)
            addAction(actionPipToggleDanmaku)
        }
        ContextCompat.registerReceiver(
            this,
            pipActionReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
        pipActionReceiverRegistered = true
    }

    private fun unregisterPipActionReceiverIfNeeded() {
        if (!pipActionReceiverRegistered) {
            return
        }
        unregisterReceiver(pipActionReceiver)
        pipActionReceiverRegistered = false
    }

    private fun getAvailableStorage(path: String): Long {
        return try {
            val stat = StatFs(path)
            stat.availableBlocksLong * stat.blockSizeLong
        } catch (e: Exception) {
            -1L
        }
    }
}
