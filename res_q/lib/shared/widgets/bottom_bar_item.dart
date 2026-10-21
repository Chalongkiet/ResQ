import 'package:flutter/material.dart';

class BottomBarItem extends StatelessWidget {
  const BottomBarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.activeIcon,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = isActive
        ? theme.colorScheme.secondary
        : theme.colorScheme.onSurface;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 70,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon ?? icon : icon,
                color: color,
                size: 26,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
