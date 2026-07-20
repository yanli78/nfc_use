import 'dart:async';

import 'package:flutter/services.dart';
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

  static const String _channelName = 'com.nfc.hce/command';
  static const MethodChannel _channel = MethodChannel(_channelName);

  /// 当前是否正在进行NFC卡模拟
  bool _isEmulating = false;

  /// 当前是否正在写入物理NFC标签
  bool _isWriting = false;

  /// 检查NFC设备是否可用
  ///
  /// 返回 `true` 表示设备支持NFC且已开启，`false` 表示不支持或未开启。
  Future<bool> isNfcAvailable() async {
    try {
      final bool result = await _channel.invokeMethod('isNfcEnabled');
      return result;
    } catch (_) {
      return NfcManager.instance.isAvailable();
    }
  }

  /// 检查HCE是否可用
  ///
  /// 返回 `true` 表示设备支持HCE主机卡模拟功能。
  Future<bool> isHceSupported() async {
    try {
      final bool result = await _channel.invokeMethod('isHceSupported');
      return result;
    } catch (_) {
      return false;
    }
  }

  /// 检查当前 HCE 服务是否为系统默认服务
  ///
  /// 返回 `true` 表示本应用的 HCE 服务已被设为默认（AID 路由正确）。
  Future<bool> isDefaultService() async {
    try {
      final bool result = await _channel.invokeMethod('isDefaultService');
      return result;
    } catch (_) {
      return false;
    }
  }

  /// 检查NFC权限和状态
  ///
  /// 综合检测NFC设备是否可用、HCE是否支持。
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

      final isHceOk = await isHceSupported();
      if (!isHceOk) {
        return NfcWriteResult(
          status: NfcWriteStatus.hceUnsupported,
          message: kNfcHceUnsupportedMessage,
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

  /// 启用或禁用 HCE 模拟响应
  ///
  /// 启用后，当读卡器发送 SELECT AID (F0010203040506) 指令时，
  /// 手机会返回 "FlutterAuto" 字符串 + 9000 状态码。
  /// 禁用后，SELECT AID 返回 6A82（文件未找到）。
  ///
  /// [enabled] 是否启用模拟响应
  /// 返回包含操作结果的 [NfcWriteResult] 对象
  Future<NfcWriteResult> setEmulationEnabled(
    bool enabled, {
    String token = "FlutterAuto",
  }) async {
    try {
      final isNfcEnabled = await isNfcAvailable();
      if (!isNfcEnabled) {
        return NfcWriteResult(
          status: NfcWriteStatus.unavailable,
          message: kNfcNotEnabledMessage,
        );
      }

      final isHceOk = await isHceSupported();
      if (!isHceOk) {
        return NfcWriteResult(
          status: NfcWriteStatus.hceUnsupported,
          message: kNfcHceUnsupportedMessage,
        );
      }

      // 【修改点】：在这里把 token 传给 Android 原生层
      await _channel.invokeMethod('enableEmulation', {
        'enabled': enabled,
        'token': token,
      });
      _isEmulating = enabled;

      return NfcWriteResult(
        status: NfcWriteStatus.success,
        message: enabled
            ? kNfcHceStartSuccessMessage
            : kNfcHceStopSuccessMessage,
      );
    } catch (error) {
      return NfcWriteResult(
        status: NfcWriteStatus.hceStartFailed,
        message: error.toString(),
        error: error,
      );
    }
  }

  /// 检查当前是否已启用 HCE 模拟响应
  Future<bool> isEmulationEnabled() async {
    try {
      final bool result = await _channel.invokeMethod('isEmulationEnabled');
      return result;
    } catch (_) {
      return false;
    }
  }

  /// 写入卡片ID到NFC（启用 HCE 模拟响应）
  ///
  /// 启用 HCE 模拟，当读卡器发送 SELECT AID 时返回 "FlutterAuto"。
  ///
  /// [card] 卡片数据对象（兼容参数，此实现不依赖卡片ID）
  /// 返回包含操作结果的 [NfcWriteResult] 对象
  Future<NfcWriteResult> writeCardId(CardItem card) {
    // 【修改点】：传入卡片 ID
    return setEmulationEnabled(true, token: card.id);
  }

  /// 使用 HCE 模拟，支持PN532模块读取
  ///
  /// 启用 HCE 模拟响应，PN532 通过 SELECT AID 指令获取 "FlutterAuto" 字符串。
  ///
  /// [card] 卡片数据对象（兼容参数）
  /// [persistMessage] 兼容参数，此实现中始终启用
  /// 返回包含操作结果的 [NfcWriteResult] 对象
  Future<NfcWriteResult> emulateCardIdForPn532(
    CardItem card, {
    bool persistMessage = true,
  }) {
    // 【修改点】：传入卡片 ID
    return setEmulationEnabled(true, token: card.id);
  }

  /// 启动 HCE 模拟（兼容旧接口）
  Future<NfcWriteResult> startHce(
    String value, {
    String mimeType = 'text/plain',
    bool persistMessage = true,
  }) {
    // 【修改点】：传入自定义 value
    return setEmulationEnabled(true, token: value);
  }

  /// 停止 HCE 模拟（禁用响应）
  Future<NfcWriteResult> stopHce() {
    return setEmulationEnabled(false);
  }

  /// 获取当前是否正在进行NFC卡模拟
  bool get isEmulating => _isEmulating;

  /// 打开系统NFC设置页面
  Future<void> openNfcSettings() async {
    try {
      await _channel.invokeMethod('openNfcSettings');
    } catch (_) {}
  }

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
