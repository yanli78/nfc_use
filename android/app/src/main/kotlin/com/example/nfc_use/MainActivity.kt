package com.example.nfc_use

import android.content.ComponentName
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
                    result.success(isDefaultPaymentApp(ctx))
                }
                "isDefaultPaymentApp" -> {
                    result.success(isDefaultPaymentApp(ctx))
                }
                "requestSetDefaultPaymentApp" -> {
                    result.success(requestSetDefaultPaymentApp())
                }
                "enableEmulation" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    // 获取 Flutter 传来的动态 token，如果没有则默认 "FlutterAuto"
                    val token = call.argument<String>("token") ?: "FlutterAuto"

                    NfcHceService.resetDebugInfo(ctx, enabled, token)
                    // 保留原本的内存变量更新
                    NfcHceService.setEmulationEnabled(enabled)
                    result.success(true)
                }
                "isEmulationEnabled" -> {
                    val prefs = ctx.getSharedPreferences("hce_prefs", Context.MODE_PRIVATE)
                    result.success(prefs.getBoolean("hce_enabled", NfcHceService.isEmulationEnabled()))
                }
                "getHceDebugInfo" -> {
                    result.success(NfcHceService.getDebugInfo(ctx))
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

    private fun isDefaultPaymentApp(context: Context): Boolean {
        return try {
            val adapter = NfcAdapter.getDefaultAdapter(context) ?: return false
            val ce = CardEmulation.getInstance(adapter) ?: return false
            val component = ComponentName(context, NfcHceService::class.java)
            ce.isDefaultServiceForCategory(component, CardEmulation.CATEGORY_PAYMENT)
        } catch (e: Exception) {
            false
        }
    }

    private fun requestSetDefaultPaymentApp(): Boolean {
        return try {
            val component = ComponentName(this, NfcHceService::class.java)
            val intent = Intent(CardEmulation.ACTION_CHANGE_DEFAULT).apply {
                putExtra(CardEmulation.EXTRA_CATEGORY, CardEmulation.CATEGORY_PAYMENT)
                putExtra(CardEmulation.EXTRA_SERVICE_COMPONENT, component)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            openNfcSettings(this)
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
