import 'package:flutter/material.dart';

import '../../../core/geo/distance_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/disaster_colors.dart';
import '../../../core/theme/disaster_icons.dart';
import '../../../data/models/disaster_event_model.dart';

class DisasterAlertCard extends StatelessWidget {
  const DisasterAlertCard({
    super.key,
    required this.event,
    required this.distanceMeters,
    required this.isInside,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
    this.showJoinButton = false,
    this.isJoined = false,
    this.isJoinChecking = false,
    this.onJoin,
  });

  final DisasterEvent event;

  final double distanceMeters;

  final bool isInside;

  final bool isSelected;

  final bool enabled;

  final VoidCallback onTap;

  // ==================================================
  // Rescue Team Join
  // ==================================================

  /// Citizen ไม่ส่งค่านี้
  /// จึงไม่แสดงปุ่ม Join
  final bool showJoinButton;

  /// true เมื่อ Rescue Team มี ACTIVE Deployment
  /// ใน Disaster Event นี้อยู่แล้ว
  final bool isJoined;

  /// true ระหว่างตรวจสอบสถานะ Join
  /// หรือระหว่างกำลังเปิดกระบวนการ Join
  final bool isJoinChecking;

  /// Parent ของ View Disaster Event
  /// เป็นผู้จัดการ Join logic
  final VoidCallback? onJoin;

  // ==================================================
  // Build
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final disasterColor = DisasterColors.colorFor(event.disasterType);

    final disasterIcon = DisasterIcons.iconFor(event.disasterType);

    final cardColor = theme.colorScheme.surface;

    final primaryTextColor = theme.colorScheme.onSurface;

    final secondaryTextColor = theme.colorScheme.onSurface.withValues(
      alpha: 0.68,
    );

    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),

        // ==================================================
        // Border
        // ==================================================
        border: Border.all(
          color: disasterColor.withValues(alpha: isSelected ? 1 : 0.65),
          width: isSelected ? 2.2 : 1.2,
        ),

        // ==================================================
        // Shadow
        // ==================================================
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.22 : 0.08,
            ),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ==================================================
                // Disaster Color Bar
                // ==================================================
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: disasterColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),

                // ==================================================
                // Content
                // ==================================================
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ==================================================
                        // Disaster Type Icon
                        // ==================================================
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: disasterColor.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.20
                                  : 0.10,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            disasterIcon,
                            color: disasterColor,
                            size: 21,
                          ),
                        ),

                        const SizedBox(width: 10),

                        // ==================================================
                        // Event Detail
                        // ==================================================
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ==============================================
                              // Event name + Distance
                              // ==============================================
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      event.eventName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // ==========================================
                                  // Distance
                                  // ==========================================
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: disasterColor.withValues(
                                        alpha:
                                            theme.brightness == Brightness.dark
                                            ? 0.18
                                            : 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isInside
                                              ? Icons.warning_rounded
                                              : Icons.near_me_rounded,
                                          size: 13,
                                          color: disasterColor,
                                        ),

                                        const SizedBox(width: 4),

                                        Text(
                                          isInside
                                              ? 'ในพื้นที่'
                                              : DistanceFormatter.format(
                                                  distanceMeters,
                                                  isInside: false,
                                                ),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: disasterColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              // ==============================================
                              // Disaster Type
                              // ==============================================
                              Text(
                                event.disasterType,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: disasterColor,
                                ),
                              ),

                              const SizedBox(height: 4),

                              // ==============================================
                              // Area
                              // ==============================================
                              Text(
                                event.areaDescription,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.25,
                                  color: secondaryTextColor,
                                ),
                              ),

                              const SizedBox(height: 6),

                              // ==============================================
                              // Date + Join
                              // ==============================================
                              Row(
                                children: [
                                  // ==========================================
                                  // Date
                                  // ==========================================
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.schedule_rounded,
                                          size: 14,
                                          color: secondaryTextColor,
                                        ),

                                        const SizedBox(width: 4),

                                        Expanded(
                                          child: Text(
                                            _formatDateTime(
                                              event.eventStartDate,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: secondaryTextColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ==========================================
                                  // Rescue Team Join
                                  // ==========================================
                                  if (showJoinButton) ...[
                                    const SizedBox(width: 8),

                                    _buildJoinButton(
                                      disasterColor: disasterColor,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================================================
  // Join Button
  // ==================================================

  Widget _buildJoinButton({required Color disasterColor}) {
    // ==================================================
    // Already Joined
    // ==================================================

    if (isJoined) {
      return FilledButton.icon(
        onPressed: null,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: AppColors.success,
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        icon: const Icon(Icons.check_circle_rounded, size: 16),
        label: const Text(
          'เข้าร่วมแล้ว',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );
    }

    // ==================================================
    // Checking
    // ==================================================

    if (isJoinChecking) {
      return FilledButton.icon(
        onPressed: null,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: disasterColor.withValues(alpha: 0.7),
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        icon: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        label: const Text(
          'กำลังตรวจสอบ...',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );
    }

    // ==================================================
    // Join
    // ==================================================

    return FilledButton.icon(
      onPressed: enabled && onJoin != null ? onJoin : null,
      style: FilledButton.styleFrom(
        backgroundColor: disasterColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        elevation: 3,
        shadowColor: disasterColor.withValues(alpha: 0.45),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.38), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      icon: const Icon(Icons.group_add_rounded, size: 16),
      label: const Text(
        'เข้าร่วมภัยพิบัติ',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ==================================================
  // Date Format
  // ==================================================

  String _formatDateTime(DateTime dateTime) {
    final date = dateTime.toLocal();

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/'
        '${date.year} '
        '${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)} น.';
  }
}
