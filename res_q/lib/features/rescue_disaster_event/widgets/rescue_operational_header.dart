import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class RescueOperationalHeader extends StatelessWidget {
  const RescueOperationalHeader({
    super.key,
    this.onLeavePressed,
    this.title = 'รายการเหตุฉุกเฉิน',
  });

  final VoidCallback? onLeavePressed;

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // ==================================================
          // Title
          // ==================================================
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // ==================================================
          // Leave Disaster Event
          //
          // LER2 แสดง UI อย่างเดียว
          // Logic จริงทำใน Leave Disaster Event ภายหลัง
          // ==================================================
          if (onLeavePressed != null) ...[
            OutlinedButton(
              onPressed: onLeavePressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'ถอนกำลัง',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // ==================================================
          // ONLINE
          // ==================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.lightSuccessContainer,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.success),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.power_settings_new_rounded,
                  size: 19,
                  color: AppColors.success,
                ),

                const SizedBox(width: 6),

                Text(
                  'ONLINE',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
