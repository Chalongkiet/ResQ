import 'package:flutter/material.dart';

class EmergencyInfoSectionTitle extends StatelessWidget {
  const EmergencyInfoSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
