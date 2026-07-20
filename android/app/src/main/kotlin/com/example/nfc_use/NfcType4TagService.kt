package com.example.nfc_use

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log
import java.nio.charset.StandardCharsets

class NfcType4TagService : HostApduService() {

    companion object {
        private const val TAG = "NfcType4Tag"

        const val NDEF_TYPE_AID = "D2760000850101"

        private const val SW_SUCCESS = "9000"
        private const val SW_SUCCESS_MORE = "61"
        private const val SW_FILE_NOT_FOUND = "6A82"
        private const val SW_WRONG_LENGTH = "6700"
        private const val SW_CONDITIONS_NOT_SATISFIED = "6985"
        private const val SW_WRONG_P1P2 = "6B00"
        private const val SW_INS_NOT_SUPPORTED = "6D00"
        private const val SW_CLA_NOT_SUPPORTED = "6E00"
        private const val SW_WRONG_DATA = "6A80"
        private const val SW_UNKNOWN = "6F00"

        private const val FILE_ID_CC = "E103"
        private const val FILE_ID_NDEF = "E104"

        private const val MAX_NDEF_SIZE = 512

        @Volatile
        private var ndefPayload: String = ""

        @Volatile
        private var apduCount: Int = 0

        fun setNdefPayload(payload: String) {
            ndefPayload = payload
            apduCount = 0
            Log.d(TAG, "Payload set: \"${payload.take(40)}\" (len=${payload.length})")
        }

        fun getNdefPayload(): String = ndefPayload

        fun getApduCount(): Int = apduCount
    }

    private enum class SelectedFile {
        NONE, CC, NDEF
    }

    private var selectedFile: SelectedFile = SelectedFile.NONE
    private var lastReadOffset: Int = 0
    private var sessionTag = 0

    private val ccFileBytes: ByteArray by lazy {
        buildCcFile()
    }

    private fun buildCcFile(): ByteArray {
        val ndefMaxSize = MAX_NDEF_SIZE
        return byteArrayOf(
            0x00, 0x0F.toByte(),   // CCLEN: 15 bytes
            0x30.toByte(),          // Mapping Version: 3.0 (compatible with v2 readers)
            0x00, 0xF6.toByte(),   // MLe: max R-APDU data = 246 bytes
            0x00, 0xF6.toByte(),   // MLc: max C-APDU data = 246 bytes
            0x04, 0x06,             // NDEF File Control TLV: T=04, L=06
            0xE1.toByte(), 0x04,    // NDEF File Identifier (E1 04)
            (ndefMaxSize shr 8).toByte(),
            (ndefMaxSize and 0xFF).toByte(), // Max NDEF size
            0x00, 0x00              // Read access: 00=full, Write access: 00=full
        )
    }

    private fun buildNdefFileBytes(): ByteArray {
        val text = ndefPayload
        if (text.isEmpty()) {
            return byteArrayOf(0x00, 0x00)
        }

        val textBytes = text.toByteArray(StandardCharsets.UTF_8)
        val languageCode = "en".toByteArray(StandardCharsets.US_ASCII)

        val textPayloadLen = 1 + languageCode.size + textBytes.size
        if (textPayloadLen > 255) {
            Log.w(TAG, "NDEF payload too long for short record, truncating")
            val truncated = textBytes.copyOf(255 - 1 - languageCode.size)
            return buildNdefFileWithRecord(languageCode, truncated)
        }

        return buildNdefFileWithRecord(languageCode, textBytes)
    }

    private fun buildNdefFileWithRecord(
        languageCode: ByteArray,
        textBytes: ByteArray
    ): ByteArray {
        val textPayloadLen = 1 + languageCode.size + textBytes.size
        val ndefRecordLen = 2 + 1 + textPayloadLen // header + typeLen + payloadLen + type + payload

        val ndefRecord = ByteArray(ndefRecordLen)
        var pos = 0

        ndefRecord[pos++] = (0xD1).toByte() // MB=1, ME=1, CF=0, SR=1, IL=0, TNF=001
        ndefRecord[pos++] = 0x01 // Type Length = 1
        ndefRecord[pos++] = textPayloadLen.toByte() // Payload Length (short record)
        ndefRecord[pos++] = 0x54 // Type: 'T' (Text)

        ndefRecord[pos++] = languageCode.size.toByte() // Text Record: status byte (UTF-8 + lang len)
        System.arraycopy(languageCode, 0, ndefRecord, pos, languageCode.size)
        pos += languageCode.size
        System.arraycopy(textBytes, 0, ndefRecord, pos, textBytes.size)
        pos += textBytes.size

        val ndefFile = ByteArray(2 + ndefRecordLen)
        ndefFile[0] = (ndefRecordLen shr 8).toByte()
        ndefFile[1] = (ndefRecordLen and 0xFF).toByte()
        System.arraycopy(ndefRecord, 0, ndefFile, 2, ndefRecordLen)

        return ndefFile
    }

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        apduCount++
        val hex = toHexString(commandApdu)
        Log.d(TAG, "APDU[$apduCount]: $hex (${commandApdu.size} bytes)")

        try {
            if (commandApdu.size < 4) {
                Log.w(TAG, "  -> WRONG_LENGTH (too short)")
                return hexToBytes(SW_WRONG_LENGTH)
            }

            val cla = commandApdu[0].toInt() and 0xFF
            val ins = commandApdu[1].toInt() and 0xFF
            val p1 = commandApdu[2].toInt() and 0xFF
            val p2 = commandApdu[3].toInt() and 0xFF

            if (cla != 0x00 && cla != 0xFF.toInt() && cla != 0x80 && cla != 0x40) {
                Log.w(TAG, "  -> CLA_NOT_SUPPORTED (${String.format("%02X", cla)})")
                return hexToBytes(SW_CLA_NOT_SUPPORTED)
            }

            val response = when (ins) {
                0xA4 -> handleSelect(p1, p2, commandApdu)
                0xB0 -> handleReadBinary(p1, p2, commandApdu)
                0xC0 -> handleGetResponse(commandApdu)
                else -> {
                    Log.w(TAG, "  -> INS_NOT_SUPPORTED (${String.format("%02X", ins)})")
                    hexToBytes(SW_INS_NOT_SUPPORTED)
                }
            }

            val swBytes = response.takeLast(2).toByteArray()
            Log.d(TAG, "  -> SW=${toHexString(swBytes).uppercase()} data=${response.size - 2} bytes")
            return response
        } catch (e: Exception) {
            Log.e(TAG, "Error processing APDU", e)
            return hexToBytes(SW_UNKNOWN)
        }
    }

    private fun handleSelect(p1: Int, p2: Int, commandApdu: ByteArray): ByteArray {
        if (commandApdu.size < 5) {
            return hexToBytes(SW_WRONG_LENGTH)
        }

        val lc = commandApdu[4].toInt() and 0xFF
        if (lc > 0 && commandApdu.size < 5 + lc) {
            return hexToBytes(SW_WRONG_LENGTH)
        }

        val data = if (lc > 0) commandApdu.copyOfRange(5, 5 + lc) else byteArrayOf()
        val dataHex = toHexString(data).uppercase()

        return when (p1) {
            0x04 -> handleSelectByAid(dataHex, p2)
            0x00, 0x09 -> handleSelectById(dataHex, p2, lc)
            else -> {
                Log.w(TAG, "  SELECT: unknown P1=${String.format("%02X", p1)}")
                hexToBytes(SW_WRONG_P1P2)
            }
        }
    }

    private fun handleSelectByAid(aidHex: String, p2: Int): ByteArray {
        val targetAid = NDEF_TYPE_AID.uppercase()

        val matches = when (p2 and 0x03) {
            0x00, 0x01 -> aidHex == targetAid
            0x02 -> targetAid.startsWith(aidHex)
            else -> false
        }

        if (matches) {
            selectedFile = SelectedFile.NONE
            lastReadOffset = 0
            sessionTag++
            Log.d(TAG, "  SELECT AID OK: $aidHex")
            return hexToBytes(SW_SUCCESS)
        }

        Log.w(TAG, "  SELECT AID FAIL: $aidHex (expected $targetAid)")
        return hexToBytes(SW_FILE_NOT_FOUND)
    }

    private fun handleSelectById(idHex: String, p2: Int, lc: Int): ByteArray {
        if (lc != 2) {
            Log.w(TAG,  "  SELECT by ID: wrong length=$lc")
            return hexToBytes(SW_FILE_NOT_FOUND)
        }

        return when (idHex.uppercase()) {
            FILE_ID_CC -> {
                selectedFile = SelectedFile.CC
                lastReadOffset = 0
                Log.d(TAG, "  SELECT CC file OK")
                hexToBytes(SW_SUCCESS)
            }
            FILE_ID_NDEF -> {
                selectedFile = SelectedFile.NDEF
                lastReadOffset = 0
                Log.d(TAG, "  SELECT NDEF file OK")
                hexToBytes(SW_SUCCESS)
            }
            else -> {
                Log.w(TAG, "  SELECT by ID FAIL: $idHex")
                hexToBytes(SW_FILE_NOT_FOUND)
            }
        }
    }

    private fun handleReadBinary(p1: Int, p2: Int, commandApdu: ByteArray): ByteArray {
        if (selectedFile == SelectedFile.NONE) {
            Log.w(TAG, "  READ_BINARY: no file selected")
            return hexToBytes(SW_CONDITIONS_NOT_SATISFIED)
        }

        val offset = ((p1 and 0xFF) shl 8) or (p2 and 0xFF)
        lastReadOffset = offset

        val le = if (commandApdu.size >= 5) {
            commandApdu[4].toInt() and 0xFF
        } else {
            0x00
        }
        val readLength = if (le == 0) 255 else le

        val fileData = when (selectedFile) {
            SelectedFile.CC -> ccFileBytes
            SelectedFile.NDEF -> buildNdefFileBytes()
            else -> byteArrayOf()
        }

        val totalSize = fileData.size

        if (offset >= totalSize) {
            Log.d(TAG, "  READ_BINARY: offset=$offset beyond size=$totalSize")
            return hexToBytes(SW_SUCCESS)
        }

        val end = (offset + readLength).coerceAtMost(totalSize)
        val data = fileData.copyOfRange(offset, end)

        Log.d(TAG, "  READ_BINARY: file=${selectedFile.name} offset=$offset len=${data.size}/${readLength} total=$totalSize")

        val response = data + hexToBytes(SW_SUCCESS)
        return response
    }

    private fun handleGetResponse(commandApdu: ByteArray): ByteArray {
        val le = if (commandApdu.size >= 5) {
            commandApdu[4].toInt() and 0xFF
        } else {
            0x00
        }
        val readLength = if (le == 0) 255 else le

        val fileData = when (selectedFile) {
            SelectedFile.CC -> ccFileBytes
            SelectedFile.NDEF -> buildNdefFileBytes()
            else -> {
                return hexToBytes(SW_CONDITIONS_NOT_SATISFIED)
            }
        }

        val offset = lastReadOffset
        if (offset >= fileData.size) {
            return hexToBytes(SW_SUCCESS)
        }

        val end = (offset + readLength).coerceAtMost(fileData.size)
        val data = fileData.copyOfRange(offset, end)
        lastReadOffset = end

        val remaining = fileData.size - end
        return if (remaining > 0) {
            val sw1 = 0x61
            val sw2 = remaining.coerceAtMost(255)
            data + byteArrayOf(sw1.toByte(), sw2.toByte())
        } else {
            data + hexToBytes(SW_SUCCESS)
        }
    }

    override fun onDeactivated(reason: Int) {
        Log.d(TAG, "Deactivated: reason=$reason, total APDUs=$apduCount, session=$sessionTag")
        selectedFile = SelectedFile.NONE
        lastReadOffset = 0
    }

    private fun hexToBytes(hex: String): ByteArray {
        val clean = hex.replace(" ", "")
        val len = clean.length
        val result = ByteArray(len / 2)
        for (i in 0 until len step 2) {
            result[i / 2] = ((Character.digit(clean[i], 16) shl 4) +
                    Character.digit(clean[i + 1], 16)).toByte()
        }
        return result
    }

    private fun toHexString(bytes: ByteArray): String {
        val sb = StringBuilder()
        for (b in bytes) {
            sb.append(String.format("%02X", b.toInt() and 0xFF))
        }
        return sb.toString()
    }
}
