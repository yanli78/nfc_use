import 'package:flutter/material.dart';
import 'package:nfc_use/core/services/nfc_service.dart';
import 'package:nfc_use/pages/Setting/setting_item.dart';

/// 设置页面组件
///
/// 提供应用的系统设置功能，包括：
/// - NFC硬件状态检测和卡模拟控制
/// - 数据管理（查看卡片数量、清空数据）
/// - 应用信息展示
///
/// 引用的组件：
/// - [StatusTile] - 状态显示列表项（来自 setting_item.dart）
/// - [SwitchTile] - 开关控制列表项（来自 setting_item.dart）
/// - [ActionTile] - 操作触发列表项（来自 setting_item.dart）
/// - [InfoTile] - 信息展示列表项（来自 setting_item.dart）
/// - [SettingGroup] - 设置分组容器（来自 setting_item.dart）
///
/// 依赖的服务：
/// - [NfcService] - NFC服务（来自 nfc_service.dart）
class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

/// 设置页面状态类
///
/// 管理NFC状态、HCE模拟状态等内部状态，处理用户交互逻辑。
class _SettingPageState extends State<SettingPage> {
  /// NFC设备是否可用
  bool _nfcAvailable = false;

  /// 是否正在进行NFC卡模拟
  bool _isEmulating = false;

  /// 是否正在加载NFC状态
  bool _isLoadingNfc = true;

  @override
  void initState() {
    super.initState();
    // 页面初始化时刷新NFC状态
    _refreshNfcState();
  }

  /// 刷新NFC状态信息
  ///
  /// 异步检测NFC设备可用性和当前卡模拟状态，
  /// 更新页面UI以反映最新状态。
  Future<void> _refreshNfcState() async {
    setState(() => _isLoadingNfc = true);
    try {
      final available = await NfcService.instance.isNfcAvailable();
      if (!mounted) return;
      setState(() {
        _nfcAvailable = available;
        _isEmulating = NfcService.instance.isEmulating;
        _isLoadingNfc = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingNfc = false);
    }
  }

  /// 切换HCE卡模拟状态
  ///
  /// 如果当前正在模拟，则停止模拟；否则启动模拟。
  /// 操作完成后显示结果提示并刷新状态。
  void _toggleHce() async {
    if (_isEmulating) {
      // 停止卡模拟
      final result = await NfcService.instance.stopHce();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    } else {
      // 启动卡模拟，使用固定内容 'nfc_use_setting_hce'
      final result = await NfcService.instance.startHce(
        'nfc_use_setting_hce',
        mimeType: 'text/plain',
        persistMessage: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    }
    // 刷新NFC状态以更新UI
    _refreshNfcState();
  }

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
            _buildNfcGroup(),
            const SizedBox(height: 24),
            _buildDataGroup(),
            const SizedBox(height: 24),
            _buildAboutGroup(),
          ],
        ),
      ),
    );
  }

  /// 构建页面头部区域
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

  /// 构建NFC设置分组
  ///
  /// 包含NFC硬件状态显示、HCE开关和停止卡模拟操作。
  Widget _buildNfcGroup() {
    return SettingGroup(
      title: 'NFC',
      children: [
        StatusTile(
          icon: Icons.nfc,
          title: 'NFC硬件状态',
          subtitle: _isLoadingNfc
              ? '检测中...'
              : (_nfcAvailable ? '可用' : '当前设备不支持或未开启'),
          trailing: _isLoadingNfc
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _nfcAvailable ? Icons.check_circle : Icons.error_outline,
                  color: _nfcAvailable ? const Color(0xFF00966A) : Colors.grey,
                ),
        ),
        SwitchTile(
          icon: Icons.wifi_tethering,
          title: '开启卡模拟（HCE）',
          subtitle: '让PN532等读卡器可读取手机数据',
          value: _isEmulating,
          onChanged: _nfcAvailable && !_isLoadingNfc
              ? (_) => _toggleHce()
              : null,
        ),
        ActionTile(
          icon: Icons.phonelink_erase,
          title: '停止卡模拟',
          subtitle: '关闭当前运行的卡模拟会话',
          onTap: _isEmulating && _nfcAvailable ? _toggleHce : null,
        ),
      ],
    );
  }

  /// 构建数据管理分组
  ///
  /// 包含查看卡片数量和清空全部卡片操作。
  Widget _buildDataGroup() {
    return SettingGroup(
      title: '数据管理',
      children: [
        ActionTile(
          icon: Icons.inventory_2,
          title: '查看卡片数量',
          subtitle: '查看本地数据库中保存的卡片数',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('稍后接入 SQLiteService.getCardCount()'),
              ),
            );
          },
        ),
        ActionTile(
          icon: Icons.delete_sweep,
          title: '清空全部卡片',
          subtitle: '删除本地数据库中所有卡片，操作不可撤销',
          onTap: () => _showConfirmDialog(
            '确认清空全部卡片？',
            '将删除本地数据库中的所有卡片数据。',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('稍后接入 SQLiteService.deleteAllCards()'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建关于分组
  ///
  /// 包含应用名称、支持的卡片类型和版本信息。
  Widget _buildAboutGroup() {
    return SettingGroup(
      title: '关于',
      children: const [
        InfoTile(
          icon: Icons.info,
          title: '应用名称',
          subtitle: '数字钱包',
        ),
        InfoTile(
          icon: Icons.tag,
          title: '支持的卡片类型',
          subtitle: 'NFC NDEF / HCE',
        ),
        InfoTile(
          icon: Icons.description,
          title: '版本',
          subtitle: '1.0.0',
        ),
      ],
    );
  }

  /// 显示确认对话框
  ///
  /// [title] 对话框标题
  /// [message] 对话框内容
  /// [onConfirm] 确认后的回调函数
  Future<void> _showConfirmDialog(
    String title,
    String message,
    VoidCallback onConfirm,
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
    if (confirmed == true) {
      onConfirm();
    }
  }
}
