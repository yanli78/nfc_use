import 'package:flutter/material.dart';

class BaseTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

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
            Container(
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
            ),
            const SizedBox(width: 12),
            Expanded(
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
            ),
            if (trailing case final Widget child) child,
          ],
        ),
      ),
    );
  }
}

class StatusTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

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

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

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

class SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

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

class InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

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
