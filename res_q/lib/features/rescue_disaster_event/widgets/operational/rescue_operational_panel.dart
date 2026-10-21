import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/mission_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/emergency_request_model.dart';
import '../../../../data/models/rescue_mission_monitor_model.dart';

import '../../controllers/rescue_emergency_request_controller.dart';

import '../emergency_request_empty_state.dart';
import '../rescue_operational_header.dart';

import 'emergency_request_card.dart';

class RescueOperationalPanel extends StatelessWidget {
  const RescueOperationalPanel({
    super.key,
    required this.emergencyController,
    required this.rescuePosition,
    required this.onLeavePressed,
    required this.onEmergencyRequestTap,
    required this.activeMission,
    required this.queuedMissions,
    required this.isMissionLoading,
    required this.missionErrorMessage,
    required this.onRetryMission,
    required this.onUpdateMissionStatus,
    required this.onCancelMission,
    required this.onCompleteMission,
    required this.isUpdatingMissionStatus,
  });

  final RescueEmergencyRequestController emergencyController;

  final LatLng rescuePosition;

  final VoidCallback onLeavePressed;

  final ValueChanged<EmergencyRequest> onEmergencyRequestTap;

  final RescueMissionAssignment? activeMission;

  final List<RescueMissionAssignment> queuedMissions;

  final bool isMissionLoading;

  final String? missionErrorMessage;

  final VoidCallback onRetryMission;

  final Future<bool> Function(
    RescueMissionAssignment assignment,
    String newStatus,
  )
  onUpdateMissionStatus;

  final ValueChanged<RescueMissionAssignment> onCancelMission;

  final ValueChanged<RescueMissionAssignment> onCompleteMission;

  final bool isUpdatingMissionStatus;

  static const Distance _distance = Distance();

  // ==================================================
  // Build
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAssignments = activeMission != null || queuedMissions.isNotEmpty;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RescueOperationalHeader(
            title: !hasAssignments
                ? 'รายการเหตุฉุกเฉิน'
                : 'ภารกิจของชุดปฏิบัติการ',
            onLeavePressed: onLeavePressed,
          ),

          Expanded(
            child: !hasAssignments
                ? _buildContent(context)
                : DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(
                          tabs: [
                            Tab(text: 'ภารกิจและคิว'),
                            Tab(text: 'คำร้องใกล้เคียง'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildMissionOverview(context),
                              _buildContent(context),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // Content
  // ==================================================

  Widget _buildContent(BuildContext context) {
    if (isMissionLoading && !emergencyController.hasRequests) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (missionErrorMessage != null && !emergencyController.hasRequests) {
      return _EmergencyRequestErrorState(
        message: missionErrorMessage!,
        onRetry: onRetryMission,
      );
    }

    // ==================================================
    // Loading
    // ==================================================

    if (emergencyController.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),

            SizedBox(height: 12),

            Text('กำลังโหลดรายการเหตุฉุกเฉิน...'),
          ],
        ),
      );
    }

    // ==================================================
    // Error
    // ==================================================

    final error = emergencyController.errorMessage;

    if (error != null) {
      return _EmergencyRequestErrorState(
        message: error,
        onRetry: emergencyController.retry,
      );
    }

    // ==================================================
    // Empty
    // ==================================================

    if (!emergencyController.hasRequests) {
      return const SingleChildScrollView(child: EmergencyRequestEmptyState());
    }

    // ==================================================
    // Requests
    // ==================================================

    final requests = emergencyController.requests;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];

        final distanceMeters = _calculateDistance(request);

        return Column(
          children: [
            EmergencyRequestCard(
              request: request,

              distanceMeters: distanceMeters,

              onTap: () {
                onEmergencyRequestTap(request);
              },
            ),

            // ==========================================
            // Invalid Location
            // ==========================================
            if (!request.hasValidLocation)
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      size: 16,
                      color: AppColors.warning,
                    ),

                    SizedBox(width: 6),

                    Expanded(
                      child: Text(
                        'ไม่สามารถแสดงตำแหน่ง'
                        'ของคำร้องนี้บนแผนที่ได้',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMissionOverview(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (activeMission != null)
            _ActiveMissionControlCard(
              assignment: activeMission!,
              isUpdating: isUpdatingMissionStatus,
              onUpdateStatus: onUpdateMissionStatus,
              onCancel: onCancelMission,
              onComplete: onCompleteMission,
            ),
          if (queuedMissions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'คิวภารกิจ ${queuedMissions.length}/2',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...queuedMissions.map(
              (assignment) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _QueuedMissionCard(
                  assignment: assignment,
                  onCancel: onCancelMission,
                ),
              ),
            ),
          ],
          if (activeMission == null && queuedMissions.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'กำลังซิงก์ภารกิจถัดไป กรุณารอสักครู่',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  // ==================================================
  // Distance
  // ==================================================

  double _calculateDistance(EmergencyRequest request) {
    if (!request.hasValidLocation) {
      return double.nan;
    }

    return _distance.as(
      LengthUnit.Meter,
      rescuePosition,
      LatLng(request.latitude, request.longitude),
    );
  }
}

class _QueuedMissionCard extends StatelessWidget {
  const _QueuedMissionCard({required this.assignment, required this.onCancel});

  final RescueMissionAssignment assignment;
  final ValueChanged<RescueMissionAssignment> onCancel;

  @override
  Widget build(BuildContext context) {
    final position = assignment.mission.queuePosition ?? 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightWarningContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.warning,
            foregroundColor: Colors.white,
            child: Text(
              '$position',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.request.requestType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  'รอภารกิจปัจจุบันเสร็จสิ้น',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.warningDark),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => onCancel(assignment),
            child: const Text('ยกเลิกคิว'),
          ),
        ],
      ),
    );
  }
}

class _ActiveMissionControlCard extends StatelessWidget {
  const _ActiveMissionControlCard({
    required this.assignment,
    required this.isUpdating,
    required this.onUpdateStatus,
    required this.onCancel,
    required this.onComplete,
  });

  final RescueMissionAssignment assignment;
  final bool isUpdating;
  final Future<bool> Function(RescueMissionAssignment, String) onUpdateStatus;
  final ValueChanged<RescueMissionAssignment> onCancel;
  final ValueChanged<RescueMissionAssignment> onComplete;

  @override
  Widget build(BuildContext context) {
    final mission = assignment.mission;
    final currentStatus = mission.missionStatus;
    final nextStatus = MissionStatus.nextActiveStatus(currentStatus);
    final canUpdate = !isUpdating && nextStatus != null;
    final canComplete =
        currentStatus == MissionStatus.evacuationCenterReached && !isUpdating;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.emergency_share_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'สถานะปัจจุบัน',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        MissionStatus.labelOf(currentStatus),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: isUpdating ? null : () => onCancel(assignment),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emergency,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('ยกเลิกภารกิจ'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: canComplete
                      ? () => onComplete(assignment)
                      : canUpdate
                      ? () => onUpdateStatus(assignment, nextStatus)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: canComplete
                        ? AppColors.success
                        : AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: isUpdating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          canComplete
                              ? Icons.task_alt_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                  label: Text(
                    canComplete
                        ? 'จบภารกิจ'
                        : MissionStatus.nextActionLabel(currentStatus),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================================================
// Error State
// ==================================================

class _EmergencyRequestErrorState extends StatelessWidget {
  const _EmergencyRequestErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: theme.colorScheme.error,
            ),

            const SizedBox(height: 12),

            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: 14),

            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}
