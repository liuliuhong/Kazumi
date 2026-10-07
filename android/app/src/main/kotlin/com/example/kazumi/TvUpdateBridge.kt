package com.example.kazumi

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.zip.ZipFile

/** Uses only the application's private update cache. Never accepts arbitrary APK paths. */
class TvUpdateBridge(private val activity: Activity, messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, "com.predidit.kazumi/tv_update").setMethodCallHandler { call, result ->
            if (activity.packageName != "com.predidit.kazumi.tv") {
                result.error("NOT_TV", "只有社区 TV 构建支持此更新渠道", null)
            } else when (call.method) {
                "installed" -> {
                    val info = installedInfo()
                    result.success(mapOf("name" to info.versionName, "code" to versionCode(info),
                        "sdk" to Build.VERSION.SDK_INT, "abis" to Build.SUPPORTED_ABIS.toList()))
                }
                "canInstall" -> result.success(canInstall())
                "openPermission" -> try {
                    activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:${activity.packageName}")))
                    result.success(null)
                } catch (_: Exception) {
                    result.error("PERMISSION", "无法打开安装授权设置，请在盒子系统设置中允许 Kazumi TV 安装应用", null)
                }
                "verify", "install" -> Thread {
                    try {
                        val file = verify(call)
                        activity.runOnUiThread {
                            try {
                                if (call.method == "install") {
                                    check(canInstall()) { "请先允许 Kazumi TV 安装未知来源应用" }
                                    val uri = FileProvider.getUriForFile(activity,
                                        "${activity.packageName}.tv_update_files", file)
                                    val intent = Intent(Intent.ACTION_VIEW)
                                        .setDataAndType(uri, "application/vnd.android.package-archive")
                                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    intent.clipData = ClipData.newRawUri("TV update", uri)
                                    activity.startActivity(intent)
                                }
                                result.success(null)
                            } catch (e: Exception) { result.error("INSTALL", e.message, null) }
                        }
                    } catch (e: Exception) {
                        activity.runOnUiThread { result.error("INVALID_APK", e.message ?: "APK 验证失败", null) }
                    }
                }.start()
                else -> result.notImplemented()
            }
        }
    }

    private fun canInstall() = Build.VERSION.SDK_INT < 26 || activity.packageManager.canRequestPackageInstalls()
    private fun flags() = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
    @Suppress("DEPRECATION")
    private fun installedInfo() = activity.packageManager.getPackageInfo(activity.packageName, flags())
    @Suppress("DEPRECATION")
    private fun versionCode(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
    @Suppress("DEPRECATION")
    private fun signers(info: PackageInfo): List<String> {
        val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
        check(!signatures.isNullOrEmpty()) { "无法读取 APK 签名" }
        return signatures.map { hex(MessageDigest.getInstance("SHA-256").digest(it.toByteArray())) }.sorted()
    }
    private fun hex(bytes: ByteArray) = bytes.joinToString("") { "%02x".format(it) }

    @Suppress("DEPRECATION")
    private fun verify(call: MethodCall): File {
        val root = File(activity.cacheDir, "tv-updates").canonicalFile
        val file = File(call.argument<String>("path") ?: "").canonicalFile
        check(file.parentFile == root && file.name.endsWith(".apk") && file.isFile) { "安装包不在应用的更新缓存中" }
        check(file.length() == call.argument<Number>("size")?.toLong()) { "安装包大小不一致" }
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            var count = input.read(buffer)
            while (count != -1) { digest.update(buffer, 0, count); count = input.read(buffer) }
        }
        check(hex(digest.digest()) == call.argument<String>("sha256")) { "安装包 SHA-256 校验失败" }
        val archive = activity.packageManager.getPackageArchiveInfo(file.path, flags())
            ?: throw IllegalArgumentException("无法读取 APK 信息或签名")
        val current = installedInfo()
        check(archive.packageName == activity.packageName) { "安装包不是 Kazumi TV" }
        check(versionCode(archive) == call.argument<Number>("versionCode")?.toLong() &&
            archive.versionName == call.argument<String>("versionName")) { "APK 版本与发布信息不一致" }
        check(versionCode(archive) > versionCode(current)) { "安装包不是更新版本，禁止降级或重复安装" }
        check(signers(archive) == signers(current)) { "APK 签名与当前 TV 应用不一致，不能覆盖安装" }
        if (Build.VERSION.SDK_INT >= 24) check((archive.applicationInfo?.minSdkVersion ?: Int.MAX_VALUE) <= Build.VERSION.SDK_INT) { "APK 不支持当前 Android 版本" }
        val abis = ZipFile(file).use { zip -> zip.entries().asSequence()
            .map { it.name }.filter { it.startsWith("lib/") && it.endsWith("/libflutter.so") }
            .map { it.split('/')[1] }.toSet() }
        check(abis.any { Build.SUPPORTED_ABIS.contains(it) }) { "APK 不支持当前盒子的 CPU 架构" }
        return file
    }
}
