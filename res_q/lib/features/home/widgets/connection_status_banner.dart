import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({
    super.key,
    required this.isOffline,
    required this.showOnline,
  });

  final bool isOffline;
  final bool showOnline;

  @override
  Widget build(BuildContext context) {
    if (!isOffline && !showOnline) {
      return const SizedBox.shrink();
    }

    final isShowingOffline = isOffline;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isShowingOffline ? AppColors.warning : AppColors.success,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                blurRadius: 6,
                offset: Offset(0, 2),
                color: Color(0x33000000),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isShowingOffline
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_done_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isShowingOffline
                      ? 'ออฟไลน์ — กำลังแสดงข้อมูลล่าสุด'
                      : 'กลับมาออนไลน์แล้ว',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
