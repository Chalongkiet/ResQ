import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

import '../../../../data/models/emergency_info_model.dart';
import '../../../../data/models/emergency_request_model.dart';

import '../../controllers/rescue_emergency_detail_controller.dart';

// ==================================================
// Show
// ==================================================

Future<void> showEmergencyRequestDetailDialog({
  required BuildContext context,
  required EmergencyRequest request,
  required RescueEmergencyDetailController controller,

  // Accept Rescue Mission จะส่ง callback ทีหลัง
  Future<bool> Function()? onAcceptMission,
}) async {
  controller.clear();

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return EmergencyRequestDetailDialog(
        request: request,
        controller: controller,
        onAcceptMission: onAcceptMission,
      );
    },
  );
}

// ==================================================
// Dialog
// ==================================================

class EmergencyRequestDetailDialog extends StatefulWidget {
  const EmergencyRequestDetailDialog({
    super.key,
    required this.request,
    required this.controller,
    this.onAcceptMission,
  });

  final EmergencyRequest request;

  final RescueEmergencyDetailController controller;

  final Future<bool> Function()? onAcceptMission;

  @override
  State<EmergencyRequestDetailDialog> createState() =>
      _EmergencyRequestDetailDialogState();
}

class _EmergencyRequestDetailDialogState
    extends State<EmergencyRequestDetailDialog> {
  bool _isAcceptingMission = false;
  @override
  void initState() {
    super.initState();

    widget.controller.addListener(_handleChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      widget.controller.load(widget.request);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChanged);

    super.dispose();
  }

  void _handleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleAcceptMission() async {
    final callback = widget.onAcceptMission;

    // ไม่มี callback
    // หรือกำลัง Accept อยู่แล้ว
    // ไม่ต้องทำอะไร
    if (callback == null || _isAcceptingMission) {
      return;
    }

    // ==================================================
    // เริ่ม Loading
    // ==================================================

    setState(() {
      _isAcceptingMission = true;
    });

    try {
      // ==================================================
      // เรียก callback จาก Page
      //
      // callback ตัวนี้จะไปทำ:
      // - หา Event
      // - หา Deployment
      // - สร้าง missionName
      // - Firestore Transaction
      // - WAITING -> ACCEPTED
      // - Create RescueMission
      // ==================================================

      final success = await callback();

      if (!mounted) {
        return;
      }

      // ==================================================
      // ถ้าสำเร็จ
      // ปิด Detail Popup
      // ==================================================

      if (success) {
        Navigator.of(context).pop();
      }
    } finally {
      // ==================================================
      // ถ้ายังอยู่บนหน้าจอ
      // หยุด Loading
      // ==================================================

      if (mounted) {
        setState(() {
          _isAcceptingMission = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 50),

      backgroundColor: theme.colorScheme.surface,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

      clipBehavior: Clip.antiAlias,

      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,

          maxHeight: screen.height * 0.82,
        ),

        child: Column(
          children: [
            // ==================================================
            // Header
            // ==================================================
            Container(
              height: 48,

              color: AppColors.primaryDark,

              padding: const EdgeInsets.only(left: 46, right: 8),

              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ข้อมูลผู้ประสบภัย',

                      textAlign: TextAlign.center,

                      style: TextStyle(
                        fontSize: 18,

                        fontWeight: FontWeight.w800,

                        color: Colors.white,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: _isAcceptingMission
                        ? null
                        : () {
                            Navigator.of(context).pop();
                          },

                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // Body
            // ==================================================
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (widget.controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = widget.controller.errorMessage;

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              const Icon(
                Icons.error_outline_rounded,

                size: 42,

                color: AppColors.error,
              ),

              const SizedBox(height: 10),

              Text(error, textAlign: TextAlign.center),

              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: widget.controller.retry,

                child: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
      );
    }

    final info = widget.controller.emergencyInfo;

    if (info == null) {
      return const SizedBox.shrink();
    }

    return _DetailContent(
      request: widget.request,

      info: info,

      previousCancellations: widget.controller.previousCancellations,

      // ส่งสถานะ Loading จาก State ลงไปให้ UI
      isAcceptingMission: _isAcceptingMission,

      // ถ้า Page ไม่ได้ส่ง onAcceptMission มา
      // จะส่ง null ลงไป และปุ่มจะไม่แสดง
      //
      // ถ้ามี callback
      // ให้ DetailContent เรียก method ของ State ตัวนี้แทน
      onAcceptPressed: widget.onAcceptMission == null
          ? null
          : _handleAcceptMission,
    );
  }
}

// ==================================================
// Detail
// ==================================================

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.request,
    required this.info,
    required this.previousCancellations,
    required this.isAcceptingMission,
    required this.onAcceptPressed,
  });

  final EmergencyRequest request;

  final EmergencyInfo info;

  final List<PreviousRescueMissionCancellation> previousCancellations;

  // ==================================================
  // Accept Mission UI State
  // ==================================================

  /// true = กำลังส่ง Accept Mission
  /// false = ปุ่มอยู่สถานะปกติ
  final bool isAcceptingMission;

  /// callback สำหรับกดปุ่มเข้าร่วมภารกิจ
  ///
  /// null = ไม่แสดงปุ่ม
  final VoidCallback? onAcceptPressed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          // ==================================================
          // Disaster Type
          // ==================================================
          _Box(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Line(label: 'ประเภทเหตุ', value: _value(request.requestType)),
                const SizedBox(height: 5),
                _Line(
                  label: 'จำนวนผู้ประสบภัย',
                  value: '${request.affectedCount} คน',
                ),
              ],
            ),
          ),

          const SizedBox(height: 9),

          // ==================================================
          // Victim Information
          // ==================================================
          _Box(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Expanded(
                      flex: 2,

                      child: _Line(
                        label: 'ชื่อ - นามสกุล',

                        value: _value(info.fullName),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: _Line(
                        label: 'กรุ๊ปเลือด',

                        value: _value(info.bloodGroup),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                _Line(label: 'เบอร์โทร', value: _value(info.phoneNumber)),

                const SizedBox(height: 5),

                _Line(
                  label: 'โรคประจำตัว',

                  value: _optional(info.medicalCondition),
                ),

                const SizedBox(height: 5),

                _Line(label: 'ประวัติการแพ้', value: _optional(info.allergy)),

                const SizedBox(height: 5),

                _Line(
                  label: 'ยาประจำตัว',

                  value: _optional(info.regularMedication),
                ),

                const SizedBox(height: 5),

                _Line(
                  label: 'ชื่อ - นามสกุลผู้ติดต่อฉุกเฉิน',

                  value: _value(info.emergencyContactName),
                ),

                const SizedBox(height: 5),

                _Line(
                  label: 'เบอร์โทรผู้ติดต่อฉุกเฉิน',

                  value: _value(info.emergencyContactPhone),
                ),
              ],
            ),
          ),

          const SizedBox(height: 9),

          // ==================================================
          // Image
          // ==================================================
          _Box(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text('รูปภาพ :', style: _labelStyle),

                const SizedBox(height: 8),

                _RequestImage(imageUrl: request.requestImage),

                if (previousCancellations.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _PreviousCancellationHistory(
                    cancellations: previousCancellations,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 9),

          // ==================================================
          // Detail
          // ==================================================
          _Box(
            child: _Line(
              label: 'รายละเอียดเพิ่มเติม',

              value: _value(request.requestDetail),
            ),
          ),

          const SizedBox(height: 16),

          // ==================================================
          // Accept Rescue Mission
          //
          // จะปรากฏเมื่อ Use Case Accept Mission
          // ส่ง callback เข้ามาเท่านั้น
          // ==================================================
          // ==================================================
          // Accept Rescue Mission
          //
          // ปุ่มจะปรากฏเฉพาะเมื่อ Parent ส่ง callback มา
          // ==================================================
          if (onAcceptPressed != null)
            SizedBox(
              height: 48,

              child: Material(
                // ==================================================
                // สีของปุ่ม
                //
                // Loading = สีอ่อน
                // Normal = สีปกติ
                // ==================================================
                color: isAcceptingMission
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : AppColors.primary,

                borderRadius: BorderRadius.circular(12),

                clipBehavior: Clip.antiAlias,

                child: InkWell(
                  // ==================================================
                  // ป้องกันการกดซ้ำ
                  // ==================================================
                  onTap: isAcceptingMission ? null : onAcceptPressed,

                  borderRadius: BorderRadius.circular(12),

                  child: SizedBox(
                    width: double.infinity,

                    height: 48,

                    child: Center(
                      child: isAcceptingMission
                          // ==================================================
                          // Loading
                          // ==================================================
                          ? const SizedBox(
                              width: 22,

                              height: 22,

                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,

                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          // ==================================================
                          // Normal
                          // ==================================================
                          : const Text(
                              'เข้าร่วมภารกิจ',

                              style: TextStyle(
                                color: Colors.white,

                                fontSize: 16,

                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _value(String value) {
    final text = value.trim();

    return text.isEmpty ? '-' : text;
  }

  static String _optional(String? value) {
    final text = value?.trim();

    return text == null || text.isEmpty ? '-' : text;
  }
}

// ==================================================
// Previous mission cancellations
// ==================================================

class _PreviousCancellationHistory extends StatefulWidget {
  const _PreviousCancellationHistory({required this.cancellations});

  final List<PreviousRescueMissionCancellation> cancellations;

  @override
  State<_PreviousCancellationHistory> createState() =>
      _PreviousCancellationHistoryState();
}

class _PreviousCancellationHistoryState
    extends State<_PreviousCancellationHistory> {
  static const int _initialVisibleCount = 2;

  bool _showAll = false;

  @override
  void didUpdateWidget(covariant _PreviousCancellationHistory oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.cancellations.length <= _initialVisibleCount && _showAll) {
      _showAll = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headingColor = isDark
        ? Colors.orange.shade200
        : AppColors.warningDark;
    final canExpand = widget.cancellations.length > _initialVisibleCount;
    final visibleCancellations = _showAll
        ? widget.cancellations
        : widget.cancellations.take(_initialVisibleCount).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.warning.withValues(alpha: 0.14)
            : AppColors.lightWarningContainer,
        border: Border.all(
          color: AppColors.warning.withValues(alpha: isDark ? 0.65 : 0.45),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.history_rounded, size: 20, color: headingColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ประวัติการยกเลิกจากทีมกู้ภัยก่อนหน้า '
                  '(${widget.cancellations.length} ครั้ง)',
                  style: TextStyle(
                    color: headingColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < visibleCancellations.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _CancellationHistoryItem(
              cancellation: visibleCancellations[index],
              isLatest: index == 0,
            ),
          ],
          if (canExpand) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showAll = !_showAll;
                  });
                },
                icon: Icon(
                  _showAll
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: Text(
                  _showAll
                      ? 'แสดง 2 รายการล่าสุด'
                      : 'ดูประวัติทั้งหมด (${widget.cancellations.length})',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CancellationHistoryItem extends StatelessWidget {
  const _CancellationHistoryItem({
    required this.cancellation,
    required this.isLatest,
  });

  final PreviousRescueMissionCancellation cancellation;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mission = cancellation.mission;
    final reason = mission.cancelReason?.trim();
    final detail = mission.cancelDetail?.trim();
    final normalizedTeamName = cancellation.teamName?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: isDark ? 0.7 : 0.9),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: isDark ? 0.4 : 0.28),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLatest ? 'รายการล่าสุด' : 'รายการก่อนหน้า',
            style: TextStyle(
              color: isDark ? Colors.orange.shade200 : AppColors.warningDark,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          _CancellationLine(
            label: 'ทีมกู้ภัยก่อนหน้า',
            value: normalizedTeamName == null || normalizedTeamName.isEmpty
                ? 'ไม่พบข้อมูลชื่อทีม'
                : normalizedTeamName,
          ),
          const SizedBox(height: 5),
          _CancellationLine(
            label: 'ยกเลิกเมื่อ',
            value: _formatCancellationDateTime(mission.missionEndDate),
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 5),
            _CancellationLine(label: 'เหตุผล', value: reason),
          ],
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: 5),
            _CancellationLine(label: 'รายละเอียดเพิ่มเติม', value: detail),
          ],
        ],
      ),
    );
  }

  static String _formatCancellationDateTime(DateTime? value) {
    if (value == null) {
      return 'ไม่พบข้อมูลเวลา';
    }

    final localValue = value.toLocal();
    final day = localValue.day.toString().padLeft(2, '0');
    final month = localValue.month.toString().padLeft(2, '0');
    final year = localValue.year + 543;
    final hour = localValue.hour.toString().padLeft(2, '0');
    final minute = localValue.minute.toString().padLeft(2, '0');

    return '$day/$month/$year เวลา $hour:$minute น.';
  }
}

class _CancellationLine extends StatelessWidget {
  const _CancellationLine({required this.label, required this.value});

  final String label;

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 13,
          height: 1.35,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

// ==================================================
// Gray Box
// ==================================================

class _Box extends StatelessWidget {
  const _Box({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),

      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,

        borderRadius: BorderRadius.circular(13),
      ),

      child: child,
    );
  }
}

// ==================================================
// Text Line
// ==================================================

const _labelStyle = TextStyle(
  color: AppColors.primary,

  fontWeight: FontWeight.w700,

  fontSize: 13,
);

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label : ', style: _labelStyle),

          TextSpan(
            text: value,

            style: const TextStyle(
              color: Colors.black87,

              fontSize: 13,

              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================
// Image
// ==================================================

class _RequestImage extends StatelessWidget {
  const _RequestImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();

    return Container(
      width: double.infinity,

      height: 150,

      clipBehavior: Clip.antiAlias,

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(16),
      ),

      child: url == null || url.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  Icon(Icons.image_outlined, size: 32, color: Colors.black45),

                  SizedBox(height: 6),

                  Text('ไม่มีรูปภาพ', style: TextStyle(color: Colors.black54)),
                ],
              ),
            )
          : Image.network(
              url,

              fit: BoxFit.cover,

              errorBuilder: (context, error, stackTrace) {
                return const Center(child: Text('ไม่สามารถแสดงรูปภาพได้'));
              },
            ),
    );
  }
}
