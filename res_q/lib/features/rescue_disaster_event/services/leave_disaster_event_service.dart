import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/deployment_status.dart';

import 'exceptions/leave_disaster_event_exception.dart';

class LeaveDisasterEventService {
  LeaveDisasterEventService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ==================================================
  // Collection Names
  // ==================================================

  static const String _disasterEventsCollection = 'disasterEvents';

  static const String _rescueTeamSubCollection = 'RescueTeam';

  static const String _rescueOrganizationCollection = 'RescueOrganization';

  // ==================================================
  // Leave Disaster Event
  // ==================================================

  Future<void> leave({
    required String eventId,
    required String deploymentId,
    required String rescueTeamId,
    required String leaveReason,
    String? leaveDetail,
    required String leaveImageUrl,
  }) async {
    // ==================================================
    // Normalize
    // ==================================================

    final normalizedEventId = eventId.trim();

    final normalizedDeploymentId = deploymentId.trim();

    final normalizedTeamId = rescueTeamId.trim();

    final normalizedReason = leaveReason.trim();

    final normalizedDetail = _normalizeOptional(leaveDetail);

    final normalizedImageUrl = leaveImageUrl.trim();

    // ==================================================
    // Validate IDs
    // ==================================================

    if (normalizedEventId.isEmpty || normalizedDeploymentId.isEmpty) {
      throw const LeaveDeploymentNotFoundException();
    }

    if (normalizedTeamId.isEmpty) {
      throw const LeaveOrganizationNotFoundException();
    }

    // ==================================================
    // Validate Reason
    // ==================================================

    if (normalizedReason.isEmpty) {
      throw const LeaveReasonRequiredException();
    }

    if (normalizedReason.length > 255) {
      throw const LeaveReasonTooLongException();
    }

    // ==================================================
    // Validate Detail
    // ==================================================

    if (normalizedDetail != null && normalizedDetail.length > 255) {
      throw const LeaveDetailTooLongException();
    }

    // ==================================================
    // Validate Image
    //
    // ณ จุดนี้รูปต้อง Upload สำเร็จแล้ว
    // Service นี้รับ URL เท่านั้น
    // ==================================================

    if (normalizedImageUrl.isEmpty) {
      throw const LeaveImageRequiredException();
    }

    // ==================================================
    // Firestore References
    // ==================================================

    final deploymentReference = _firestore
        .collection(_disasterEventsCollection)
        .doc(normalizedEventId)
        .collection(_rescueTeamSubCollection)
        .doc(normalizedDeploymentId);

    final organizationReference = _firestore
        .collection(_rescueOrganizationCollection)
        .doc(normalizedTeamId);

    debugPrint('================================');

    debugPrint('[LEAVE EVENT] START');

    debugPrint(
      '[LEAVE EVENT] '
      'event=$normalizedEventId',
    );

    debugPrint(
      '[LEAVE EVENT] '
      'deployment=$normalizedDeploymentId',
    );

    debugPrint(
      '[LEAVE EVENT] '
      'team=$normalizedTeamId',
    );

    try {
      // ==================================================
      // Transaction
      //
      // Deployment + Organization ต้องสำเร็จพร้อมกัน
      // ==================================================

      await _firestore.runTransaction((transaction) async {
        // ==================================================
        // Read Current Deployment
        // ==================================================

        final deploymentSnapshot = await transaction.get(deploymentReference);

        if (!deploymentSnapshot.exists) {
          throw const LeaveDeploymentNotFoundException();
        }

        final deploymentData =
            deploymentSnapshot.data() ?? const <String, dynamic>{};

        // ==================================================
        // Validate Deployment Owner
        // ==================================================

        final storedTeamId = deploymentData['rescueTeamId']?.toString().trim();

        if (storedTeamId == null ||
            storedTeamId.isEmpty ||
            storedTeamId != normalizedTeamId) {
          throw const LeaveDeploymentOwnerMismatchException();
        }

        // ==================================================
        // Validate Current Status
        // ==================================================

        final currentStatus = deploymentData['deploymentStatus']
            ?.toString()
            .trim()
            .toUpperCase();

        if (currentStatus != DeploymentStatus.active) {
          debugPrint(
            '[LEAVE EVENT] '
            'invalid status=$currentStatus',
          );

          throw const LeaveDeploymentNotActiveException();
        }

        final activeMissionId = (deploymentData['activeMissionId'] ?? '')
            .toString()
            .trim();
        final missionQueue = deploymentData['missionQueue'];
        if (activeMissionId.isNotEmpty ||
            (missionQueue is Iterable && missionQueue.isNotEmpty)) {
          throw const LeaveDeploymentHasMissionsException();
        }

        // ==================================================
        // Read Organization
        // ==================================================

        final organizationSnapshot = await transaction.get(
          organizationReference,
        );

        if (!organizationSnapshot.exists) {
          throw const LeaveOrganizationNotFoundException();
        }

        // ==================================================
        // Update Deployment
        //
        // ACTIVE → LEFT
        // ==================================================

        transaction.update(deploymentReference, {
          'deploymentStatus': DeploymentStatus.left,

          'leaveReason': normalizedReason,

          'leaveDetail': normalizedDetail,

          'leaveImage': normalizedImageUrl,
        });

        // ==================================================
        // Update Organization
        //
        // Online → Offline
        // ==================================================

        transaction.update(organizationReference, {'operationalStatus': false});
      });

      // ==================================================
      // Success
      // ==================================================

      debugPrint('[LEAVE EVENT] SUCCESS');
    } on LeaveDisasterEventException {
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('[LEAVE EVENT] FIREBASE ERROR');

      debugPrint(
        '[LEAVE EVENT] '
        '${error.code}: ${error.message}',
      );

      debugPrint('[LEAVE EVENT] $stackTrace');

      throw LeaveDisasterEventException(
        _firebaseErrorMessage(error),
        code: error.code,
      );
    } catch (error, stackTrace) {
      debugPrint('[LEAVE EVENT] UNKNOWN ERROR');

      debugPrint('[LEAVE EVENT] $error');

      debugPrint('[LEAVE EVENT] $stackTrace');

      throw const LeaveDisasterEventException(
        'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง',
        code: 'leave-unknown-error',
      );
    } finally {
      debugPrint('[LEAVE EVENT] FINISHED');

      debugPrint('================================');
    }
  }

  // ==================================================
  // Normalize Optional
  // ==================================================

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  // ==================================================
  // Firebase Message
  // ==================================================

  static String _firebaseErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'ไม่มีสิทธิ์ถอนกำลังจากเหตุการณ์นี้';

      case 'unavailable':
        return 'ไม่สามารถเชื่อมต่อฐานข้อมูลได้ กรุณาลองใหม่อีกครั้ง';

      case 'deadline-exceeded':
        return 'การเชื่อมต่อใช้เวลานานเกินไป กรุณาลองใหม่';

      case 'cancelled':
        return 'การถอนกำลังถูกยกเลิก';

      default:
        return 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
    }
  }
}
