import 'dart:async';

import 'package:flutter_nfc_hce/flutter_nfc_hce.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_use/core/constants/card_item.dart';

enum NfcWriteStatus {
  success,
  unavailable,
  tagNotFound,
  tagNotWritable,
  writeFailed,
  sessionCancelled,
  invalidPayload,
  hceUnsupported,
  hceStartFailed,
}

class NfcWriteResult {
  final NfcWriteStatus status;
  final String message;
  final String? payload;
  final Object? error;

  const NfcWriteResult({
    required this.status,
    required this.message,
    this.payload,
    this.error,
  });

  bool get isSuccess => status == NfcWriteStatus.success;
}

class NfcService {
  NfcService._();

  static final NfcService instance = NfcService._();

  final FlutterNfcHce _hce = FlutterNfcHce();
  bool _isWriting = false;
  bool _isEmulating = false;

  Future<bool> isNfcAvailable() {
    return NfcManager.instance.isAvailable();
  }

  Future<NfcWriteResult> checkNfcPermissionAndState() async {
    try {
      final isAvailable = await isNfcAvailable();
      if (!isAvailable) {
        return const NfcWriteResult(
          status: NfcWriteStatus.unavailable,
          message: '当前设备不支持 NFC，或 NFC 未开启',
        );
      }

      return const NfcWriteResult(
        status: NfcWriteStatus.success,
        message: 'NFC 可用',
      );
    } catch (error) {
      return NfcWriteResult(
        status: NfcWriteStatus.unavailable,
        message: 'NFC 状态检测失败',
        error: error,
      );
    }
  }

  Future<NfcWriteResult> writeCardId(CardItem card) {
    return emulateCardIdForPn532(card);
  }

  Future<NfcWriteResult> emulateCardIdForPn532(
    CardItem card, {
    bool persistMessage = true,
  }) {
    return startHce(card.id, persistMessage: persistMessage);
  }

  Future<NfcWriteResult> startHce(
    String value, {
    String mimeType = 'text/plain',
    bool persistMessage = true,
  }) async {
    final payload = _formatPayload(value);
    if (payload == null) {
      return const NfcWriteResult(
        status: NfcWriteStatus.invalidPayload,
        message: '模拟内容不能为空',
      );
    }

    try {
      final isNfcEnabled = await _hce.isNfcEnabled();
      if (!isNfcEnabled) {
        return const NfcWriteResult(
          status: NfcWriteStatus.unavailable,
          message: '当前设备 NFC 未开启',
          payload: null,
        );
      }

      final isHceSupported = await _hce.isNfcHceSupported();
      if (!isHceSupported) {
        return NfcWriteResult(
          status: NfcWriteStatus.hceUnsupported,
          message: '当前设备不支持 NFC 卡模拟，无法被 PN532 读取',
          payload: payload,
        );
      }

      await _hce.startNfcHce(
        payload,
        mimeType: mimeType,
        persistMessage: persistMessage,
      );
      _isEmulating = true;

      return NfcWriteResult(
        status: NfcWriteStatus.success,
        message: '已启动 NFC 卡模拟，请使用 PN532 读取',
        payload: payload,
      );
    } catch (error) {
      return NfcWriteResult(
        status: NfcWriteStatus.hceStartFailed,
        message: 'NFC 卡模拟启动失败',
        payload: payload,
        error: error,
      );
    }
  }

  Future<NfcWriteResult> stopHce() async {
    try {
      await _hce.stopNfcHce();
      _isEmulating = false;

      return const NfcWriteResult(
        status: NfcWriteStatus.success,
        message: '已停止 NFC 卡模拟',
      );
    } catch (error) {
      return NfcWriteResult(
        status: NfcWriteStatus.hceStartFailed,
        message: 'NFC 卡模拟停止失败',
        error: error,
      );
    }
  }

  bool get isEmulating => _isEmulating;

  Future<NfcWriteResult> writeCardIdToTag(
    CardItem card, {
    Duration timeout = const Duration(seconds: 20),
  }) {
    return writeString(card.id, timeout: timeout);
  }

  Future<NfcWriteResult> writeString(
    String value, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final payload = _formatPayload(value);
    if (payload == null) {
      return const NfcWriteResult(
        status: NfcWriteStatus.invalidPayload,
        message: '写入内容不能为空',
      );
    }

    if (_isWriting) {
      await stopSession(errorMessage: '已取消上一次 NFC 写入会话');
    }

    final stateResult = await checkNfcPermissionAndState();
    if (!stateResult.isSuccess) return stateResult;

    final completer = Completer<NfcWriteResult>();
    _isWriting = true;

    Timer? timer;
    timer = Timer(timeout, () async {
      if (completer.isCompleted) return;
      await stopSession(errorMessage: '未检测到 NFC 标签，写入超时');
      completer.complete(
        NfcWriteResult(
          status: NfcWriteStatus.tagNotFound,
          message: '未检测到 NFC 标签，写入超时',
          payload: payload,
        ),
      );
    });

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (tag) async {
          if (completer.isCompleted) return;

          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              await stopSession(errorMessage: '当前标签不支持 NDEF 格式');
              completer.complete(
                NfcWriteResult(
                  status: NfcWriteStatus.tagNotWritable,
                  message: '当前标签不支持 NDEF 格式',
                  payload: payload,
                ),
              );
              return;
            }

            if (!ndef.isWritable) {
              await stopSession(errorMessage: '当前 NFC 标签不可写');
              completer.complete(
                NfcWriteResult(
                  status: NfcWriteStatus.tagNotWritable,
                  message: '当前 NFC 标签不可写',
                  payload: payload,
                ),
              );
              return;
            }

            final message = NdefMessage([NdefRecord.createText(payload)]);
            final capacity = ndef.maxSize;
            final messageSize = message.byteLength;

            if (capacity > 0 && messageSize > capacity) {
              await stopSession(errorMessage: '写入内容超过标签容量');
              completer.complete(
                NfcWriteResult(
                  status: NfcWriteStatus.writeFailed,
                  message: '写入内容超过标签容量',
                  payload: payload,
                ),
              );
              return;
            }

            await ndef.write(message);
            await stopSession(alertMessage: '写入成功');
            completer.complete(
              NfcWriteResult(
                status: NfcWriteStatus.success,
                message: 'NFC 标签写入成功',
                payload: payload,
              ),
            );
          } catch (error) {
            await stopSession(errorMessage: 'NFC 标签写入失败');
            if (!completer.isCompleted) {
              completer.complete(
                NfcWriteResult(
                  status: NfcWriteStatus.writeFailed,
                  message: 'NFC 标签写入失败',
                  payload: payload,
                  error: error,
                ),
              );
            }
          }
        },
      );
    } catch (error) {
      timer.cancel();
      _isWriting = false;
      return NfcWriteResult(
        status: NfcWriteStatus.writeFailed,
        message: 'NFC 会话启动失败',
        payload: payload,
        error: error,
      );
    }

    final result = await completer.future;
    timer.cancel();
    _isWriting = false;
    return result;
  }

  Future<void> stopSession({String? alertMessage, String? errorMessage}) async {
    try {
      await NfcManager.instance.stopSession(
        alertMessage: alertMessage,
        errorMessage: errorMessage,
      );
    } catch (_) {}
    _isWriting = false;
  }

  String? _formatPayload(String value) {
    final payload = value.trim();
    if (payload.isEmpty) return null;
    return payload;
  }
}
