import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/emergency_request_model.dart';

class EmergencyRequestCard extends StatelessWidget {
  const EmergencyRequestCard({
    super.key,
    required this.request,
    required this.distanceMeters,
    required this.onTap,
  });

  final EmergencyRequest request;

  final double distanceMeters;

  final VoidCallback onTap;

  // ==================================================
  // Build
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 7),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
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
                    // ----------------------------------------------
                    // SOS Badge
                    // ----------------------------------------------
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightEmergencyContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sos_rounded,
                            size: 16,
                            color: AppColors.emergency,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'EMERGENCY SOS',
                            style: TextStyle(
                              color: AppColors.emergency,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // ----------------------------------------------
                    // Time
                    // ----------------------------------------------
                    Text(
                      _formatDateTime(request.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 11),

                // ==================================================
                // Request Type
                // ==================================================
                Text(
                  request.requestType.trim().isEmpty
                      ? 'เหตุฉุกเฉิน'
                      : request.requestType.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    const Icon(
                      Icons.groups_2_outlined,
                      size: 18,
                      color: AppColors.emergency,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ผู้ประสบภัย ${request.affectedCount} คน',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.emergencyDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // ==================================================
                // Detail
                // ==================================================
                Text(
                  request.requestDetail.trim().isEmpty
                      ? 'ไม่มีรายละเอียดเพิ่มเติม'
                      : request.requestDetail.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 13),

                Divider(height: 1, color: theme.colorScheme.outlineVariant),

                const SizedBox(height: 12),

                // ==================================================
                // Distance + Arrow
                // ==================================================
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 19,
                      color: theme.colorScheme.primary,
                    ),

                    const SizedBox(width: 6),

                    Expanded(
                      child: Text(
                        'ห่าง ${_formatDistance(distanceMeters)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================================================
  // Distance
  // ==================================================

  static String _formatDistance(double meters) {
    if (!meters.isFinite || meters < 0) {
      return '-';
    }

    if (meters < 1000) {
      return '${meters.round()} เมตร';
    }

    final kilometers = meters / 1000;

    if (kilometers < 10) {
      return '${kilometers.toStringAsFixed(1)} กิโลเมตร';
    }

    return '${kilometers.round()} กิโลเมตร';
  }

  // ==================================================
  // Date / Time
  // ==================================================

  static String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return '-';
    }

    final day = dateTime.day.toString().padLeft(2, '0');

    final month = dateTime.month.toString().padLeft(2, '0');

    final hour = dateTime.hour.toString().padLeft(2, '0');

    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month $hour:$minute';
  }
}
