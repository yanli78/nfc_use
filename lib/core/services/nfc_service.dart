import 'dart:async';

import 'package:flutter_nfc_hce/flutter_nfc_hce.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_use/core/constants/card_item.dart';

/// NFC写入操作状态枚举
///
/// 定义NFC操作可能的各种结果状态，用于标识操作成功或失败的具体原因。
enum NfcWriteStatus {
  /// 操作成功
  success,

  /// NFC设备不可用（未支持或未开启）
  unavailable,

  /// 未检测到NFC标签
  tagNotFound,

  /// NFC标签不可写
  tagNotWritable,

  /// 写入失败
  writeFailed,

  /// 会话已取消
  sessionCancelled,

  /// 写入内容无效（为空）
  invalidPayload,

  /// 设备不支持HCE（主机卡模拟）
  hceUnsupported,

  /// HCE启动失败
  hceStartFailed,
}

/// NFC写入操作结果类
///
/// 封装NFC操作的结果信息，包括操作状态、提示消息、写入的内容和可能的错误对象。
class NfcWriteResult {
  /// 操作状态
  final NfcWriteStatus status;

  /// 操作结果提示消息
  final String message;

  /// 写入的NFC内容（可选）
  final String? payload;

  /// 操作过程中发生的错误对象（可选）
  final Object? error;

  /// 创建NFC写入结果实例
  ///
  /// [status] 操作状态
  /// [message] 结果提示消息
  /// [payload] 写入的内容（可选）
  /// [error] 错误对象（可选）
  const NfcWriteResult({
    required this.status,
    required this.message,
    this.payload,
    this.error,
  });

  /// 判断操作是否成功
  bool get isSuccess => status == NfcWriteStatus.success;
}

/// NFC服务类
///
/// 提供NFC相关的核心功能，包括：
/// - NFC设备可用性检测
/// - NFC标签写入（NDEF格式）
/// - NFC主机卡模拟（HCE）功能，支持PN532模块读取
/// - NFC会话管理
///
/// 采用单例模式，通过 [instance] 获取唯一实例。
class NfcService {
  /// 私有构造函数
  NfcService._();

  /// NFC服务单例实例
  static final NfcService instance = NfcService._();

  /// HCE插件实例
  final FlutterNfcHce _hce = FlutterNfcHce();

  /// 当前是否正在写入NFC标签
  bool _isWriting = false;

  /// 当前是否正在进行NFC卡模拟
  bool _isEmulating = false;

  /// 检查NFC设备是否可用
  ///
  /// 返回 `true` 表示设备支持NFC且已开启，`false` 表示不支持或未开启。
  Future<bool> isNfcAvailable() {
    return NfcManager.instance.isAvailable();
  }

  /// 检查NFC权限和状态
  ///
  /// 综合检测NFC设备是否可用、权限是否已获取。
  /// 返回包含检测结果的 [NfcWriteResult] 对象。
  Future<NfcWriteResult> checkNfcPermissionAndState() async {
    try {
      final isAvailable = await isNfcAvailable();
      if (!isAvailable) {
        return NfcWriteResult(
          status: NfcWriteStatus.unavailable,
          message: kNfcUnavailableMessage,
        );
      }

      return const NfcWriteResult(
        status: NfcWriteStatus.success,
        message: 'NFC可用',
      );
    } catch (error) {
      return NfcWriteResult(
        status: NfcWriteStatus.unavailable,
        message: kNfcStateCheckFailedMessage,
        error: error,
      );
    }
  }

  /// 写入卡片ID到NFC
  ///
  /// 根据卡片信息执行NFC写入操作。当前实现调用 [emulateCardIdForPn532]
  /// 使用HCE模式模拟卡片，以便PN532模块可以读取。
  ///
  /// [card] 卡片数据对象
  /// 返回包含操作结果的 [NfcWriteResult] 对象
  Future<NfcWriteResult> writeCardId(CardItem card) {
    return emulateCardIdForPn532(card);
  }

  /// 使用HCE模拟卡片ID，支持PN532模块读取
  ///
  /// 通过主机卡模拟（HCE）技术，让手机模拟成一张NFC卡片，
  /// 使得PN532等NFC读写模块可以直接读取手机中的数据。
  ///
  /// [card] 卡片数据对象，使用其ID作为模拟内容
  /// [persistMessage] 是否持久化消息，默认为 `true`
  /// 返回包含操作结果的 [NfcWriteResult] 对象
  Future<NfcWriteResult> emulateCardIdForPn532(
    CardItem card, {
    bool persistMessage = true,
  }) {
    return startHce(card.id, persistMessage: persistMessage);
  }

  /// 启动NFC主机卡模拟（HCE）
  ///
  /// 开启手机的HCE功能，使其能够模拟NFC标签。
  /// 模拟的数据将以指定的MIME类型格式发送给读取设备（如PN532模块）。
  ///
  /// [value] 要模拟的内容
  /// [mimeType] 内容的MIME类型，默认为 `text/plain`
  /// [persistMessage] 是否持久化消息，默认为 `true`
  /// 返回包含操作结果的 [NfcWriteResult] 对象
  Future<NfcWriteResult> startHce(
    String value, {
    String mimeType = 'text/plain',
    bool persistMessage = true,
  }) async {
    // 1. 校验内容有效性
    final payload = _formatPayload(value);
    if (payload == null) {
      return NfcWriteResult(
        status: NfcWriteStatus.invalidPayload,
        message: kNfcInvalidPayloadMessage,
      );
    }

    try {
      // 2. 检查NFC是否已开启
      final isNfcEnabled = await _hce.isNfcEnabled();
      if (!isNfcEnabled) {
        return NfcWriteResult(
          status: NfcWriteStatus.unavailable,
          message: kNfcNotEnabledMessage,
          payload: null,
        );
      }

      // 3. 检查设备是否支持HCE
      final isHceSupported = await _hce.isNfcHceSupported();
      if (!isHceSupported) {
        return NfcWriteResult(
          status: NfcWriteStatus.hceUnsupported,
          message: kNfcHceUnsupportedMessage,
          payload: payload,
        );
      }

      // 4. 启动HCE服务
      await _hce.startNfcHce(
        payload,
        mimeType: mimeType,
        persistMessage: persistMessage,
      );
      _isEmulating = true;

      return NfcWriteResult(
        status: NfcWriteStatus.success,
        message: kNfcHceStartSuccessMessage,
        payload: payload,
      );
    } catch (error) {
      return NfcWriteResult(
        status: NfcWriteStatus.hceStartFailed,
        message: kNfcHceStartFailedMessage,
        payload: payload,
        error: error,
      );
    }
  }

  /// 停止NFC主机卡模拟（HCE）
  ///
  /// 关闭手机的HCE功能，停止模拟NFC标签。
  ///
  /// 返回包含操作结果的 [NfcWriteResult] 对象
  Future<NfcWriteResult> stopHce() async {
    try {
      await _hce.stopNfcHce();
      _isEmulating = false;

      return const NfcWriteResult(
        status: NfcWriteStatus.success,
        message: kNfcHceStopSuccessMessage,
      );
    } catch (error) {
      return NfcWriteResult(
        status: NfcWriteStatus.hceStartFailed,
        message: kNfcHceStopFailedMessage,
        error: error,
      );
    }
  }

  /// 获取当前是否正在进行NFC卡模拟
  bool get isEmulating => _isEmulating;

  /// 写入卡片ID到物理NFC标签
  ///
  /// 将卡片的ID信息写入到物理NFC标签中，使用NDEF格式存储。
  ///
  /// [card] 卡片数据对象，使用其ID作为写入内容
  /// [timeout] 操作超时时间，默认为20秒
  /// 返回包含操作结果的 [NfcWriteResult] 对象
  Future<NfcWriteResult> writeCardIdToTag(
    CardItem card, {
    Duration timeout = const Duration(seconds: 20),
  }) {
    return writeString(card.id, timeout: timeout);
  }

  /// 写入字符串到物理NFC标签
  ///
  /// 将指定的字符串内容写入到物理NFC标签中，使用NDEF文本格式存储。
  /// 支持超时机制，防止无限等待标签。
  ///
  /// [value] 要写入的字符串内容
  /// [timeout] 操作超时时间，默认为20秒
  /// 返回包含操作结果的 [NfcWriteResult] 对象
  Future<NfcWriteResult> writeString(
    String value, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    // 1. 校验内容有效性
    final payload = _formatPayload(value);
    if (payload == null) {
      return NfcWriteResult(
        status: NfcWriteStatus.invalidPayload,
        message: kNfcInvalidPayloadMessage,
      );
    }

    // 2. 如果正在写入，先取消上一次会话
    if (_isWriting) {
      await stopSession(errorMessage: '已取消上一次NFC写入会话');
    }

    // 3. 检查NFC状态
    final stateResult = await checkNfcPermissionAndState();
    if (!stateResult.isSuccess) return stateResult;

    // 4. 创建完成器和超时定时器
    final completer = Completer<NfcWriteResult>();
    _isWriting = true;

    Timer? timer;
    timer = Timer(timeout, () async {
      if (completer.isCompleted) return;
      await stopSession(errorMessage: kNfcTagNotFoundMessage);
      completer.complete(
        NfcWriteResult(
          status: NfcWriteStatus.tagNotFound,
          message: kNfcTagNotFoundMessage,
          payload: payload,
        ),
      );
    });

    try {
      // 5. 启动NFC会话并监听标签发现
      await NfcManager.instance.startSession(
        onDiscovered: (tag) async {
          if (completer.isCompleted) return;

          try {
            // 5.1 获取NDEF标签对象
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              await stopSession(errorMessage: kNfcTagNotSupportedMessage);
              completer.complete(
                NfcWriteResult(
                  status: NfcWriteStatus.tagNotWritable,
                  message: kNfcTagNotSupportedMessage,
                  payload: payload,
                ),
              );
              return;
            }

            // 5.2 检查标签是否可写
            if (!ndef.isWritable) {
              await stopSession(errorMessage: kNfcTagNotWritableMessage);
              completer.complete(
                NfcWriteResult(
                  status: NfcWriteStatus.tagNotWritable,
                  message: kNfcTagNotWritableMessage,
                  payload: payload,
                ),
              );
              return;
            }

            // 5.3 创建NDEF消息并检查容量
            final message = NdefMessage([NdefRecord.createText(payload)]);
            final capacity = ndef.maxSize;
            final messageSize = message.byteLength;

            if (capacity > 0 && messageSize > capacity) {
              await stopSession(errorMessage: kNfcPayloadTooLargeMessage);
              completer.complete(
                NfcWriteResult(
                  status: NfcWriteStatus.writeFailed,
                  message: kNfcPayloadTooLargeMessage,
                  payload: payload,
                ),
              );
              return;
            }

            // 5.4 执行写入操作
            await ndef.write(message);
            await stopSession(alertMessage: kNfcWriteSuccessMessage);
            completer.complete(
              NfcWriteResult(
                status: NfcWriteStatus.success,
                message: kNfcWriteSuccessMessage,
                payload: payload,
              ),
            );
          } catch (error) {
            await stopSession(errorMessage: kNfcWriteErrorMessage);
            if (!completer.isCompleted) {
              completer.complete(
                NfcWriteResult(
                  status: NfcWriteStatus.writeFailed,
                  message: kNfcWriteErrorMessage,
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
        message: kNfcSessionStartFailedMessage,
        payload: payload,
        error: error,
      );
    }

    // 6. 等待操作完成并清理
    final result = await completer.future;
    timer.cancel();
    _isWriting = false;
    return result;
  }

  /// 停止NFC会话
  ///
  /// 结束当前的NFC会话，释放NFC资源。
  ///
  /// [alertMessage] 成功时的提示消息（可选）
  /// [errorMessage] 失败时的错误消息（可选）
  Future<void> stopSession({String? alertMessage, String? errorMessage}) async {
    try {
      await NfcManager.instance.stopSession(
        alertMessage: alertMessage,
        errorMessage: errorMessage,
      );
    } catch (_) {}
    _isWriting = false;
  }

  /// 格式化NFC写入内容
  ///
  /// 去除内容两端的空白字符，检查内容是否为空。
  ///
  /// [value] 原始内容
  /// 返回格式化后的内容，如果为空则返回 `null`
  String? _formatPayload(String value) {
    final payload = value.trim();
    if (payload.isEmpty) return null;
    return payload;
  }
}
