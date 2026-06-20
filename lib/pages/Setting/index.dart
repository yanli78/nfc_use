import 'package:flutter/material.dart';
import 'package:nfc_use/core/services/nfc_service.dart';
import 'package:nfc_use/core/constants/setting_item.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _nfcAvailable = false;
  bool _isEmulating = false;
  bool _isLoadingNfc = true;

  @override
  void initState() {
    super.initState();
    _refreshNfcState();
  }

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

  void _toggleHce() async {
    if (_isEmulating) {
      final result = await NfcService.instance.stopHce();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } else {
      final result = await NfcService.instance.startHce(
        'nfc_use_setting_hce',
        mimeType: 'text/plain',
        persistMessage: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
      }
    }
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

  Widget _buildNfcGroup() {
    return _SettingGroup(
      title: 'NFC',
      children: [
        StatusTile(
          icon: Icons.nfc,
          title: 'NFC 硬件状态',
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
          subtitle: '让 PN532 等读卡器可读取手机数据',
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

  Widget _buildDataGroup() {
    return _SettingGroup(
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
          onTap: () => _showConfirmDialog('确认清空全部卡片？', '将删除本地数据库中的所有卡片数据。', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('稍后接入 SQLiteService.deleteAllCards()'),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildAboutGroup() {
    return _SettingGroup(
      title: '关于',
      children: const [
        InfoTile(icon: Icons.info, title: '应用名称', subtitle: '数字钱包'),
        InfoTile(icon: Icons.tag, title: '支持的卡片类型', subtitle: 'NFC NDEF / HCE'),
        InfoTile(icon: Icons.description, title: '版本', subtitle: '1.0.0'),
      ],
    );
  }

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

class _SettingGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 56),
                    child: Divider(height: 1, thickness: 1),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
