import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/deployment_status.dart';
import '../../../core/constants/emergency_request_status.dart';
import '../../../core/constants/mission_status.dart';
import '../../../core/constants/mission_result.dart';

import '../../../data/models/rescue_mission_model.dart';
import '../../../data/models/rescue_mission_queue_model.dart';

import 'exceptions/accept_rescue_mission_exception.dart';

class AcceptRescueMissionService {
  AcceptRescueMissionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ==================================================
  // Collections
  // ==================================================

  static const String _emergencyRequestsCollection = 'emergencyRequests';

  static const String _missionSubCollection = 'RescueMission';

  static const String _disasterEventsCollection = 'disasterEvents';

  static const String _rescueTeamSubCollection = 'RescueTeam';

  // ==================================================
  // Accept Mission
  // ==================================================

  Future<RescueMission> accept({
    required String requestId,
    required String deploymentId,
    required String missionName,
  }) async {
    // ==================================================
    // Normalize
    // ==================================================

    final normalizedRequestId = requestId.trim();

    final normalizedDeploymentId = deploymentId.trim();

    final normalizedMissionName = missionName.trim();

    // ==================================================
    // Validation
    // ==================================================

    if (normalizedRequestId.isEmpty) {
      throw const AcceptMissionRequestNotFoundException();
    }

    if (normalizedDeploymentId.isEmpty) {
      throw const AcceptMissionDeploymentNotFoundException();
    }

    if (normalizedMissionName.isEmpty) {
      throw const AcceptMissionNameRequiredException();
    }

    // ==================================================
    // References
    // ==================================================

    final requestReference = _firestore
        .collection(_emergencyRequestsCollection)
        .doc(normalizedRequestId);

    final missionReference = requestReference
        .collection(_missionSubCollection)
        .doc();

    debugPrint('================================');

    debugPrint('[ACCEPT MISSION] START');

    debugPrint(
      '[ACCEPT MISSION] '
      'request=$normalizedRequestId',
    );

    debugPrint(
      '[ACCEPT MISSION] '
      'deployment=$normalizedDeploymentId',
    );

    debugPrint(
      '[ACCEPT MISSION] '
      'mission=${missionReference.id}',
    );

    try {
      // ใช้สำหรับย้ายข้อมูลเดิมที่สร้างก่อนมีฟิลด์คิวบน Deployment
      // query นี้ใช้ collection-group index ของ deploymentId ที่ระบบมีอยู่แล้ว
      final existingAssignments = await _loadExistingAssignments(
        normalizedDeploymentId,
      );

      // ==================================================
      // Firestore Transaction
      // ==================================================

      await _firestore.runTransaction((transaction) async {
        // ==================================================
        // 1. Read Emergency Request
        // ==================================================

        final requestSnapshot = await transaction.get(requestReference);

        if (!requestSnapshot.exists) {
          throw const AcceptMissionRequestNotFoundException();
        }

        final requestData = requestSnapshot.data() ?? const <String, dynamic>{};

        // ==================================================
        // 2. Check Request Status
        //
        // สำคัญ:
        // ถ้าทีมอื่น Accept ไปก่อนแล้ว
        // status จะไม่ใช่ WAITING
        // ==================================================

        final requestStatus = requestData['requestStatus']
            ?.toString()
            .trim()
            .toUpperCase();

        if (requestStatus != EmergencyRequestStatus.waiting) {
          debugPrint(
            '[ACCEPT MISSION] '
            'request unavailable '
            'status=$requestStatus',
          );

          throw const AcceptMissionRequestUnavailableException();
        }

        // ==================================================
        // 3. Resolve Disaster Event
        //
        // Mission ไม่ต้อง duplicate disasterEventId
        // แต่ตอน Accept ต้องใช้ eventId เพื่อหา Deployment
        // ==================================================

        final disasterEventId = requestData['disasterEventId']
            ?.toString()
            .trim();

        if (disasterEventId == null || disasterEventId.isEmpty) {
          throw const AcceptRescueMissionException(
            'ไม่พบข้อมูลเหตุการณ์ภัยพิบัติของคำร้อง',
            code: 'disaster-event-not-found',
          );
        }

        // ==================================================
        // 4. Resolve Rescue Deployment
        // ==================================================

        final deploymentReference = _firestore
            .collection(_disasterEventsCollection)
            .doc(disasterEventId)
            .collection(_rescueTeamSubCollection)
            .doc(normalizedDeploymentId);

        final deploymentSnapshot = await transaction.get(deploymentReference);

        if (!deploymentSnapshot.exists) {
          throw const AcceptMissionDeploymentNotFoundException();
        }

        final deploymentData =
            deploymentSnapshot.data() ?? const <String, dynamic>{};

        final deploymentStatus = deploymentData['deploymentStatus']
            ?.toString()
            .trim()
            .toUpperCase();

        if (deploymentStatus != DeploymentStatus.active) {
          debugPrint(
            '[ACCEPT MISSION] '
            'deployment not active '
            'status=$deploymentStatus',
          );

          throw const AcceptMissionDeploymentNotActiveException();
        }

        final hasStoredQueueState =
            deploymentData.containsKey('activeMissionId') ||
            deploymentData.containsKey('activeMissionRequestId') ||
            deploymentData.containsKey('missionQueue');
        var queueState = hasStoredQueueState
            ? RescueMissionQueueState.fromDeployment(deploymentData)
            : _queueStateFromExisting(existingAssignments);
        final newEntry = RescueMissionQueueEntry(
          requestId: normalizedRequestId,
          missionId: missionReference.id,
        );

        late final String initialMissionStatus;
        late final int? queuePosition;

        if (queueState.active == null) {
          initialMissionStatus = MissionStatus.onTheWay;
          queuePosition = null;
          queueState = RescueMissionQueueState(
            active: newEntry,
            queued: queueState.queued,
          );
        } else {
          if (!queueState.hasQueueCapacity) {
            throw const AcceptMissionQueueFullException();
          }

          initialMissionStatus = MissionStatus.queued;
          queuePosition = queueState.queued.length + 1;
          queueState = RescueMissionQueueState(
            active: queueState.active,
            queued: <RescueMissionQueueEntry>[...queueState.queued, newEntry],
          );
        }

        // ==================================================
        // 5. Create RescueMission
        // ==================================================

        transaction.set(missionReference, {
          'missionId': missionReference.id,

          'missionName': normalizedMissionName,

          'missionStatus': initialMissionStatus,

          'missionAcceptedDate': FieldValue.serverTimestamp(),

          'missionStartDate': initialMissionStatus == MissionStatus.onTheWay
              ? FieldValue.serverTimestamp()
              : null,

          'queuePosition': queuePosition,

          'missionEndDate': null,

          'missionResult': MissionResult.pending,

          'totalAffected': null,

          'proofImage': null,

          'safeLocationName': null,

          'cancelReason': null,

          'cancelDetail': null,

          'cancelImage': null,

          'deploymentId': normalizedDeploymentId,
        });

        transaction.update(deploymentReference, {
          ...queueState.toFirestore(),
          'missionQueueUpdatedAt': FieldValue.serverTimestamp(),
        });

        // ==================================================
        // 6. Update Emergency Request
        //
        // WAITING → ACCEPTED
        // ==================================================

        transaction.update(requestReference, {
          'requestStatus': EmergencyRequestStatus.accepted,

          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // ==================================================
      // Transaction Success
      //
      // serverTimestamp อาจยังต้องอ่านจาก Firestore
      // เพื่อให้ได้ค่าจริง
      // ==================================================

      final missionSnapshot = await missionReference.get();

      if (!missionSnapshot.exists) {
        throw const AcceptRescueMissionException(
          'สร้างภารกิจสำเร็จแต่ไม่สามารถอ่านข้อมูลภารกิจได้',
          code: 'mission-read-after-create-failed',
        );
      }

      final mission = RescueMission.fromFirestore(missionSnapshot);

      debugPrint(
        '[ACCEPT MISSION] SUCCESS '
        'mission=${mission.missionId}',
      );

      return mission;
    } on AcceptRescueMissionException {
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('[ACCEPT MISSION] FIREBASE ERROR');

      debugPrint(
        '[ACCEPT MISSION] '
        '${error.code}: ${error.message}',
      );

      debugPrint('[ACCEPT MISSION] $stackTrace');

      throw AcceptRescueMissionException(
        _firebaseErrorMessage(error),
        code: error.code,
      );
    } catch (error, stackTrace) {
      debugPrint('[ACCEPT MISSION] UNKNOWN ERROR');

      debugPrint('[ACCEPT MISSION] $error');

      debugPrint('[ACCEPT MISSION] $stackTrace');

      throw const AcceptRescueMissionException(
        'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง',
        code: 'accept-mission-unknown-error',
      );
    } finally {
      debugPrint('[ACCEPT MISSION] FINISHED');

      debugPrint('================================');
    }
  }

  Future<List<_ExistingAssignment>> _loadExistingAssignments(
    String deploymentId,
  ) async {
    final snapshot = await _firestore
        .collectionGroup(_missionSubCollection)
        .where('deploymentId', isEqualTo: deploymentId)
        .get();

    final assignments = snapshot.docs
        .map((document) {
          final data = document.data();
          final status = (data['missionStatus'] ?? '')
              .toString()
              .trim()
              .toUpperCase();
          if (!MissionStatus.isAssigned(status)) return null;

          final requestId = document.reference.parent.parent?.id ?? '';
          if (requestId.isEmpty) return null;

          return _ExistingAssignment(
            entry: RescueMissionQueueEntry(
              requestId: requestId,
              missionId: document.id,
            ),
            status: status,
            queuePosition: _readInt(data['queuePosition']),
            acceptedAt: _readTimestamp(
              data['missionAcceptedDate'] ?? data['missionStartDate'],
            ),
          );
        })
        .whereType<_ExistingAssignment>()
        .toList();

    assignments.sort(_compareExistingAssignments);
    return assignments;
  }

  static RescueMissionQueueState _queueStateFromExisting(
    List<_ExistingAssignment> assignments,
  ) {
    _ExistingAssignment? active;
    final queued = <RescueMissionQueueEntry>[];

    for (final assignment in assignments) {
      if (MissionStatus.isActive(assignment.status) && active == null) {
        active = assignment;
      } else if (MissionStatus.isQueued(assignment.status) &&
          queued.length < RescueMissionQueueState.maximumQueuedMissions) {
        queued.add(assignment.entry);
      }
    }

    return RescueMissionQueueState(active: active?.entry, queued: queued);
  }

  static int _compareExistingAssignments(
    _ExistingAssignment first,
    _ExistingAssignment second,
  ) {
    final firstIsActive = MissionStatus.isActive(first.status);
    final secondIsActive = MissionStatus.isActive(second.status);
    if (firstIsActive != secondIsActive) return firstIsActive ? -1 : 1;

    final queueComparison = (first.queuePosition ?? 1 << 20).compareTo(
      second.queuePosition ?? 1 << 20,
    );
    if (queueComparison != 0) return queueComparison;

    final firstDate = first.acceptedAt;
    final secondDate = second.acceptedAt;
    if (firstDate == null && secondDate == null) {
      return first.entry.missionId.compareTo(second.entry.missionId);
    }
    if (firstDate == null) return 1;
    if (secondDate == null) return -1;
    return firstDate.compareTo(secondDate);
  }

  static int? _readInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _readTimestamp(dynamic value) {
    return value is Timestamp ? value.toDate() : null;
  }

  // ==================================================
  // Firebase Message
  // ==================================================

  static String _firebaseErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'ไม่มีสิทธิ์รับภารกิจนี้';

      case 'unavailable':
        return 'ไม่สามารถเชื่อมต่อฐานข้อมูลได้ กรุณาลองใหม่อีกครั้ง';

      case 'deadline-exceeded':
        return 'การเชื่อมต่อใช้เวลานานเกินไป กรุณาลองใหม่';

      case 'aborted':
        return 'ข้อมูลมีการเปลี่ยนแปลง กรุณาลองรับภารกิจอีกครั้ง';

      default:
        return 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
    }
  }
}

class _ExistingAssignment {
  const _ExistingAssignment({
    required this.entry,
    required this.status,
    required this.queuePosition,
    required this.acceptedAt,
  });

  final RescueMissionQueueEntry entry;
  final String status;
  final int? queuePosition;
  final DateTime? acceptedAt;
}
