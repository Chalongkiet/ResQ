import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/emergency_request_model.dart';

class EmergencyRequestCallout extends StatelessWidget {
  const EmergencyRequestCallout({
    super.key,
    required this.request,
    required this.onClose,
    required this.onViewDetail,
  });

  final EmergencyRequest request;

  final VoidCallback onClose;

  final VoidCallback onViewDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ==================================================
            // Callout
            // ==================================================
            Container(
              width: 220,
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.emergency),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 9,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // Header
                  // ==================================================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 17,
                          color: AppColors.emergency,
                        ),
                      ),

                      const SizedBox(width: 6),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            request.requestType.trim().isEmpty
                                ? 'เหตุฉุกเฉิน'
                                : request.requestType.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                      // ==================================================
                      // Close Callout
                      // ==================================================
                      InkWell(
                        onTap: onClose,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'ผู้ประสบภัย ${request.affectedCount} คน',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.emergencyDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 3),

                  // ==================================================
                  // Description
                  // ==================================================
                  Text(
                    request.requestDetail.trim().isEmpty
                        ? 'ไม่มีรายละเอียดเพิ่มเติม'
                        : request.requestDetail.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // ==================================================
                  // View Detail
                  // ==================================================
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: onViewDetail,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 5,
                        ),
                        child: Text(
                          'ดูรายละเอียด',
                          style: TextStyle(
                            color: AppColors.emergency,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // Pointer
            // ==================================================
            CustomPaint(
              size: const Size(18, 8),
              painter: _CalloutPointerPainter(color: theme.colorScheme.surface),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================
// Pointer
// ==================================================

class _CalloutPointerPainter extends CustomPainter {
  const _CalloutPointerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CalloutPointerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
