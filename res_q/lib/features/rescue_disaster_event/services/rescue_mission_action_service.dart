import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/emergency_request_status.dart';
import '../../../core/constants/mission_result.dart';
import '../../../core/constants/mission_status.dart';
import '../../../data/models/rescue_mission_queue_model.dart';
import 'exceptions/rescue_mission_action_exception.dart';

class RescueMissionActionService {
  RescueMissionActionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _requestsCollection = 'emergencyRequests';
  static const String _missionsCollection = 'RescueMission';
  static const String _eventsCollection = 'disasterEvents';
  static const String _deploymentsCollection = 'RescueTeam';

  Future<void> updateStatus({
    required String requestId,
    required String missionId,
    required String deploymentId,
    required String newStatus,
  }) async {
    final references = _references(requestId: requestId, missionId: missionId);
    final normalizedDeploymentId = deploymentId.trim();
    final normalizedStatus = newStatus.trim().toUpperCase();

    if (normalizedDeploymentId.isEmpty) {
      throw const RescueMissionOwnerMismatchException();
    }

    if (!MissionStatus.isActive(normalizedStatus)) {
      throw const RescueMissionNotActiveException();
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final requestSnapshot = await transaction.get(references.request);
        final missionSnapshot = await transaction.get(references.mission);

        if (!requestSnapshot.exists || !missionSnapshot.exists) {
          throw const RescueMissionNotFoundException();
        }

        final requestData = requestSnapshot.data() ?? const <String, dynamic>{};
        final missionData = missionSnapshot.data() ?? const <String, dynamic>{};

        final deploymentReference = _deploymentReference(
          requestData: requestData,
          deploymentId: normalizedDeploymentId,
        );
        final deploymentSnapshot = await transaction.get(deploymentReference);
        final deploymentData =
            deploymentSnapshot.data() ?? const <String, dynamic>{};

        _validateRequestStatus(requestData);
        _validateOwner(missionData, normalizedDeploymentId);
        _validateCurrentMission(
          deploymentData: deploymentData,
          missionId: references.mission.id,
        );

        final currentStatus = (missionData['missionStatus'] ?? '')
            .toString()
            .trim()
            .toUpperCase();

        if (!MissionStatus.isActive(currentStatus)) {
          throw const RescueMissionNotActiveException();
        }

        final currentIndex = MissionStatus.activeFlow.indexOf(currentStatus);
        final newIndex = MissionStatus.activeFlow.indexOf(normalizedStatus);

        if (newIndex < currentIndex) {
          throw const RescueMissionStatusBackwardException();
        }

        if (newIndex == currentIndex) {
          return;
        }

        if (newIndex != currentIndex + 1) {
          throw const RescueMissionStatusSkipException();
        }

        transaction.update(references.mission, {
          'missionStatus': normalizedStatus,
        });
      });
    } on RescueMissionActionException {
      rethrow;
    } on FirebaseException catch (error) {
      throw RescueMissionActionException(
        _firebaseMessage(error),
        code: error.code,
      );
    }
  }

  Future<void> cancel({
    required String requestId,
    required String missionId,
    required String deploymentId,
    required String cancelReason,
    String? cancelDetail,
    required String cancelImageUrl,
  }) async {
    final references = _references(requestId: requestId, missionId: missionId);
    final normalizedDeploymentId = deploymentId.trim();
    final normalizedReason = cancelReason.trim();
    final normalizedDetail = _normalizeOptional(cancelDetail);
    final normalizedImageUrl = cancelImageUrl.trim();

    if (normalizedDeploymentId.isEmpty) {
      throw const RescueMissionOwnerMismatchException();
    }
    if (normalizedReason.isEmpty) {
      throw const RescueMissionCancelReasonRequiredException();
    }
    if (normalizedReason.length > 255 ||
        (normalizedDetail != null && normalizedDetail.length > 255)) {
      throw const RescueMissionActionException(
        'ข้อมูลเหตุผลหรือรายละเอียดต้องไม่เกิน 255 ตัวอักษร',
        code: 'cancel-text-too-long',
      );
    }
    if (normalizedImageUrl.isEmpty) {
      throw const RescueMissionCancelImageRequiredException();
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final requestSnapshot = await transaction.get(references.request);
        final missionSnapshot = await transaction.get(references.mission);

        if (!requestSnapshot.exists || !missionSnapshot.exists) {
          throw const RescueMissionNotFoundException();
        }

        final requestData = requestSnapshot.data() ?? const <String, dynamic>{};
        final missionData = missionSnapshot.data() ?? const <String, dynamic>{};

        final deploymentReference = _deploymentReference(
          requestData: requestData,
          deploymentId: normalizedDeploymentId,
        );
        final deploymentSnapshot = await transaction.get(deploymentReference);
        if (!deploymentSnapshot.exists) {
          throw const RescueMissionNotFoundException();
        }
        final deploymentData =
            deploymentSnapshot.data() ?? const <String, dynamic>{};

        _validateRequestStatus(requestData);
        _validateOwner(missionData, normalizedDeploymentId);

        final currentStatus = (missionData['missionStatus'] ?? '')
            .toString()
            .trim()
            .toUpperCase();

        if (!MissionStatus.isAssigned(currentStatus)) {
          throw const RescueMissionNotActiveException();
        }

        if (MissionStatus.isActive(currentStatus)) {
          _validateCurrentMission(
            deploymentData: deploymentData,
            missionId: references.mission.id,
          );
        }

        await _releaseMissionAndPromote(
          transaction: transaction,
          deploymentReference: deploymentReference,
          deploymentData: deploymentData,
          currentMissionId: references.mission.id,
          currentWasQueued: MissionStatus.isQueued(currentStatus),
          deploymentId: normalizedDeploymentId,
        );

        transaction.update(references.mission, {
          'missionStatus': MissionStatus.cancelled,
          'missionEndDate': FieldValue.serverTimestamp(),
          'cancelReason': normalizedReason,
          'cancelDetail': normalizedDetail,
          'cancelImage': normalizedImageUrl,
        });

        transaction.update(references.request, {
          'requestStatus': EmergencyRequestStatus.waiting,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on RescueMissionActionException {
      rethrow;
    } on FirebaseException catch (error) {
      throw RescueMissionActionException(
        _firebaseMessage(error),
        code: error.code,
      );
    }
  }

  Future<void> complete({
    required String requestId,
    required String missionId,
    required String deploymentId,
    required String proofImageUrl,
    required String safeLocationName,
  }) async {
    final references = _references(requestId: requestId, missionId: missionId);
    final normalizedDeploymentId = deploymentId.trim();
    final normalizedProofImageUrl = proofImageUrl.trim();
    final normalizedSafeLocation = safeLocationName.trim();

    if (normalizedDeploymentId.isEmpty) {
      throw const RescueMissionOwnerMismatchException();
    }
    if (normalizedProofImageUrl.isEmpty) {
      throw const RescueMissionProofImageRequiredException();
    }
    if (normalizedSafeLocation.isEmpty) {
      throw const RescueMissionSafeLocationRequiredException();
    }
    if (normalizedSafeLocation.length > 255) {
      throw const RescueMissionActionException(
        'ชื่อสถานที่ปลอดภัยต้องไม่เกิน 255 ตัวอักษร',
        code: 'complete-text-too-long',
      );
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final requestSnapshot = await transaction.get(references.request);
        final missionSnapshot = await transaction.get(references.mission);

        if (!requestSnapshot.exists || !missionSnapshot.exists) {
          throw const RescueMissionNotFoundException();
        }

        final requestData = requestSnapshot.data() ?? const <String, dynamic>{};
        final missionData = missionSnapshot.data() ?? const <String, dynamic>{};
        final affectedCount = _affectedCountOf(requestData);

        final deploymentReference = _deploymentReference(
          requestData: requestData,
          deploymentId: normalizedDeploymentId,
        );
        final deploymentSnapshot = await transaction.get(deploymentReference);
        if (!deploymentSnapshot.exists) {
          throw const RescueMissionNotFoundException();
        }
        final deploymentData =
            deploymentSnapshot.data() ?? const <String, dynamic>{};

        _validateRequestStatus(requestData);
        _validateOwner(missionData, normalizedDeploymentId);
        _validateCurrentMission(
          deploymentData: deploymentData,
          missionId: references.mission.id,
        );

        final currentStatus = (missionData['missionStatus'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
        if (currentStatus != MissionStatus.evacuationCenterReached) {
          throw const RescueMissionCompleteUnavailableException();
        }

        await _releaseMissionAndPromote(
          transaction: transaction,
          deploymentReference: deploymentReference,
          deploymentData: deploymentData,
          currentMissionId: references.mission.id,
          currentWasQueued: false,
          deploymentId: normalizedDeploymentId,
        );

        transaction.update(references.mission, {
          'missionStatus': MissionStatus.completed,
          'missionEndDate': FieldValue.serverTimestamp(),
          'missionResult': MissionResult.success,
          'totalAffected': affectedCount,
          'proofImage': normalizedProofImageUrl,
          'safeLocationName': normalizedSafeLocation,
        });
        transaction.update(references.request, {
          'requestStatus': EmergencyRequestStatus.completed,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on RescueMissionActionException {
      rethrow;
    } on FirebaseException catch (error) {
      throw RescueMissionActionException(
        _firebaseMessage(error),
        code: error.code,
      );
    }
  }

  _MissionReferences _references({
    required String requestId,
    required String missionId,
  }) {
    final normalizedRequestId = requestId.trim();
    final normalizedMissionId = missionId.trim();

    if (normalizedRequestId.isEmpty || normalizedMissionId.isEmpty) {
      throw const RescueMissionNotFoundException();
    }

    final requestReference = _firestore
        .collection(_requestsCollection)
        .doc(normalizedRequestId);

    return _MissionReferences(
      request: requestReference,
      mission: requestReference
          .collection(_missionsCollection)
          .doc(normalizedMissionId),
    );
  }

  DocumentReference<Map<String, dynamic>> _deploymentReference({
    required Map<String, dynamic> requestData,
    required String deploymentId,
  }) {
    final eventId = (requestData['disasterEventId'] ?? '').toString().trim();
    if (eventId.isEmpty) {
      throw const RescueMissionRequestUnavailableException();
    }

    return _firestore
        .collection(_eventsCollection)
        .doc(eventId)
        .collection(_deploymentsCollection)
        .doc(deploymentId);
  }

  Future<void> _releaseMissionAndPromote({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> deploymentReference,
    required Map<String, dynamic> deploymentData,
    required String currentMissionId,
    required bool currentWasQueued,
    required String deploymentId,
  }) async {
    final state = RescueMissionQueueState.fromDeployment(deploymentData);
    final remainingEntries = state.queued
        .where((entry) => entry.missionId != currentMissionId)
        .toList();

    if (currentWasQueued) {
      for (var index = 0; index < remainingEntries.length; index++) {
        final entry = remainingEntries[index];
        transaction.update(_missionReference(entry), {
          'queuePosition': index + 1,
        });
      }

      final updatedState = RescueMissionQueueState(
        active: state.active,
        queued: remainingEntries,
      );
      transaction.update(deploymentReference, {
        ...updatedState.toFirestore(),
        'missionQueueUpdatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final validEntries = <RescueMissionQueueEntry>[];
    for (final entry in remainingEntries) {
      final missionSnapshot = await transaction.get(_missionReference(entry));
      final requestSnapshot = await transaction.get(
        _firestore.collection(_requestsCollection).doc(entry.requestId),
      );
      final missionData = missionSnapshot.data();
      final requestData = requestSnapshot.data();
      final status = (missionData?['missionStatus'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      final owner = (missionData?['deploymentId'] ?? '').toString().trim();
      final requestStatus = (requestData?['requestStatus'] ?? '')
          .toString()
          .trim()
          .toUpperCase();

      if (missionSnapshot.exists &&
          requestSnapshot.exists &&
          status == MissionStatus.queued &&
          owner == deploymentId &&
          requestStatus == EmergencyRequestStatus.accepted) {
        validEntries.add(entry);
      }
    }

    final promoted = validEntries.isEmpty ? null : validEntries.first;
    final newQueue = validEntries.skip(1).toList(growable: false);

    if (promoted != null) {
      transaction.update(_missionReference(promoted), {
        'missionStatus': MissionStatus.onTheWay,
        'missionStartDate': FieldValue.serverTimestamp(),
        'queuePosition': FieldValue.delete(),
      });
      transaction.update(
        _firestore.collection(_requestsCollection).doc(promoted.requestId),
        {'updatedAt': FieldValue.serverTimestamp()},
      );
    }

    for (var index = 0; index < newQueue.length; index++) {
      transaction.update(_missionReference(newQueue[index]), {
        'queuePosition': index + 1,
      });
    }

    final updatedState = RescueMissionQueueState(
      active: promoted,
      queued: newQueue,
    );
    transaction.update(deploymentReference, {
      ...updatedState.toFirestore(),
      'missionQueueUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  DocumentReference<Map<String, dynamic>> _missionReference(
    RescueMissionQueueEntry entry,
  ) {
    return _firestore
        .collection(_requestsCollection)
        .doc(entry.requestId)
        .collection(_missionsCollection)
        .doc(entry.missionId);
  }

  static void _validateRequestStatus(Map<String, dynamic> data) {
    final status = (data['requestStatus'] ?? '')
        .toString()
        .trim()
        .toUpperCase();

    if (status != EmergencyRequestStatus.accepted) {
      throw const RescueMissionRequestUnavailableException();
    }
  }

  static void _validateOwner(Map<String, dynamic> data, String deploymentId) {
    final storedDeploymentId = (data['deploymentId'] ?? '').toString().trim();

    if (storedDeploymentId != deploymentId) {
      throw const RescueMissionOwnerMismatchException();
    }
  }

  static void _validateCurrentMission({
    required Map<String, dynamic> deploymentData,
    required String missionId,
  }) {
    final storedActiveMissionId = (deploymentData['activeMissionId'] ?? '')
        .toString()
        .trim();
    if (storedActiveMissionId.isNotEmpty &&
        storedActiveMissionId != missionId) {
      throw const RescueMissionNotActiveException();
    }
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static int _affectedCountOf(Map<String, dynamic> requestData) {
    final value = requestData['affectedCount'];
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');

    // คำร้องเก่าก่อนเพิ่ม affectedCount ให้ถือเป็นผู้ประสบภัย 1 คน
    return parsed == null || parsed <= 0 ? 1 : parsed;
  }

  static String _firebaseMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'ไม่มีสิทธิ์แก้ไขภารกิจนี้';
      case 'unavailable':
        return 'ไม่สามารถเชื่อมต่อฐานข้อมูลได้ กรุณาลองใหม่อีกครั้ง';
      case 'aborted':
        return 'ข้อมูลภารกิจมีการเปลี่ยนแปลง กรุณาลองใหม่อีกครั้ง';
      default:
        return 'เกิดข้อผิดพลาดในการดำเนินการกับภารกิจ';
    }
  }
}

class _MissionReferences {
  const _MissionReferences({required this.request, required this.mission});

  final DocumentReference<Map<String, dynamic>> request;
  final DocumentReference<Map<String, dynamic>> mission;
}
