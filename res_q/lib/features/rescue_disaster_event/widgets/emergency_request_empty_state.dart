import 'package:flutter/material.dart';

class EmergencyRequestEmptyState extends StatelessWidget {
  const EmergencyRequestEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emergency_outlined,
              size: 38,
              color: theme.colorScheme.onSurfaceVariant,
            ),

            const SizedBox(height: 12),

            Text(
              'ไม่มีรายการขอความช่วยเหลือในขณะนี้',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
