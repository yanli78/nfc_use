package com.example.nfc_use

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log
import java.nio.charset.StandardCharsets

import android.content.Context

// File path: android/app/src/main/kotlin/com/example/nfc_use/NfcHceService.kt
// HCE 服务：响应 AID=F0010203040506 的 SELECT 指令，返回 "FlutterAuto" + 9000
class NfcHceService : HostApduService() {

    companion object {
        private const val TAG = "NfcHceService"
        private const val PREFS_NAME = "hce_prefs"

        // AID: F0010203040506 (7 bytes)
        // SELECT AID 指令通常为: 00 A4 04 P2 07 F0 01 02 03 04 05 06 [Le]
        private val AID_BYTES = byteArrayOf(
            0xF0.toByte(), 0x01, 0x02, 0x03, 0x04, 0x05, 0x06
        )

        // 响应数据: "FlutterAuto" 的 UTF-8 字节
        // val RESPONSE_DATA = "FlutterAuto".toByteArray(StandardCharsets.UTF_8)

        // SW 状态码
        val SW_SUCCESS = byteArrayOf(0x90.toByte(), 0x00.toByte())
        val SW_FILE_NOT_FOUND = byteArrayOf(0x6A.toByte(), 0x82.toByte())
        val SW_WRONG_LENGTH = byteArrayOf(0x67.toByte(), 0x00.toByte())
        val SW_UNKNOWN = byteArrayOf(0x6F.toByte(), 0x00.toByte())

        // 响应标志：Flutter 端可启用/禁用响应
        @Volatile
        private var emulationEnabled: Boolean = true

        fun setEmulationEnabled(enabled: Boolean) {
            emulationEnabled = enabled
            Log.d(TAG, "Emulation ${if (enabled) "enabled" else "disabled"}")
        }

        fun isEmulationEnabled(): Boolean = emulationEnabled

        fun resetDebugInfo(context: Context, enabled: Boolean, token: String) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean("hce_enabled", enabled)
                .putString("hce_token", token)
                .putInt("hce_apdu_count", 0)
                .putString(
                    "hce_last_event",
                    if (enabled) "HCE 已启用，等待读卡器靠近" else "HCE 已关闭"
                )
                .putString("hce_last_apdu", "")
                .putString("hce_last_response", "")
                .putLong("hce_updated_at", System.currentTimeMillis())
                .apply()
        }

        fun getDebugInfo(context: Context): Map<String, Any> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return mapOf(
                "enabled" to prefs.getBoolean("hce_enabled", emulationEnabled),
                "token" to (prefs.getString("hce_token", "FlutterAuto") ?: "FlutterAuto"),
                "apduCount" to prefs.getInt("hce_apdu_count", 0),
                "lastEvent" to (prefs.getString("hce_last_event", "暂无 NFC 识别记录") ?: "暂无 NFC 识别记录"),
                "lastApdu" to (prefs.getString("hce_last_apdu", "") ?: ""),
                "lastResponse" to (prefs.getString("hce_last_response", "") ?: ""),
                "updatedAt" to prefs.getLong("hce_updated_at", 0L),
            )
        }
    }

    private var apduCount = 0

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        apduCount++
        val hex = toHex(commandApdu)
        Log.d(TAG, "APDU[$apduCount]: $hex (${commandApdu.size}B)")

        if (commandApdu.size < 5) {
            Log.w(TAG, "  -> wrong length")
            recordDebug("APDU 长度错误", hex, toHex(SW_WRONG_LENGTH))
            return SW_WRONG_LENGTH
        }

        if (isSelectAidCommand(commandApdu)) {
            // 从 SharedPreferences 获取最新的状态和 Token，防止系统杀死后台导致内存变量丢失
            val prefs = getSharedPreferences("hce_prefs", Context.MODE_PRIVATE)
            val isEnabled = prefs.getBoolean("hce_enabled", emulationEnabled)

            return if (isEnabled) {
                val currentToken = prefs.getString("hce_token", "FlutterAuto") ?: "FlutterAuto"
                val responseData = currentToken.toByteArray(StandardCharsets.UTF_8)
                val response = responseData + SW_SUCCESS
                
                Log.d(TAG, "  -> SELECT AID OK, resp=${toHex(responseData)} 9000")
                recordDebug("识别成功：已返回 Token \"$currentToken\"", hex, toHex(response))
                response
            } else {
                Log.w(TAG, "  -> emulation disabled, return 6A82")
                recordDebug("读卡器已靠近，但 HCE 未启用", hex, toHex(SW_FILE_NOT_FOUND))
                SW_FILE_NOT_FOUND
            }
        }

        Log.w(TAG, "  -> unknown command, return 6F00")
        recordDebug("收到未知 APDU 指令", hex, toHex(SW_UNKNOWN))
        return SW_UNKNOWN
    }

    private fun isSelectAidCommand(apdu: ByteArray): Boolean {
        val selectOffset = findSelectByAidOffset(apdu) ?: return false
        if (apdu.size <= selectOffset + 4) return false

        val lc = apdu[selectOffset + 4].toInt() and 0xFF
        val dataStart = selectOffset + 5
        val declaredDataEnd = dataStart + lc

        val dataEnd = if (lc > 0 && declaredDataEnd <= apdu.size) {
            declaredDataEnd
        } else {
            apdu.size
        }

        if (dataEnd <= dataStart) return false

        val dataField = apdu.copyOfRange(dataStart, dataEnd)
        val matched = containsBytes(dataField, AID_BYTES)

        if (!matched) {
            Log.w(
                TAG,
                "  SELECT by AID header found, but AID not matched. data=${toHex(dataField)}"
            )
        }

        return matched
    }

    private fun findSelectByAidOffset(apdu: ByteArray): Int? {
        if (apdu.size < 5) return null

        for (offset in 0..apdu.size - 5) {
            val cla = apdu[offset].toInt() and 0xFF
            val ins = apdu[offset + 1].toInt() and 0xFF
            val p1 = apdu[offset + 2].toInt() and 0xFF

            if (cla == 0x00 && ins == 0xA4 && p1 == 0x04) {
                return offset
            }
        }

        return null
    }

    private fun containsBytes(source: ByteArray, target: ByteArray): Boolean {
        if (target.isEmpty() || source.size < target.size) return false

        for (start in 0..source.size - target.size) {
            var matched = true
            for (i in target.indices) {
                if (source[start + i] != target[i]) {
                    matched = false
                    break
                }
            }
            if (matched) return true
        }

        return false
    }

    override fun onDeactivated(reason: Int) {
        Log.d(TAG, "Deactivated, reason=$reason, total APDUs=$apduCount")
        recordDebug("读卡器连接已断开：reason=$reason", "", "")
    }

    private fun recordDebug(event: String, apduHex: String, responseHex: String) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val count = if (apduHex.isNotEmpty()) {
            prefs.getInt("hce_apdu_count", 0) + 1
        } else {
            prefs.getInt("hce_apdu_count", 0)
        }

        val editor = prefs.edit()
            .putInt("hce_apdu_count", count)
            .putString("hce_last_event", event)
            .putLong("hce_updated_at", System.currentTimeMillis())

        if (apduHex.isNotEmpty()) {
            editor.putString("hce_last_apdu", apduHex)
        }
        if (responseHex.isNotEmpty()) {
            editor.putString("hce_last_response", responseHex)
        }

        editor.apply()
    }

    private fun toHex(bytes: ByteArray): String {
        val sb = StringBuilder()
        for (b in bytes) {
            sb.append(String.format("%02X ", b.toInt() and 0xFF))
        }
        return sb.toString().trim()
    }
}
