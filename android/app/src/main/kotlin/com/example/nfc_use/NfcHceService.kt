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

        // AID: F0010203040506 (7 bytes)
        // SELECT AID 指令: 00 A4 04 00 07 F0 01 02 03 04 05 06
        val SELECT_AID_HEADER = byteArrayOf(
            0x00.toByte(), 0xA4.toByte(), 0x04.toByte(), 0x00.toByte()
        )
        val AID_BYTES = byteArrayOf(
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
    }

    private var apduCount = 0

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        apduCount++
        val hex = toHex(commandApdu)
        Log.d(TAG, "APDU[$apduCount]: $hex (${commandApdu.size}B)")

        if (commandApdu.size < 5) {
            Log.w(TAG, "  -> wrong length")
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
                response
            } else {
                Log.w(TAG, "  -> emulation disabled, return 6A82")
                SW_FILE_NOT_FOUND
            }
        }

        Log.w(TAG, "  -> unknown command, return 6F00")
        return SW_UNKNOWN
    }

    private fun isSelectAidCommand(apdu: ByteArray): Boolean {
        if (apdu.size < 4 + 1 + AID_BYTES.size) return false

        // CLA INS P1 P2 检查
        for (i in 0 until 4) {
            if (apdu[i] != SELECT_AID_HEADER[i]) return false
        }

        // Lc 检查
        val lc = apdu[4].toInt() and 0xFF
        if (lc != AID_BYTES.size) return false

        // AID 数据检查（前 7 字节匹配）
        for (i in AID_BYTES.indices) {
            if (apdu[5 + i] != AID_BYTES[i]) return false
        }

        return true
    }

    override fun onDeactivated(reason: Int) {
        Log.d(TAG, "Deactivated, reason=$reason, total APDUs=$apduCount")
    }

    private fun toHex(bytes: ByteArray): String {
        val sb = StringBuilder()
        for (b in bytes) {
            sb.append(String.format("%02X ", b.toInt() and 0xFF))
        }
        return sb.toString().trim()
    }
}
