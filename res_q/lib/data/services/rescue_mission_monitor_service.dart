import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/mission_status.dart';
import '../models/emergency_request_model.dart';
import '../models/rescue_mission_model.dart';
import '../models/rescue_mission_monitor_model.dart';

class RescueMissionMonitorService {
  RescueMissionMonitorService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _requestsCollection = 'emergencyRequests';
  static const String _missionsCollection = 'RescueMission';
  static const String _eventsCollection = 'disasterEvents';
  static const String _deploymentsCollection = 'RescueTeam';
  static const String _organizationsCollection = 'RescueOrganization';

  Stream<RescueMission?> watchMissionForRequest(String requestId) {
    final normalizedRequestId = requestId.trim();

    if (normalizedRequestId.isEmpty) {
      return Stream<RescueMission?>.value(null);
    }

    return _firestore
        .collection(_requestsCollection)
        .doc(normalizedRequestId)
        .collection(_missionsCollection)
        .snapshots()
        .map((snapshot) {
          final missions = snapshot.docs
              .map(RescueMission.fromFirestore)
              .where(
                (mission) => MissionStatus.isAssigned(mission.missionStatus),
              )
              .toList();

          if (missions.isEmpty) {
            return null;
          }

          missions.sort(_compareMissionsNewestFirst);
          return missions.first;
        });
  }

  /// โหลดภารกิจที่ถูกยกเลิกทั้งหมดของคำร้อง เรียงจากล่าสุดไปเก่าสุด
  /// โดยอ่านเฉพาะ subcollection ของคำร้องนั้นและไม่ต้องใช้ collection-group
  /// index เพิ่มเติม
  Future<List<RescueMission>> loadCancelledMissions(String requestId) async {
    final normalizedRequestId = requestId.trim();

    if (normalizedRequestId.isEmpty) {
      return const <RescueMission>[];
    }

    final snapshot = await _firestore
        .collection(_requestsCollection)
        .doc(normalizedRequestId)
        .collection(_missionsCollection)
        .where('missionStatus', isEqualTo: MissionStatus.cancelled)
        .get();

    final missions = snapshot.docs.map(RescueMission.fromFirestore).toList();

    missions.sort(_compareCancelledMissionsNewestFirst);
    return List<RescueMission>.unmodifiable(missions);
  }

  /// คง method เดิมไว้สำหรับจุดที่ต้องการเฉพาะรายการล่าสุด
  Future<RescueMission?> loadLatestCancelledMission(String requestId) async {
    final missions = await loadCancelledMissions(requestId);
    return missions.isEmpty ? null : missions.first;
  }

  /// โหลดชื่อหน่วยกู้ภัยเจ้าของ deployment โดยไม่โหลดสมาชิกหรือยานพาหนะ
  /// ใช้สำหรับข้อมูลประกอบของภารกิจที่ยกเลิกก่อนหน้า
  Future<String?> loadTeamNameForDeployment({
    required String disasterEventId,
    required String deploymentId,
  }) async {
    final eventId = disasterEventId.trim();
    final normalizedDeploymentId = deploymentId.trim();

    if (eventId.isEmpty || normalizedDeploymentId.isEmpty) {
      return null;
    }

    final deploymentSnapshot = await _firestore
        .collection(_eventsCollection)
        .doc(eventId)
        .collection(_deploymentsCollection)
        .doc(normalizedDeploymentId)
        .get();
    final rescueTeamId = deploymentSnapshot
        .data()?['rescueTeamId']
        ?.toString()
        .trim();

    if (!deploymentSnapshot.exists ||
        rescueTeamId == null ||
        rescueTeamId.isEmpty) {
      return null;
    }

    final organizationSnapshot = await _firestore
        .collection(_organizationsCollection)
        .doc(rescueTeamId)
        .get();
    final teamName = organizationSnapshot
        .data()?['rescueTeamName']
        ?.toString()
        .trim();

    return teamName == null || teamName.isEmpty ? null : teamName;
  }

  Stream<List<RescueMissionAssignment>> watchAssignmentsForDeployment(
    String deploymentId,
  ) {
    final normalizedDeploymentId = deploymentId.trim();

    if (normalizedDeploymentId.isEmpty) {
      return Stream<List<RescueMissionAssignment>>.value(
        const <RescueMissionAssignment>[],
      );
    }

    return _firestore
        .collectionGroup(_missionsCollection)
        .where('deploymentId', isEqualTo: normalizedDeploymentId)
        .snapshots()
        .asyncMap((snapshot) async {
          final assignedMissionDocuments = snapshot.docs.where((document) {
            final status = document.data()['missionStatus']?.toString().trim();
            return status != null && MissionStatus.isAssigned(status);
          }).toList();

          final assignments = await Future.wait(
            assignedMissionDocuments.map((missionDocument) async {
              final requestReference = missionDocument.reference.parent.parent;

              if (requestReference == null) {
                return null;
              }

              final requestSnapshot = await requestReference.get();

              if (!requestSnapshot.exists) {
                return null;
              }

              return RescueMissionAssignment(
                // missionStatus ที่ยัง Active เป็น source of truth ของ
                // Mission Mode ฝั่งกู้ภัย ไม่ควรกรองซ้ำด้วย requestStatus
                // จาก parent document เพราะ get() อาจคืน cache ก่อน
                // WAITING -> ACCEPTED แล้วทำให้ mission ถูกทิ้งถาวร
                request: EmergencyRequest.fromFirestore(requestSnapshot),
                mission: RescueMission.fromFirestore(missionDocument),
              );
            }),
          );

          final result = assignments
              .whereType<RescueMissionAssignment>()
              .toList();

          result.sort(_compareAssignments);

          return result;
        });
  }

  Stream<RescueMissionDeploymentInfo?> watchDeployment({
    required String disasterEventId,
    required String deploymentId,
  }) {
    final eventId = disasterEventId.trim();
    final normalizedDeploymentId = deploymentId.trim();

    if (eventId.isEmpty || normalizedDeploymentId.isEmpty) {
      return Stream<RescueMissionDeploymentInfo?>.value(null);
    }

    return _firestore
        .collection(_eventsCollection)
        .doc(eventId)
        .collection(_deploymentsCollection)
        .doc(normalizedDeploymentId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();

          if (!snapshot.exists || data == null) {
            return null;
          }

          final location = data['currentLocation'];
          final latitude = location is GeoPoint ? location.latitude : 0.0;
          final longitude = location is GeoPoint ? location.longitude : 0.0;

          return RescueMissionDeploymentInfo(
            deploymentId: snapshot.id,
            rescueTeamId: (data['rescueTeamId'] ?? '').toString().trim(),
            latitude: latitude,
            longitude: longitude,
          );
        });
  }

  Future<void> updateDeploymentLocation({
    required String disasterEventId,
    required String deploymentId,
    required double latitude,
    required double longitude,
  }) async {
    final eventId = disasterEventId.trim();
    final normalizedDeploymentId = deploymentId.trim();

    if (eventId.isEmpty ||
        normalizedDeploymentId.isEmpty ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return;
    }

    await _firestore
        .collection(_eventsCollection)
        .doc(eventId)
        .collection(_deploymentsCollection)
        .doc(normalizedDeploymentId)
        .update({'currentLocation': GeoPoint(latitude, longitude)});
  }

  Future<RescueMissionTeamInfo> loadTeamInfo({
    required String disasterEventId,
    required String deploymentId,
    required String rescueTeamId,
  }) async {
    final eventId = disasterEventId.trim();
    final normalizedDeploymentId = deploymentId.trim();
    final teamId = rescueTeamId.trim();

    if (eventId.isEmpty || normalizedDeploymentId.isEmpty || teamId.isEmpty) {
      return RescueMissionTeamInfo(
        rescueTeamId: teamId,
        teamName: 'ทีมกู้ภัย',
        members: const <RescueMissionMemberInfo>[],
        vehicles: const <RescueMissionVehicleInfo>[],
      );
    }

    final deploymentReference = _firestore
        .collection(_eventsCollection)
        .doc(eventId)
        .collection(_deploymentsCollection)
        .doc(normalizedDeploymentId);
    final organizationReference = _firestore
        .collection(_organizationsCollection)
        .doc(teamId);

    final results = await Future.wait<Object>([
      organizationReference.get(),
      deploymentReference.collection('DeploymentMember').get(),
      deploymentReference.collection('DeploymentVehicle').get(),
    ]);

    final organizationSnapshot =
        results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final deploymentMembers = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final deploymentVehicles =
        results[2] as QuerySnapshot<Map<String, dynamic>>;

    final teamName = organizationSnapshot
        .data()?['rescueTeamName']
        ?.toString()
        .trim();

    final memberIds = deploymentMembers.docs
        .map((document) => document.data()['memberId']?.toString().trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final vehicleIds = deploymentVehicles.docs
        .map((document) => document.data()['vehicleId']?.toString().trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final memberSnapshots = await Future.wait(
      memberIds.map(
        (id) =>
            organizationReference.collection('RescueTeamMember').doc(id).get(),
      ),
    );
    final vehicleSnapshots = await Future.wait(
      vehicleIds.map(
        (id) => organizationReference.collection('Vehicles').doc(id).get(),
      ),
    );

    final members = memberSnapshots.where((snapshot) => snapshot.exists).map((
      snapshot,
    ) {
      final data = snapshot.data() ?? const <String, dynamic>{};
      return RescueMissionMemberInfo(
        memberId: snapshot.id,
        fullName: (data['fullName'] ?? '').toString().trim(),
        phoneNumber: (data['phoneNumber'] ?? '').toString().trim(),
        position: (data['position'] ?? '').toString().trim(),
      );
    }).toList()..sort((a, b) => a.fullName.compareTo(b.fullName));

    final vehicles = vehicleSnapshots.where((snapshot) => snapshot.exists).map((
      snapshot,
    ) {
      final data = snapshot.data() ?? const <String, dynamic>{};
      return RescueMissionVehicleInfo(
        vehicleId: snapshot.id,
        vehiclePlate: (data['vehiclePlate'] ?? '').toString().trim(),
        vehicleType: (data['vehicleType'] ?? '').toString().trim(),
      );
    }).toList()..sort((a, b) => a.vehiclePlate.compareTo(b.vehiclePlate));

    return RescueMissionTeamInfo(
      rescueTeamId: teamId,
      teamName: teamName == null || teamName.isEmpty ? 'ทีมกู้ภัย' : teamName,
      members: members,
      vehicles: vehicles,
    );
  }

  static int _compareMissionsNewestFirst(RescueMission a, RescueMission b) {
    final aDate = a.missionAcceptedDate ?? a.missionStartDate;
    final bDate = b.missionAcceptedDate ?? b.missionStartDate;

    if (aDate == null && bDate == null) {
      return b.missionId.compareTo(a.missionId);
    }
    if (aDate == null) {
      return 1;
    }
    if (bDate == null) {
      return -1;
    }
    return bDate.compareTo(aDate);
  }

  static int _compareCancelledMissionsNewestFirst(
    RescueMission a,
    RescueMission b,
  ) {
    final aDate =
        a.missionEndDate ?? a.missionAcceptedDate ?? a.missionStartDate;
    final bDate =
        b.missionEndDate ?? b.missionAcceptedDate ?? b.missionStartDate;

    if (aDate == null && bDate == null) {
      return b.missionId.compareTo(a.missionId);
    }
    if (aDate == null) {
      return 1;
    }
    if (bDate == null) {
      return -1;
    }
    return bDate.compareTo(aDate);
  }

  static int _compareAssignments(
    RescueMissionAssignment first,
    RescueMissionAssignment second,
  ) {
    final firstIsActive = MissionStatus.isActive(first.mission.missionStatus);
    final secondIsActive = MissionStatus.isActive(second.mission.missionStatus);
    if (firstIsActive != secondIsActive) return firstIsActive ? -1 : 1;

    if (!firstIsActive) {
      final positionComparison = (first.mission.queuePosition ?? 1 << 20)
          .compareTo(second.mission.queuePosition ?? 1 << 20);
      if (positionComparison != 0) return positionComparison;
    }

    return _compareMissionsNewestFirst(first.mission, second.mission);
  }
}
