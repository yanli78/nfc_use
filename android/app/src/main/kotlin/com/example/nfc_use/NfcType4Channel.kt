package com.example.nfc_use

import android.content.Context
import android.nfc.NfcAdapter
import android.nfc.cardemulation.CardEmulation
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class NfcType4Channel(private val context: Context) {

    companion object {
        private const val CHANNEL = "com.example.nfc_use/type4_ndef"

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            val handler = NfcType4Channel(context)
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isNfcEnabled" -> result.success(handler.isNfcEnabled())
                    "isHceSupported" -> result.success(handler.isHceSupported())
                    "setNdefPayload" -> {
                        val payload = call.argument<String>("payload") ?: ""
                        handler.setNdefPayload(payload)
                        result.success(true)
                    }
                    "getNdefPayload" -> result.success(handler.getNdefPayload())
                    "isServiceDefault" -> result.success(handler.isServiceDefault())
                    "openNfcSettings" -> {
                        handler.openNfcSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private val nfcAdapter: NfcAdapter? by lazy {
        NfcAdapter.getDefaultAdapter(context)
    }

    private val cardEmulation: CardEmulation? by lazy {
        nfcAdapter?.let { CardEmulation.getInstance(it) }
    }

    fun isNfcEnabled(): Boolean {
        return try {
            nfcAdapter?.isEnabled == true
        } catch (e: Exception) {
            false
        }
    }

    fun isHceSupported(): Boolean {
        return try {
            cardEmulation != null
        } catch (e: Exception) {
            false
        }
    }

    fun setNdefPayload(payload: String) {
        NfcType4TagService.setNdefPayload(payload)
    }

    fun getNdefPayload(): String {
        return NfcType4TagService.getNdefPayload()
    }

    fun isServiceDefault(): Boolean {
        return try {
            val ce = cardEmulation ?: return false
            val componentName = android.content.ComponentName(
                context,
                NfcType4TagService::class.java
            )
            ce.isDefaultServiceForCategory(
                componentName,
                CardEmulation.CATEGORY_OTHER
            )
        } catch (e: Exception) {
            false
        }
    }

    fun openNfcSettings() {
        try {
            val intent = android.content.Intent(Settings.ACTION_NFC_SETTINGS)
            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (e: Exception) {
            // Ignore
        }
    }
}
