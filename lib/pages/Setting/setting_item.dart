
import 'package:flutter/material.dart';

/// 设置页面通用组件库
///
/// 提供设置页面所需的各种列表项组件和分组容器组件，
/// 这些组件被 [SettingPage] 引用，用于构建统一风格的设置界面。

/// 基础列表项组件
///
/// 所有设置列表项的基类，提供统一的布局结构：
/// 左侧图标 + 中间标题/副标题 + 右侧尾部组件
///
/// 子类通过继承或组合方式扩展不同的功能：
/// - [StatusTile] - 显示状态信息
/// - [ActionTile] - 触发操作
/// - [SwitchTile] - 开关控制
/// - [InfoTile] - 展示静态信息
class BaseTile extends StatelessWidget {
  /// 左侧图标
  final IconData icon;

  /// 主标题
  final String title;

  /// 副标题（可选）
  final String? subtitle;

  /// 右侧尾部组件（可选）
  final Widget? trailing;

  /// 点击回调（可选）
  final VoidCallback? onTap;

  /// 创建基础列表项
  ///
  /// [icon] 左侧显示的图标
  /// [title] 主标题文本
  /// [subtitle] 副标题文本，用于补充说明
  /// [trailing] 右侧尾部组件，如开关、箭头、状态图标等
  /// [onTap] 点击事件回调，为null时组件呈禁用状态
  const BaseTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _buildIcon(isEnabled),
            const SizedBox(width: 12),
            _buildContent(isEnabled),
            if (trailing case final Widget child) child,
          ],
        ),
      ),
    );
  }

  /// 构建左侧图标区域
  Widget _buildIcon(bool isEnabled) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF00966A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: isEnabled ? const Color(0xFF00966A) : Colors.grey,
      ),
    );
  }

  /// 构建中间内容区域（标题和副标题）
  Widget _buildContent(bool isEnabled) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: isEnabled ? Colors.black87 : Colors.grey,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 状态显示列表项
///
/// 用于展示某个功能或服务的当前状态，
/// 不可点击，右侧显示状态图标或加载动画。
///
/// 使用示例：
/// ```dart
/// StatusTile(
///   icon: Icons.nfc,
///   title: 'NFC硬件状态',
///   subtitle: '可用',
///   trailing: Icon(Icons.check_circle),
/// )
/// ```
class StatusTile extends StatelessWidget {
  /// 左侧图标
  final IconData icon;

  /// 主标题
  final String title;

  /// 状态描述副标题
  final String subtitle;

  /// 右侧状态指示器（可选）
  final Widget? trailing;

  /// 创建状态显示列表项
  ///
  /// [icon] 左侧图标
  /// [title] 状态名称
  /// [subtitle] 状态详细描述
  /// [trailing] 状态图标或加载动画
  const StatusTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return BaseTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}

/// 操作触发列表项
///
/// 用于触发某个操作或导航到其他页面，
/// 可点击，右侧显示箭头图标表示可交互。
///
/// 使用示例：
/// ```dart
/// ActionTile(
///   icon: Icons.delete_sweep,
///   title: '清空全部卡片',
///   subtitle: '删除本地数据库中所有卡片',
///   onTap: () => _showConfirmDialog(...),
/// )
/// ```
class ActionTile extends StatelessWidget {
  /// 左侧图标
  final IconData icon;

  /// 操作名称
  final String title;

  /// 操作描述副标题
  final String subtitle;

  /// 点击回调
  final VoidCallback? onTap;

  /// 创建操作触发列表项
  ///
  /// [icon] 左侧图标
  /// [title] 操作名称
  /// [subtitle] 操作详细描述
  /// [onTap] 点击事件回调，为null时箭头隐藏，呈禁用状态
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BaseTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: Colors.grey)
          : null,
    );
  }
}

/// 开关控制列表项
///
/// 用于控制某个功能的开启/关闭状态，
/// 右侧显示开关组件，点击可切换状态。
///
/// 使用示例：
/// ```dart
/// SwitchTile(
///   icon: Icons.wifi_tethering,
///   title: '开启卡模拟（HCE）',
///   subtitle: '让PN532等读卡器可读取手机数据',
///   value: _isEmulating,
///   onChanged: (value) => _toggleHce(),
/// )
/// ```
class SwitchTile extends StatelessWidget {
  /// 左侧图标
  final IconData icon;

  /// 开关名称
  final String title;

  /// 开关描述副标题
  final String subtitle;

  /// 当前开关状态
  final bool value;

  /// 状态变化回调
  final ValueChanged<bool>? onChanged;

  /// 创建开关控制列表项
  ///
  /// [icon] 左侧图标
  /// [title] 开关名称
  /// [subtitle] 开关功能描述
  /// [value] 当前状态（true为开启）
  /// [onChanged] 状态变化回调，为null时开关禁用
  const SwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BaseTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: const Color(0xFF00966A).withValues(alpha: 0.4),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFF00966A)
              : null,
        ),
      ),
    );
  }
}

/// 信息展示列表项
///
/// 用于展示静态信息，不可点击，无尾部组件。
///
/// 使用示例：
/// ```dart
/// InfoTile(
///   icon: Icons.info,
///   title: '应用名称',
///   subtitle: '数字钱包',
/// )
/// ```
class InfoTile extends StatelessWidget {
  /// 左侧图标
  final IconData icon;

  /// 信息名称
  final String title;

  /// 信息内容
  final String subtitle;

  /// 创建信息展示列表项
  ///
  /// [icon] 左侧图标
  /// [title] 信息名称
  /// [subtitle] 信息具体内容
  const InfoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return BaseTile(icon: icon, title: title, subtitle: subtitle);
  }
}

/// 设置分组容器组件
///
/// 用于将相关的设置项分组展示，
/// 包含分组标题和卡片式背景容器，
/// 内部列表项之间自动添加分隔线。
///
/// 使用示例：
/// ```dart
/// SettingGroup(
///   title: 'NFC',
///   children: [
///     StatusTile(...),
///     SwitchTile(...),
///     ActionTile(...),
///   ],
/// )
/// ```
class SettingGroup extends StatelessWidget {
  /// 分组标题
  final String title;

  /// 分组内的子组件列表
  final List<Widget> children;

  /// 创建设置分组容器
  ///
  /// [title] 分组名称，显示在分组上方
  /// [children] 分组内的列表项组件
  const SettingGroup({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGroupTitle(),
        _buildGroupContent(),
      ],
    );
  }

  /// 构建分组标题
  Widget _buildGroupTitle() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.grey,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 构建分组内容区域
  ///
  /// 包含白色卡片背景和自动分隔线
  Widget _buildGroupContent() {
    return Container(
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
    );
  }
}

/// 文本输入框列表项
///
/// 用于让用户输入配置信息，如服务器地址、端口、主题等。
/// 布局：左侧图标 + 标题 + 右侧 TextField。
class FieldTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? initialValue;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;

  const FieldTile({
    super.key,
    required this.icon,
    required this.title,
    this.initialValue,
    this.hintText = '',
    this.onChanged,
    this.keyboardType,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: initialValue);
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF00966A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF00966A)),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: keyboardType,
              obscureText: obscureText,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF00966A), width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
