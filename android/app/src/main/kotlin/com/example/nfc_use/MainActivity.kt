package com.example.nfc_use

import android.content.Context
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.cardemulation.CardEmulation
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// File path: android/app/src/main/kotlin/com/example/nfc_use/MainActivity.kt
// MethodChannel 桥接：检查 HCE 支持、启用/禁用模拟、打开 NFC 设置
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.nfc.hce/command"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val ctx = applicationContext
            when (call.method) {
                "isNfcEnabled" -> {
                    result.success(isNfcEnabled(ctx))
                }
                "isHceSupported" -> {
                    result.success(isHceSupported(ctx))
                }
                "isDefaultService" -> {
                    result.success(isDefaultService(ctx))
                }
                "enableEmulation" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    // 获取 Flutter 传来的动态 token，如果没有则默认 "FlutterAuto"
                    val token = call.argument<String>("token") ?: "FlutterAuto"

                    // 保存到 SharedPreferences (跨进程持久化)
                    val prefs = ctx.getSharedPreferences("hce_prefs", Context.MODE_PRIVATE)
                    prefs.edit()
                        .putBoolean("hce_enabled", enabled)
                        .putString("hce_token", token)
                        .apply()

                    // 保留原本的内存变量更新
                    NfcHceService.setEmulationEnabled(enabled)
                    result.success(true)
                }
                "isEmulationEnabled" -> {
                    result.success(NfcHceService.isEmulationEnabled())
                }
                "openNfcSettings" -> {
                    openNfcSettings(ctx)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isNfcEnabled(context: Context): Boolean {
        return try {
            val adapter = NfcAdapter.getDefaultAdapter(context)
            adapter?.isEnabled == true
        } catch (e: Exception) {
            false
        }
    }

    private fun isHceSupported(context: Context): Boolean {
        return try {
            val adapter = NfcAdapter.getDefaultAdapter(context) ?: return false
            CardEmulation.getInstance(adapter) != null
        } catch (e: Exception) {
            false
        }
    }

    private fun isDefaultService(context: Context): Boolean {
        return try {
            val adapter = NfcAdapter.getDefaultAdapter(context) ?: return false
            val ce = CardEmulation.getInstance(adapter) ?: return false
            val component = android.content.ComponentName(context, NfcHceService::class.java)
            ce.isDefaultServiceForCategory(component, CardEmulation.CATEGORY_OTHER)
        } catch (e: Exception) {
            false
        }
    }

    private fun openNfcSettings(context: Context) {
        try {
            val intent = Intent(Settings.ACTION_NFC_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (e: Exception) {
            // ignore
        }
    }
}
