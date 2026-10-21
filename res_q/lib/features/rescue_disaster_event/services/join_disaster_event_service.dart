import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/deployment_status.dart';
import '../models/rescue_deployment.dart';
import 'exceptions/join_disaster_event_exception.dart';

class JoinDisasterEventService {
  JoinDisasterEventService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ==================================================
  // Get Active Deployment
  // ==================================================

  Future<RescueDeployment?> getActiveDeployment({
    required String eventId,
    required String rescueTeamId,
  }) async {
    final normalizedEventId = eventId.trim();
    final normalizedTeamId = rescueTeamId.trim();

    if (normalizedEventId.isEmpty || normalizedTeamId.isEmpty) {
      return null;
    }

    debugPrint('[JOIN SERVICE] checking active deployment');

    debugPrint('[JOIN SERVICE] event=$normalizedEventId');

    debugPrint('[JOIN SERVICE] team=$normalizedTeamId');

    try {
      final snapshot = await _firestore
          .collection('disasterEvents')
          .doc(normalizedEventId)
          .collection('RescueTeam')
          .where('rescueTeamId', isEqualTo: normalizedTeamId)
          .where('deploymentStatus', isEqualTo: DeploymentStatus.active)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      debugPrint('[JOIN SERVICE] query completed');

      debugPrint('[JOIN SERVICE] found=${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final deployment = RescueDeployment.fromFirestore(snapshot.docs.first);

      debugPrint(
        '[JOIN SERVICE] ACTIVE deployment='
        '${deployment.deploymentId}',
      );

      return deployment;
    } catch (error, stackTrace) {
      debugPrint('[JOIN SERVICE] getActiveDeployment ERROR');

      debugPrint('[JOIN SERVICE] $error');

      debugPrint('[JOIN SERVICE] $stackTrace');

      rethrow;
    }
  }

  // ==================================================
  // Has Active Deployment
  // ==================================================

  Future<bool> hasActiveDeployment({
    required String eventId,
    required String rescueTeamId,
  }) async {
    final deployment = await getActiveDeployment(
      eventId: eventId,
      rescueTeamId: rescueTeamId,
    );

    return deployment != null;
  }

  // ==================================================
  // Join Disaster Event
  // ==================================================

  Future<RescueDeployment> join({
    required String eventId,
    required String rescueTeamId,
    required List<String> memberIds,
    required List<String> vehicleIds,
    required double latitude,
    required double longitude,
  }) async {
    final normalizedEventId = eventId.trim();

    final normalizedTeamId = rescueTeamId.trim();

    debugPrint('================================');

    debugPrint('[JOIN SERVICE] JOIN START');

    debugPrint('[JOIN SERVICE] event=$normalizedEventId');

    debugPrint('[JOIN SERVICE] team=$normalizedTeamId');

    // ==================================================
    // Validate IDs
    // ==================================================

    if (normalizedEventId.isEmpty) {
      throw const DisasterEventNotFoundException();
    }

    if (normalizedTeamId.isEmpty) {
      throw const RescueTeamNotFoundException();
    }

    // ==================================================
    // Normalize Resources
    // ==================================================

    final normalizedMemberIds = memberIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final normalizedVehicleIds = vehicleIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    debugPrint(
      '[JOIN SERVICE] members='
      '${normalizedMemberIds.length}',
    );

    debugPrint(
      '[JOIN SERVICE] vehicles='
      '${normalizedVehicleIds.length}',
    );

    // ==================================================
    // Validate Resources
    // ==================================================

    if (normalizedMemberIds.isEmpty) {
      throw const RescueResourceRequiredException(
        'กรุณาเลือกสมาชิกกู้ภัยอย่างน้อย 1 คน',
      );
    }

    if (normalizedVehicleIds.isEmpty) {
      throw const RescueResourceRequiredException(
        'กรุณาเลือกยานพาหนะอย่างน้อย 1 คัน',
      );
    }

    // ==================================================
    // Duplicate Protection
    // ==================================================

    debugPrint('[JOIN SERVICE] duplicate check...');

    final existingDeployment = await getActiveDeployment(
      eventId: normalizedEventId,
      rescueTeamId: normalizedTeamId,
    );

    if (existingDeployment != null) {
      debugPrint('[JOIN SERVICE] duplicate detected');

      throw const AlreadyJoinedDisasterEventException();
    }

    debugPrint('[JOIN SERVICE] no duplicate');

    // ==================================================
    // References
    // ==================================================

    final eventRef = _firestore
        .collection('disasterEvents')
        .doc(normalizedEventId);

    final organizationRef = _firestore
        .collection('RescueOrganization')
        .doc(normalizedTeamId);

    // ==================================================
    // Validate Disaster Event
    // ==================================================

    debugPrint('[JOIN SERVICE] validating disaster event...');

    final eventSnapshot = await eventRef.get().timeout(
      const Duration(seconds: 10),
    );

    if (!eventSnapshot.exists) {
      throw const DisasterEventNotFoundException();
    }

    final eventData = eventSnapshot.data();

    if (eventData == null) {
      throw const DisasterEventNotFoundException();
    }

    if (eventData['eventStatus'] != true) {
      throw const DisasterEventInactiveException();
    }

    debugPrint('[JOIN SERVICE] disaster event valid');

    // ==================================================
    // Validate Organization
    // ==================================================

    debugPrint('[JOIN SERVICE] validating rescue organization...');

    final organizationSnapshot = await organizationRef.get().timeout(
      const Duration(seconds: 10),
    );

    if (!organizationSnapshot.exists) {
      throw const RescueTeamNotFoundException();
    }

    debugPrint('[JOIN SERVICE] rescue organization valid');

    // ==================================================
    // Create Deployment
    // ==================================================

    final deploymentRef = eventRef.collection('RescueTeam').doc();

    final deploymentId = deploymentRef.id;

    debugPrint('[JOIN SERVICE] deploymentId=$deploymentId');

    final batch = _firestore.batch();

    // ==================================================
    // Deployment
    // ==================================================

    batch.set(deploymentRef, {
      'deploymentId': deploymentId,

      'deploymentStatus': DeploymentStatus.active,

      'deploymentTime': FieldValue.serverTimestamp(),

      'leaveReason': null,

      'leaveDetail': null,

      'leaveImage': null,

      'currentLocation': GeoPoint(latitude, longitude),

      'rescueTeamId': normalizedTeamId,

      'activeMissionRequestId': null,

      'activeMissionId': null,

      'missionQueue': const <Map<String, dynamic>>[],
    });

    // ==================================================
    // Members
    // ==================================================

    for (final memberId in normalizedMemberIds) {
      final memberRef = deploymentRef.collection('DeploymentMember').doc();

      batch.set(memberRef, {
        'deploymentMemberId': memberRef.id,

        'memberId': memberId,
      });
    }

    // ==================================================
    // Vehicles
    // ==================================================

    for (final vehicleId in normalizedVehicleIds) {
      final vehicleRef = deploymentRef.collection('DeploymentVehicle').doc();

      batch.set(vehicleRef, {
        'deploymentVehicleId': vehicleRef.id,

        'vehicleId': vehicleId,
      });
    }

    // ==================================================
    // Organization Online
    // ==================================================

    batch.update(organizationRef, {'operationalStatus': true});

    // ==================================================
    // Commit
    // ==================================================

    debugPrint('[JOIN SERVICE] committing batch...');

    try {
      await batch.commit().timeout(const Duration(seconds: 15));
    } catch (error, stackTrace) {
      debugPrint('[JOIN SERVICE] batch commit ERROR');

      debugPrint('[JOIN SERVICE] $error');

      debugPrint('[JOIN SERVICE] $stackTrace');

      throw const JoinDisasterEventException(
        'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง',
      );
    }

    debugPrint('[JOIN SERVICE] batch committed');

    // ==================================================
    // Load Saved Deployment
    // ==================================================

    final saved = await deploymentRef.get().timeout(
      const Duration(seconds: 10),
    );

    if (!saved.exists) {
      throw const JoinDisasterEventException(
        'สร้างข้อมูลการเข้าร่วมสำเร็จ '
        'แต่ไม่สามารถโหลดข้อมูลกลับมาได้',
      );
    }

    final deployment = RescueDeployment.fromFirestore(saved);

    debugPrint('[JOIN SERVICE] JOIN SUCCESS');

    debugPrint(
      '[JOIN SERVICE] deployment='
      '${deployment.deploymentId}',
    );

    debugPrint('================================');

    return deployment;
  }
}
