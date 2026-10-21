import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/routing/app_routes.dart';
import '../../core/constants/emergency_request_status.dart';
import '../../core/constants/mission_status.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/emergency_request_model.dart';
import '../../data/models/rescue_mission_monitor_model.dart';
import '../../shared/widgets/success_alert_dialog.dart';
import 'controllers/emergency_tracking_controller.dart';
import 'widgets/emergency_tracking_map_card.dart';
import 'widgets/emergency_tracking_progress.dart';
import 'widgets/safety_confirmation_popup.dart';

class EmergencyTrackingPage extends StatefulWidget {
  const EmergencyTrackingPage({super.key, required this.requestId});

  final String requestId;

  @override
  State<EmergencyTrackingPage> createState() => _EmergencyTrackingPageState();
}

class _EmergencyTrackingPageState extends State<EmergencyTrackingPage>
    with WidgetsBindingObserver {
  late final EmergencyTrackingController _controller;

  String? _lastObservedRequestStatus;
  bool _hasObservedInitialRequest = false;
  bool _isShowingMissionCancelledDialog = false;
  bool _isShowingMissionCompletedDialog = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _controller = EmergencyTrackingController(requestId: widget.requestId);

    _controller.addListener(_handleTrackingChanged);

    _controller.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _controller.removeListener(_handleTrackingChanged);

    _controller.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.resumeLiveLocationTracking();
      return;
    }

    unawaited(_controller.pauseLiveLocationTracking());
  }

  void _handleTrackingChanged() {
    final request = _controller.request;

    if (request == null) return;

    final currentStatus = request.requestStatus;

    if (!_hasObservedInitialRequest) {
      _hasObservedInitialRequest = true;
      _lastObservedRequestStatus = currentStatus;
      return;
    }

    final previousStatus = _lastObservedRequestStatus;
    _lastObservedRequestStatus = currentStatus;

    final rescueMissionWasCancelled =
        previousStatus == EmergencyRequestStatus.accepted &&
        currentStatus == EmergencyRequestStatus.waiting;
    final rescueMissionWasCompleted =
        previousStatus == EmergencyRequestStatus.accepted &&
        currentStatus == EmergencyRequestStatus.completed;

    if (rescueMissionWasCancelled && !_isShowingMissionCancelledDialog) {
      _isShowingMissionCancelledDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMissionCancelledDialog();
      });
    }

    if (rescueMissionWasCompleted && !_isShowingMissionCompletedDialog) {
      _isShowingMissionCompletedDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMissionCompletedDialog();
      });
    }
  }

  Future<void> _showMissionCancelledDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.emergency,
            size: 42,
          ),
          title: const Text(
            'ทีมกู้ภัยยกเลิกภารกิจ',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'ทีมกู้ภัยชุดเดิมไม่สามารถดำเนินภารกิจต่อได้ '
            'คำร้องของคุณถูกนำกลับเข้าสู่รายการรอความช่วยเหลือแล้ว\n',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('รับทราบ'),
            ),
          ],
        );
      },
    );

    _isShowingMissionCancelledDialog = false;
  }

  Future<void> _showMissionCompletedDialog() async {
    final teamName = _controller.teamInfo?.teamName.trim();
    final displayTeamName = teamName == null || teamName.isEmpty
        ? 'หน่วยกู้ภัย'
        : teamName;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.volunteer_activism_rounded,
            color: AppColors.success,
            size: 42,
          ),
          title: const Text('ช่วยเหลือสำเร็จ', textAlign: TextAlign.center),
          content: Text(
            'ขอบคุณ $displayTeamName ที่ช่วยเหลือผู้ประสบภัยเรียบร้อยแล้ว\n\n'
            'ขอให้คุณและครอบครัวปลอดภัย',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('รับทราบ'),
            ),
          ],
        );
      },
    );

    _isShowingMissionCompletedDialog = false;
  }

  // ==================================================
  // Build
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      // ขณะมี Request ที่ยังรอความช่วยเหลือ
      // ป้องกันการ Back แบบไม่ตั้งใจจากหน้า Monitor
      canPop: false,

      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerLowest,

        // ==================================================
        // AppBar
        // ==================================================
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('ติดตามสถานะ'),
          centerTitle: true,
        ),

        // ==================================================
        // Body
        // ==================================================
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, child) {
              return _buildContent();
            },
          ),
        ),
      ),
    );
  }

  // ==================================================
  // Content
  // ==================================================

  Widget _buildContent() {
    if (_controller.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),

            SizedBox(height: 14),

            Text('กำลังโหลดสถานะคำร้อง...'),
          ],
        ),
      );
    }

    if (_controller.isNotFound) {
      return _buildProblemState(
        icon: Icons.search_off_rounded,
        title: 'ไม่พบคำร้อง',
        message: 'ไม่พบคำร้องขอความช่วยเหลือที่ต้องการติดตาม',
      );
    }

    if (_controller.isForbidden) {
      return _buildProblemState(
        icon: Icons.lock_outline,
        title: 'ไม่สามารถเข้าถึงคำร้องนี้ได้',
        message: 'คำร้องนี้ไม่ได้เป็นของผู้ใช้งานปัจจุบัน',
      );
    }

    if (_controller.hasError) {
      return _buildProblemState(
        icon: Icons.error_outline,
        title: 'โหลดสถานะไม่สำเร็จ',
        message: _controller.errorMessage ?? 'กรุณาลองใหม่อีกครั้ง',
        retry: true,
      );
    }

    final request = _controller.request;

    if (request == null) {
      return _buildProblemState(
        icon: Icons.error_outline,
        title: 'ไม่พบข้อมูล',
        message: 'ไม่สามารถอ่านข้อมูลคำร้องได้',
      );
    }

    return _buildRequest(request);
  }

  // ==================================================
  // Request
  // ==================================================

  Widget _buildRequest(EmergencyRequest request) {
    final deployment = _controller.deployment;
    final victimLatitude = _controller.victimLatitude ?? request.latitude;
    final victimLongitude = _controller.victimLongitude ?? request.longitude;
    final missionStatus = _controller.mission?.missionStatus;
    final rescueIsResponding =
        request.isAccepted &&
        missionStatus != null &&
        MissionStatus.isActive(missionStatus);

    return Column(
      children: [
        // ==================================================
        // Fixed Map
        //
        // แผนที่ไม่เลื่อนตามข้อมูลด้านล่าง
        // ==================================================
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: EmergencyTrackingMapCard(
            latitude: victimLatitude,
            longitude: victimLongitude,
            routeLatitude: request.latitude,
            routeLongitude: request.longitude,
            rescueLatitude:
                rescueIsResponding && deployment?.hasValidLocation == true
                ? deployment!.latitude
                : null,
            rescueLongitude:
                rescueIsResponding && deployment?.hasValidLocation == true
                ? deployment!.longitude
                : null,
          ),
        ),

        // ==================================================
        // Scrollable Information
        // ==================================================
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [_buildProgressCard(request)],
          ),
        ),
      ],
    );
  }

  // ==================================================
  // Progress Card
  // ==================================================

  Widget _buildProgressCard(EmergencyRequest request) {
    final theme = Theme.of(context);

    final waiting = request.requestStatus == EmergencyRequestStatus.waiting;

    final accepted = request.requestStatus == EmergencyRequestStatus.accepted;

    final cancelled = request.requestStatus == EmergencyRequestStatus.cancelled;

    final completed = request.requestStatus == EmergencyRequestStatus.completed;

    final missionStatus = _controller.mission?.missionStatus;
    final queued = missionStatus == MissionStatus.queued;
    final currentStep = completed
        ? 6
        : accepted && missionStatus != null
        ? MissionStatus.stageOf(missionStatus)
        : 1;
    final activeStatusLabel = missionStatus == null
        ? MissionStatus.labelOf(MissionStatus.onTheWay)
        : MissionStatus.labelOf(missionStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // ==================================================
          // 1 / 6
          // ==================================================
          EmergencyTrackingProgress(currentStep: currentStep),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ส่งคำร้อง',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.emergency,
                  fontWeight: FontWeight.w700,
                ),
              ),

              Text(
                'ช่วยเหลือสำเร็จ',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // ==================================================
          // Status Icon
          // ==================================================
          if (waiting)
            const _WaitingRescueStatusIcon()
          else if (accepted)
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.lightPrimaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emergency_share_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            )
          else
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: completed
                    ? AppColors.lightSuccessContainer
                    : cancelled
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                completed
                    ? Icons.check_circle_outline_rounded
                    : cancelled
                    ? Icons.cancel_outlined
                    : Icons.info_outline,
                size: 36,
                color: completed
                    ? AppColors.success
                    : cancelled
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),

          const SizedBox(height: 16),

          // ==================================================
          // Status Title
          // ==================================================
          Text(
            completed
                ? 'ช่วยเหลือสำเร็จแล้ว'
                : cancelled
                ? 'คำร้องถูกยกเลิกแล้ว'
                : accepted
                ? activeStatusLabel
                : waiting
                ? 'ขณะนี้คำร้องอยู่ในระหว่างดำเนินการ\n'
                      'รอเจ้าหน้าที่กู้ภัยรับเรื่อง'
                : 'กำลังดำเนินการคำร้อง',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 8),

          // ==================================================
          // Status Description
          // ==================================================
          Text(
            completed
                ? 'ทีมกู้ภัยได้ปิดภารกิจเรียบร้อยแล้ว ขอให้คุณปลอดภัย'
                : cancelled
                ? 'คำร้องขอความช่วยเหลือนี้ถูกยกเลิกแล้ว'
                : accepted
                ? queued
                      ? 'ทีมกู้ภัยบันทึกคำร้องของคุณไว้ในคิวแล้ว '
                            'เมื่อภารกิจก่อนหน้าเสร็จ ระบบจะเริ่มภารกิจของคุณอัตโนมัติ'
                      : 'โปรดอยู่ในจุดที่ปลอดภัยและสังเกตเห็นได้ง่าย '
                            'ระบบกำลังติดตามข้อมูลทีมกู้ภัยแบบเรียลไทม์'
                : waiting
                ? 'กรุณาอย่าตื่นตระหนก ตั้งสติ '
                      'และอยู่ในจุดที่ปลอดภัยระหว่างรอเจ้าหน้าที่กู้ภัย'
                : 'สถานะคำร้องของคุณมีการเปลี่ยนแปลง '
                      'ระบบจะแสดงรายละเอียดเพิ่มเติมเมื่อมีการดำเนินการ',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),

          if (!cancelled && !completed) ...[
            const SizedBox(height: 18),

            // ================================================
            // Info
            // ================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),

                  const SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      accepted
                          ? queued
                                ? 'ขณะนี้ทีมกู้ภัยยังช่วยเหลือภารกิจก่อนหน้า '
                                      'แผนที่จะเริ่มแสดงตำแหน่งทีมเมื่อถึงคิวของคุณ'
                                : 'ทีมกู้ภัยเริ่มเดินทางจากตำแหน่งชุดปฏิบัติการ '
                                      'แผนที่จะแสดงตำแหน่งล่าสุดที่บันทึกไว้'
                          : 'คำร้องของคุณถูกบันทึกแล้ว '
                                'กรุณาติดตามสถานะการช่วยเหลือจากหน้านี้',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (!accepted) ...[
            // ================================================
            // Request Detail แสดงเฉพาะ Stage 1
            // ================================================
            const SizedBox(height: 20),
            _buildRequestSummary(request),
          ],

          if (accepted) ...[
            const SizedBox(height: 20),
            _buildAcceptedMissionSection(),
          ],

          if (completed && !request.safeStatus) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _controller.canUpdateSafetyStatus
                    ? _handleSafetyStatusPressed
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.health_and_safety_rounded),
                label: const Text(
                  'ฉันปลอดภัยแล้ว',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],

          // ==================================================
          // Cancel
          // ==================================================
          if (waiting) ...[
            const SizedBox(height: 18),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightSuccessContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.health_and_safety_outlined,
                    color: AppColors.success,
                    size: 22,
                  ),

                  SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      'ตั้งสติและพยายามอยู่ในบริเวณที่ปลอดภัย '
                      'หากสามารถทำได้ให้อยู่ในจุดที่ทีมกู้ภัยสังเกตเห็นได้ง่าย',
                      style: TextStyle(height: 1.5, color: AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (waiting) ...[
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _controller.canCancel ? _handleCancelPressed : null,

                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.emergency,
                  side: const BorderSide(color: AppColors.emergency),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                icon: _controller.isCancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.emergency,
                        ),
                      )
                    : const Icon(Icons.close_rounded),

                label: Text(
                  _controller.isCancelling ? 'กำลังยกเลิก...' : 'ยกเลิกคำร้อง',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================================================
  // Request Summary
  // ==================================================

  Widget _buildRequestSummary(EmergencyRequest request) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ข้อมูลคำร้อง',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 12),

          _SummaryRow(label: 'ประเภทเหตุ', value: request.requestType),

          const SizedBox(height: 8),

          _SummaryRow(label: 'จำนวนคน', value: '${request.affectedCount} คน'),

          const SizedBox(height: 8),

          _SummaryRow(label: 'รายละเอียด', value: request.requestDetail),

          if (request.createdAt != null) ...[
            const SizedBox(height: 8),

            _SummaryRow(
              label: 'เวลาส่งคำร้อง',
              value: _formatDateTime(request.createdAt!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAcceptedMissionSection() {
    final theme = Theme.of(context);
    final mission = _controller.mission;
    final teamInfo = _controller.teamInfo;

    if (_controller.isMissionLoading && mission == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('กำลังโหลดข้อมูลทีมกู้ภัย...'),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightPrimaryContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.health_and_safety_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  teamInfo?.teamName ?? 'ทีมกู้ภัยที่รับภารกิจ',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (mission != null) ...[
            const SizedBox(height: 10),
            _MissionInfoRow(label: 'ภารกิจ', value: mission.missionName),
            const SizedBox(height: 6),
            _MissionInfoRow(
              label: 'สถานะ',
              value: MissionStatus.labelOf(mission.missionStatus),
            ),
            if (MissionStatus.isQueued(mission.missionStatus) &&
                (mission.queuePosition ?? 0) > 0) ...[
              const SizedBox(height: 10),
              _QueuedPositionBanner(position: mission.queuePosition!),
            ],
          ],
          if (teamInfo != null) ...[
            if (teamInfo.vehicles.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildVehicleHeader(),
              const SizedBox(height: 6),
              ...teamInfo.vehicles.map(_buildVehicleRow),
            ],
            if (teamInfo.members.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildMemberHeader(),
              const SizedBox(height: 6),
              ...teamInfo.members.map(_buildMemberRow),
            ],
          ],
          if (_controller.missionErrorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _controller.missionErrorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleHeader() {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: AppColors.lightTextSecondary,
      fontWeight: FontWeight.w800,
    );

    return Row(
      children: [
        const SizedBox(width: 26),
        Expanded(flex: 3, child: Text('ยานพาหนะ', style: style)),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text('ป้ายทะเบียน', textAlign: TextAlign.end, style: style),
        ),
      ],
    );
  }

  Widget _buildVehicleRow(RescueMissionVehicleInfo vehicle) {
    final vehicleName = vehicle.vehicleType.isEmpty
        ? 'ไม่ระบุยานพาหนะ'
        : vehicle.vehicleType;
    final plate = vehicle.vehiclePlate.isEmpty ? '-' : vehicle.vehiclePlate;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.local_shipping_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              vehicleName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              plate,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberHeader() {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: AppColors.lightTextSecondary,
      fontWeight: FontWeight.w800,
    );

    return Row(
      children: [
        const SizedBox(width: 26),
        Expanded(child: Text('สมาชิกกู้ภัย', style: style)),
        Text('เบอร์โทร', style: style),
      ],
    );
  }

  Widget _buildMemberRow(RescueMissionMemberInfo member) {
    final name = member.fullName.isEmpty
        ? 'เจ้าหน้าที่กู้ภัย'
        : member.fullName;
    final phoneNumber = member.phoneNumber.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.person_outline_rounded, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (member.position.isNotEmpty)
                  Text(
                    member.position,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (phoneNumber.isNotEmpty)
            TextButton.icon(
              onPressed: () => _callPhoneNumber(phoneNumber),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.phone_rounded, size: 20),
              label: Text(
                phoneNumber,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          else
            const Text('-', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  Future<void> _callPhoneNumber(String phoneNumber) async {
    final normalizedPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    final phoneUri = Uri(scheme: 'tel', path: normalizedPhone);

    try {
      final launched = await launchUrl(phoneUri);

      if (!launched && mounted) {
        _showErrorSnackBar('ไม่สามารถเปิดแอปโทรศัพท์ได้');
      }
    } catch (_) {
      if (mounted) {
        _showErrorSnackBar('ไม่สามารถโทรไปยังหมายเลขนี้ได้');
      }
    }
  }

  // ==================================================
  // S8 Placeholder
  // ==================================================

  void _showErrorSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _handleCancelPressed() async {
    // ==================================================
    // ป้องกันกดซ้ำ
    // ==================================================

    if (!_controller.canCancel || _controller.isCancelling) {
      return;
    }

    // ==================================================
    // Confirm Dialog
    // ==================================================

    final confirmed = await _showCancelConfirmDialog();

    if (!mounted || !confirmed) {
      return;
    }

    // ==================================================
    // Cancel Firestore
    // ==================================================

    final success = await _controller.cancelRequest();

    if (!mounted) {
      return;
    }

    // ==================================================
    // Failed
    // ==================================================

    if (!success) {
      _showErrorSnackBar(
        _controller.cancelErrorMessage ?? 'ไม่สามารถยกเลิกคำร้องได้',
      );

      return;
    }

    // ==================================================
    // Success
    // ==================================================

    await _showCancelSuccessDialog();

    if (!mounted) {
      return;
    }

    // ==================================================
    // กลับ Home
    // ==================================================

    context.go(AppRoutePaths.home);
  }

  Future<void> _handleSafetyStatusPressed() async {
    if (!_controller.canUpdateSafetyStatus) return;

    final confirmed = await showSafetyConfirmationPopup(
      context: context,
      controller: _controller,
    );
    if (!mounted || !confirmed) return;

    await _showSafetySuccessDialog();
    if (mounted) context.go(AppRoutePaths.home);
  }

  Future<void> _showSafetySuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.sentiment_very_satisfied_rounded,
            color: AppColors.warning,
            size: 78,
          ),
          title: const Text(
            'พวกเราดีใจที่คุณปลอดภัย',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'บันทึกการยืนยันความปลอดภัยเรียบร้อยแล้ว',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('กลับหน้าหลัก'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showCancelConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 52,
          ),

          title: const Text('ยกเลิกคำร้อง', textAlign: TextAlign.center),

          content: const Text(
            'คุณต้องการยกเลิกคำร้องขอความช่วยเหลือนี้หรือไม่?',
            textAlign: TextAlign.center,
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('ไม่ยกเลิก'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emergency,
                foregroundColor: Colors.white,
              ),
              child: const Text('ยืนยันยกเลิก'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showCancelSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return SuccessAlertDialog(
          title: 'ยกเลิกคำร้องสำเร็จ',
          message: 'ระบบได้ลบคำร้องขอความช่วยเหลือของคุณเรียบร้อยแล้ว',
          onConfirm: () => Navigator.of(dialogContext).pop(),
        );
      },
    );
  }

  // ==================================================
  // Error State
  // ==================================================

  Widget _buildProblemState({
    required IconData icon,
    required String title,
    required String message,
    bool retry = false,
  }) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 58, color: theme.colorScheme.error),

            const SizedBox(height: 14),

            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            if (retry) ...[
              const SizedBox(height: 18),

              FilledButton.icon(
                onPressed: _controller.retry,
                icon: const Icon(Icons.refresh),
                label: const Text('ลองใหม่'),
              ),
            ],

            const SizedBox(height: 12),

            TextButton.icon(
              onPressed: () => context.go(AppRoutePaths.home),
              icon: const Icon(Icons.home_outlined),
              label: const Text('กลับหน้าแรก'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================
  // Date
  // ==================================================

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${twoDigits(local.day)}/'
        '${twoDigits(local.month)}/'
        '${local.year} '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}';
  }
}

// ====================================================
// Summary Row
// ====================================================

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            value.trim().isEmpty ? '-' : value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MissionInfoRow extends StatelessWidget {
  const _MissionInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '-' : value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _QueuedPositionBanner extends StatelessWidget {
  const _QueuedPositionBanner({required this.position});

  final int position;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightWarningContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: AppColors.warning,
            size: 22,
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'ลำดับคิวของคุณ',
              style: TextStyle(
                color: AppColors.warningDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'คิวที่ $position',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingRescueStatusIcon extends StatelessWidget {
  const _WaitingRescueStatusIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.lightWarningContainer,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.warning, width: 4),
      ),
      child: const Icon(
        Icons.health_and_safety_outlined,
        size: 36,
        color: AppColors.warning,
      ),
    );
  }
}
