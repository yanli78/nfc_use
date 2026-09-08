import 'package:flutter/material.dart';
import 'package:nfc_use/core/services/card_import_service.dart';
import 'package:nfc_use/core/services/nfc_service.dart';
import 'package:nfc_use/core/services/sqlite_service.dart';
import 'package:nfc_use/core/services/zip.dart';
import 'package:nfc_use/pages/Setting/setting_item.dart';

// File path: lib/pages/Setting/index.dart
// 设置页面：发送方式切换（NFC 自动启用 HCE / MQTT，可扩展）
class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  // ====== 发送方式（可扩展：在 SendMode 枚举新增后，这里加选项即可） ======
  SendMode _sendMode = SendMode.nfc;

  final List<_ModeOption> _modeOptions = const [
    _ModeOption(
      mode: SendMode.nfc,
      title: 'NFC 近场通信',
      subtitle: '手机靠近 NFC 读卡器，自动开启卡模拟',
      icon: Icons.nfc,
    ),
    _ModeOption(
      mode: SendMode.mqtt,
      title: 'MQTT 消息总线',
      subtitle: '通过局域网 MQTT Broker 发送',
      icon: Icons.wifi,
    ),
  ];

  // ====== NFC 综合状态 ======
  bool _nfcHardwareAvailable = false;
  bool _hceSupported = false;
  bool _isDefaultService = false;
  bool _isEmulating = false;
  bool _isLoadingNfc = true;
  bool _isImportingCards = false;

  // ====== MQTT 配置 ======
  late TextEditingController _mqttServerCtrl;
  late TextEditingController _mqttPortCtrl;
  late TextEditingController _mqttClientIdCtrl;
  late TextEditingController _mqttTopicCtrl;
  late TextEditingController _mqttUsernameCtrl;
  late TextEditingController _mqttPasswordCtrl;
  bool _mqttUseAuth = false;
  MqttConnectionStatus _mqttStatus = MqttConnectionStatus.disconnected;

  // ====== 生命周期 ======
  @override
  void initState() {
    super.initState();
    final cfg = NfcService.instance.mqttConfig;
    _mqttServerCtrl = TextEditingController(text: cfg.server);
    _mqttPortCtrl = TextEditingController(text: cfg.port.toString());
    _mqttClientIdCtrl = TextEditingController(text: cfg.clientId);
    _mqttTopicCtrl = TextEditingController(text: cfg.topic);
    _mqttUsernameCtrl = TextEditingController(text: cfg.username);
    _mqttPasswordCtrl = TextEditingController(text: cfg.password);
    _mqttUseAuth = cfg.useAuth;
    _sendMode = NfcService.instance.sendMode;
    _mqttStatus = NfcService.instance.mqttStatus;

    NfcService.instance.setListeners(
      onModeChanged: (mode) {
        if (!mounted) return;
        setState(() => _sendMode = mode);
      },
      onMqttStatusChanged: (status) {
        if (!mounted) return;
        setState(() => _mqttStatus = status);
      },
    );

    _refreshNfcState();
  }

  @override
  void dispose() {
    NfcService.instance.clearListeners();
    _mqttServerCtrl.dispose();
    _mqttPortCtrl.dispose();
    _mqttClientIdCtrl.dispose();
    _mqttTopicCtrl.dispose();
    _mqttUsernameCtrl.dispose();
    _mqttPasswordCtrl.dispose();
    super.dispose();
  }

  // ====== NFC 综合检测（硬件 + HCE 支持 + 默认服务 + 当前模拟状态） ======
  Future<void> _refreshNfcState() async {
    setState(() => _isLoadingNfc = true);
    try {
      final hw = await NfcService.instance.isNfcAvailable();
      final hce = await NfcService.instance.isHceSupported();
      final def = await NfcService.instance.isDefaultService();
      final emu = NfcService.instance.isEmulating;
      if (!mounted) return;
      setState(() {
        _nfcHardwareAvailable = hw;
        _hceSupported = hce;
        _isDefaultService = def;
        _isEmulating = emu;
        _isLoadingNfc = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingNfc = false);
    }
  }

  /// NFC 功能综合正常：硬件可用 + HCE 支持
  bool get _nfcFunctionalOk => _nfcHardwareAvailable && _hceSupported;

  String get _nfcStatusText {
    if (_isLoadingNfc) return '检测中...';
    if (!_nfcHardwareAvailable) return 'NFC 硬件不可用（未开启或不支持）';
    if (!_hceSupported) return '设备不支持 HCE 卡模拟';
    if (_isEmulating) return '功能正常（卡模拟已启用）';
    if (_sendMode == SendMode.nfc) return '功能正常（待机中）';
    if (!_isDefaultService) return '功能可用，但未设为默认 HCE 服务';
    return '功能正常';
  }

  Color get _nfcStatusColor {
    if (_isLoadingNfc) return Colors.grey;
    if (!_nfcHardwareAvailable || !_hceSupported) return Colors.redAccent;
    if (_isEmulating) return const Color(0xFF00966A);
    if (_sendMode == SendMode.nfc) return Colors.orange;
    return Colors.orange;
  }

  IconData get _nfcStatusIcon {
    if (_isLoadingNfc) return Icons.hourglass_top;
    if (!_nfcHardwareAvailable || !_hceSupported) return Icons.error_outline;
    if (_isEmulating) return Icons.check_circle;
    return Icons.info_outline;
  }

  // ====== 发送方式切换：切到 NFC 自动开启 HCE，切离自动关闭 ======
  Future<void> _switchMode(SendMode mode) async {
    if (_sendMode == mode) return;

    // 先切模式（NfcService.setSendMode 会在切离 NFC 时自动关闭 HCE）
    await NfcService.instance.setSendMode(mode);
    if (!mounted) return;
    setState(() => _sendMode = mode);

    if (mode == SendMode.nfc) {
      // 切到 NFC 模式，自动启用 HCE
      final r = await NfcService.instance.setEmulationEnabled(true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(r.message)));
      }
    }

    _refreshNfcState();
  }

  // ====== MQTT ======
  void _applyMqttConfig() {
    final port = int.tryParse(_mqttPortCtrl.text.trim()) ?? 1883;
    final cfg = MqttConfig(
      server: _mqttServerCtrl.text.trim(),
      port: port,
      clientId: _mqttClientIdCtrl.text.trim().isEmpty
          ? 'nfc_use_app'
          : _mqttClientIdCtrl.text.trim(),
      topic: _mqttTopicCtrl.text.trim().isEmpty
          ? 'nfc_use/send'
          : _mqttTopicCtrl.text.trim(),
      username: _mqttUsernameCtrl.text,
      password: _mqttPasswordCtrl.text,
      useAuth: _mqttUseAuth,
    );
    NfcService.instance.setMqttConfig(cfg);
  }

  Future<void> _connectMqtt() async {
    _applyMqttConfig();
    if (_mqttStatus == MqttConnectionStatus.connected) {
      final r = await NfcService.instance.disconnectMqtt();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(r.message)));
      }
      return;
    }
    final r = await NfcService.instance.connectMqtt();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(r.message)));
    }
  }

  String get _mqttStatusText {
    switch (_mqttStatus) {
      case MqttConnectionStatus.disconnected:
        return '未连接';
      case MqttConnectionStatus.connecting:
        return '连接中...';
      case MqttConnectionStatus.connected:
        return '已连接';
      case MqttConnectionStatus.failed:
        return '连接失败';
    }
  }

  Color get _mqttStatusColor {
    switch (_mqttStatus) {
      case MqttConnectionStatus.connected:
        return const Color(0xFF00966A);
      case MqttConnectionStatus.connecting:
        return Colors.orange;
      case MqttConnectionStatus.failed:
        return Colors.redAccent;
      case MqttConnectionStatus.disconnected:
        return Colors.grey;
    }
  }

  Future<void> _importCardsFromZip() async {
    if (_isImportingCards) return;

    setState(() => _isImportingCards = true);
    try {
      final zipPath = await ZipService.instance.pickZipFile();
      if (zipPath == null) return;

      final result = await CardImportService.instance.importFromZip(zipPath);
      if (!mounted) return;

      final extra = result.warnings.isEmpty
          ? ''
          : '，${result.warnings.take(2).join('；')}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${result.message}$extra')));
    } on ZipException catch (error) {
      if (!mounted || error.type == ZipErrorType.canceled) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败：$error')));
    } finally {
      if (mounted) setState(() => _isImportingCards = false);
    }
  }

  Future<void> _showCardCount() async {
    final count = await CardDatabaseHelper.instance.getCardCount();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('本地已保存 $count 张卡片')));
  }

  Future<void> _clearCards() async {
    await CardDatabaseHelper.instance.deleteAllCards();
    await CardImportService.instance.clearImportedAssets();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清空全部卡片')));
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSendModeGroup(),
            const SizedBox(height: 24),
            if (_sendMode == SendMode.nfc) _buildNfcGroup(),
            if (_sendMode == SendMode.mqtt) _buildMqttGroup(),
            const SizedBox(height: 24),
            _buildDataGroup(),
            const SizedBox(height: 24),
            _buildAboutGroup(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '设置',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  // ---- 发送方式分组 ----
  Widget _buildSendModeGroup() {
    return SettingGroup(
      title: '发送方式',
      children: [
        for (int i = 0; i < _modeOptions.length; i++) ...[
          _buildModeOption(_modeOptions[i]),
          if (i != _modeOptions.length - 1)
            const Padding(
              padding: EdgeInsets.only(left: 56),
              child: Divider(height: 1, thickness: 1),
            ),
        ],
      ],
    );
  }

  Widget _buildModeOption(_ModeOption opt) {
    final selected = _sendMode == opt.mode;
    return InkWell(
      onTap: () => _switchMode(opt.mode),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF00966A).withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                opt.icon,
                color: selected ? const Color(0xFF00966A) : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opt.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    opt.subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF00966A)
                      : Colors.grey.shade400,
                  width: 2,
                ),
                color: selected ? const Color(0xFF00966A) : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ---- NFC 分组（不再有手动开关，切到 NFC 自动启用 HCE） ----
  Widget _buildNfcGroup() {
    return SettingGroup(
      title: 'NFC 功能状态',
      children: [
        StatusTile(
          icon: Icons.nfc,
          title: '功能状态',
          subtitle: _nfcStatusText,
          trailing: _isLoadingNfc
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_nfcStatusIcon, color: _nfcStatusColor),
        ),
        StatusTile(
          icon: Icons.smartphone,
          title: 'NFC 硬件',
          subtitle: _nfcHardwareAvailable ? '可用' : '不可用',
          trailing: Icon(
            _nfcHardwareAvailable ? Icons.check : Icons.close,
            color: _nfcHardwareAvailable
                ? const Color(0xFF00966A)
                : Colors.redAccent,
          ),
        ),
        StatusTile(
          icon: Icons.contactless,
          title: 'HCE 支持',
          subtitle: _hceSupported ? '支持' : '不支持',
          trailing: Icon(
            _hceSupported ? Icons.check : Icons.close,
            color: _hceSupported ? const Color(0xFF00966A) : Colors.redAccent,
          ),
        ),
        StatusTile(
          icon: Icons.touch_app,
          title: '卡模拟当前状态',
          subtitle: _isEmulating ? '已启用' : '未启用',
          trailing: Icon(
            _isEmulating ? Icons.play_circle : Icons.pause_circle,
            color: _isEmulating ? const Color(0xFF00966A) : Colors.grey,
          ),
        ),
        ActionTile(
          icon: Icons.restart_alt,
          title: '重新检测并启动卡模拟',
          subtitle: '手动重试 HCE 初始化与启用',
          onTap: () async {
            await _refreshNfcState();
            if (_nfcFunctionalOk && mounted) {
              final r = await NfcService.instance.setEmulationEnabled(true);
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(r.message)));
              }
              _refreshNfcState();
            } else if (!_nfcFunctionalOk && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('NFC 硬件或 HCE 不可用，无法启动')),
              );
            }
          },
        ),
        ActionTile(
          icon: Icons.settings,
          title: '打开系统 NFC 设置',
          subtitle: '前往系统设置开启 NFC 或配置默认付款应用',
          onTap: () async {
            try {
              await NfcService.instance.openNfcSettings();
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('无法打开系统设置')));
              }
            }
          },
        ),
      ],
    );
  }

  // ---- MQTT 分组 ----
  Widget _buildMqttGroup() {
    return SettingGroup(
      title: 'MQTT 配置',
      children: [
        StatusTile(
          icon: Icons.wifi,
          title: '连接状态',
          subtitle: _mqttStatusText,
          trailing: Icon(
            _mqttStatus == MqttConnectionStatus.connected
                ? Icons.check_circle
                : Icons.circle_outlined,
            color: _mqttStatusColor,
          ),
        ),
        FieldTile(
          icon: Icons.dns,
          title: '服务器',
          initialValue: _mqttServerCtrl.text,
          hintText: '192.168.1.100',
          keyboardType: TextInputType.url,
          onChanged: (v) {
            _mqttServerCtrl.value = _mqttServerCtrl.value.copyWith(text: v);
          },
        ),
        FieldTile(
          icon: Icons.pin,
          title: '端口',
          initialValue: _mqttPortCtrl.text,
          hintText: '1883',
          keyboardType: TextInputType.number,
          onChanged: (v) {
            _mqttPortCtrl.value = _mqttPortCtrl.value.copyWith(text: v);
          },
        ),
        FieldTile(
          icon: Icons.badge,
          title: 'ClientID',
          initialValue: _mqttClientIdCtrl.text,
          hintText: 'nfc_use_app',
          onChanged: (v) {
            _mqttClientIdCtrl.value = _mqttClientIdCtrl.value.copyWith(text: v);
          },
        ),
        FieldTile(
          icon: Icons.label,
          title: '主题',
          initialValue: _mqttTopicCtrl.text,
          hintText: 'nfc_use/send',
          onChanged: (v) {
            _mqttTopicCtrl.value = _mqttTopicCtrl.value.copyWith(text: v);
          },
        ),
        SwitchTile(
          icon: Icons.lock,
          title: '启用用户名密码',
          subtitle: 'Broker 需要认证时开启',
          value: _mqttUseAuth,
          onChanged: (v) {
            setState(() => _mqttUseAuth = v);
            _applyMqttConfig();
          },
        ),
        if (_mqttUseAuth)
          FieldTile(
            icon: Icons.person,
            title: '用户名',
            initialValue: _mqttUsernameCtrl.text,
            hintText: 'username',
            onChanged: (v) {
              _mqttUsernameCtrl.value = _mqttUsernameCtrl.value.copyWith(
                text: v,
              );
            },
          ),
        if (_mqttUseAuth)
          FieldTile(
            icon: Icons.password,
            title: '密码',
            initialValue: _mqttPasswordCtrl.text,
            hintText: 'password',
            obscureText: true,
            onChanged: (v) {
              _mqttPasswordCtrl.value = _mqttPasswordCtrl.value.copyWith(
                text: v,
              );
            },
          ),
        ActionTile(
          icon: _mqttStatus == MqttConnectionStatus.connected
              ? Icons.link_off
              : Icons.link,
          title: _mqttStatus == MqttConnectionStatus.connected
              ? '断开连接'
              : (_mqttStatus == MqttConnectionStatus.connecting
                    ? '正在连接...'
                    : '连接 MQTT Broker'),
          subtitle: _mqttStatus == MqttConnectionStatus.connected
              ? '断开当前 MQTT 连接'
              : '使用上方配置连接 Broker',
          onTap: _mqttStatus == MqttConnectionStatus.connecting
              ? null
              : _connectMqtt,
        ),
      ],
    );
  }

  // ---- 数据管理 ----
  Widget _buildDataGroup() {
    return SettingGroup(
      title: '数据管理',
      children: [
        ActionTile(
          icon: Icons.file_upload,
          title: _isImportingCards ? '正在导入...' : '导入卡片压缩包',
          subtitle: '选择包含 config.json 与 resources 图片的 ZIP 文件',
          onTap: _isImportingCards ? null : _importCardsFromZip,
        ),
        ActionTile(
          icon: Icons.inventory_2,
          title: '查看卡片数量',
          subtitle: '查看本地数据库中保存的卡片数',
          onTap: _showCardCount,
        ),
        ActionTile(
          icon: Icons.delete_sweep,
          title: '清空全部卡片',
          subtitle: '删除本地数据库中所有卡片，操作不可撤销',
          onTap: () =>
              _showConfirmDialog('确认清空全部卡片？', '将删除本地数据库中的所有卡片数据。', _clearCards),
        ),
      ],
    );
  }

  // ---- 关于 ----
  Widget _buildAboutGroup() {
    return SettingGroup(
      title: '关于',
      children: const [
        InfoTile(icon: Icons.info, title: '应用名称', subtitle: '数字钱包'),
        InfoTile(
          icon: Icons.tag,
          title: '支持的发送方式',
          subtitle: 'NFC（自动启用 HCE）/ MQTT（可扩展）',
        ),
        InfoTile(icon: Icons.description, title: '版本', subtitle: '1.0.0'),
      ],
    );
  }

  Future<void> _showConfirmDialog(
    String title,
    String message,
    Future<void> Function() onConfirm,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onConfirm();
  }
}

class _ModeOption {
  final SendMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
  const _ModeOption({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
