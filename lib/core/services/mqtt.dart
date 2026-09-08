import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  late MqttServerClient client;

  /// 初始化并连接 MQTT Broker
  Future<bool> connect(String server, String clientId) async {
    client = MqttServerClient(server, clientId);

    // 基础配置
    client.port = 1883; // 默认 TCP 端口
    client.keepAlivePeriod = 20; // 心跳周期
    client.logging(on: false); // 是否开启底层日志

    // 连接回调配置
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean() // 建立全新会话
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMessage;

    try {
      await client.connect();
    } catch (e) {
      debugPrint('MQTT 连接异常: $e');
      client.disconnect();
      return false;
    }

    return client.connectionStatus!.state == MqttConnectionState.connected;
  }

  /// 发送轻量级 JSON 消息 (含自定义 value 字段)
  void publishJsonMessage({
    required String topic,
    required dynamic customValue,
  }) {
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('发送失败: MQTT 未连接');
      return;
    }

    // 1. 构建轻量级 JSON Payload
    final Map<String, dynamic> payloadMap = {
      'value': customValue, // 你的自定义 value 字段
    };

    final String jsonString = jsonEncode(payloadMap);

    // 2. 转换为 MQTT 要求的字节流
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonString);

    // 3. 发布消息 (此处 QoS 设为 1: atLeastOnce)
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

    debugPrint('消息已发送至主题 $topic: $jsonString');
  }

  /// 断开连接
  void disconnect() {
    client.disconnect();
  }

  void _onConnected() {
    debugPrint('MQTT 连接成功');
  }

  void _onDisconnected() {
    debugPrint('MQTT 连接已断开');
  }
}
