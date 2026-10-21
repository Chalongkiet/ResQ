import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/mission_status.dart';
import '../models/emergency_request_model.dart';
import '../models/rescue_mission_history_item.dart';
import '../models/rescue_mission_model.dart';

class RescueMissionHistoryService {
  RescueMissionHistoryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _eventsCollection = 'disasterEvents';
  static const String _emergencyInfoCollection = 'emergencyInfos';
  static const String _deploymentsCollection = 'RescueTeam';
  static const String _missionsCollection = 'RescueMission';

  /// โหลดภารกิจที่เสร็จสิ้นของทีมกู้ภัยทุก deployment
  ///
  /// ใช้ index collection-group ของ RescueMission.deploymentId ที่มีอยู่แล้ว
  /// และกรอง COMPLETED ในแอป จึงไม่เพิ่ม composite index ใหม่.
  Future<List<RescueMissionHistoryItem>> loadCompletedForRescueTeam(
    String rescueTeamId,
  ) async {
    final normalizedTeamId = rescueTeamId.trim();
    if (normalizedTeamId.isEmpty) {
      return const <RescueMissionHistoryItem>[];
    }

    try {
      final eventSnapshots = await _firestore
          .collection(_eventsCollection)
          .get();
      final eventNamesById = <String, String>{
        for (final event in eventSnapshots.docs)
          event.id: (event.data()['eventName'] ?? '').toString().trim(),
      };
      final deploymentsByEvent = await Future.wait(
        eventSnapshots.docs.map(
          (event) => event.reference
              .collection(_deploymentsCollection)
              .where('rescueTeamId', isEqualTo: normalizedTeamId)
              .get(),
        ),
      );
      final deploymentIds = deploymentsByEvent
          .expand((snapshot) => snapshot.docs)
          .map((document) => document.id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      if (deploymentIds.isEmpty) {
        return const <RescueMissionHistoryItem>[];
      }

      final missionSnapshots = await Future.wait(
        deploymentIds.map(
          (deploymentId) => _firestore
              .collectionGroup(_missionsCollection)
              .where('deploymentId', isEqualTo: deploymentId)
              .get(),
        ),
      );
      final missionDocuments = missionSnapshots
          .expand((snapshot) => snapshot.docs)
          .where(
            (document) =>
                document.data()['missionStatus']?.toString().trim() ==
                MissionStatus.completed,
          );

      final victimNameFutures = <String, Future<String>>{};
      final assignments = await Future.wait(
        missionDocuments.map((missionDocument) async {
          final requestReference = missionDocument.reference.parent.parent;
          if (requestReference == null) return null;

          final requestSnapshot = await requestReference.get();
          if (!requestSnapshot.exists) return null;

          final request = EmergencyRequest.fromFirestore(requestSnapshot);
          final userId = request.userId.trim();
          final victimName = await victimNameFutures.putIfAbsent(
            userId,
            () => _loadVictimName(userId),
          );

          return RescueMissionHistoryItem(
            request: request,
            mission: RescueMission.fromFirestore(missionDocument),
            disasterEventName:
                eventNamesById[request.disasterEventId] ?? request.requestType,
            victimName: victimName,
          );
        }),
      );

      return sortNewestFirst(assignments.whereType<RescueMissionHistoryItem>());
    } on FirebaseException catch (error) {
      throw RescueMissionHistoryException(_firebaseMessage(error));
    }
  }

  Future<String> _loadVictimName(String userId) async {
    if (userId.isEmpty) {
      return '';
    }

    try {
      final snapshot = await _firestore
          .collection(_emergencyInfoCollection)
          .doc(userId)
          .get();
      return (snapshot.data()?['fullName'] ?? '').toString().trim();
    } on FirebaseException {
      // ชื่อเป็นข้อมูลประกอบ การโหลดไม่สำเร็จต้องไม่ปิดกั้นประวัติภารกิจ
      return '';
    }
  }

  static List<RescueMissionHistoryItem> filter(
    Iterable<RescueMissionHistoryItem> items,
    RescueMissionHistoryFilter selectedFilter,
  ) {
    return switch (selectedFilter) {
      RescueMissionHistoryFilter.all => List.of(items),
      RescueMissionHistoryFilter.safetyConfirmed =>
        items.where((item) => item.isSafetyConfirmed).toList(growable: false),
      RescueMissionHistoryFilter.awaitingSafety =>
        items.where((item) => !item.isSafetyConfirmed).toList(growable: false),
    };
  }

  static List<RescueMissionHistoryItem> filterByPeriodAndDisaster(
    Iterable<RescueMissionHistoryItem> items, {
    int? year,
    int? month,
    String? disasterEventId,
  }) {
    final normalizedEventId = disasterEventId?.trim();

    return items
        .where((item) {
          final completedAt = item.completedAt;

          if (year != null && completedAt?.year != year) {
            return false;
          }
          if (month != null && completedAt?.month != month) {
            return false;
          }
          if (normalizedEventId != null &&
              normalizedEventId.isNotEmpty &&
              item.request.disasterEventId != normalizedEventId) {
            return false;
          }

          return true;
        })
        .toList(growable: false);
  }

  static int totalSafetyConfirmedAffected(
    Iterable<RescueMissionHistoryItem> items,
  ) {
    return items.where((item) => item.isSafetyConfirmed).fold<int>(0, (
      total,
      item,
    ) {
      final missionTotal = item.mission.totalAffected;
      final affected = missionTotal != null && missionTotal > 0
          ? missionTotal
          : item.request.affectedCount;
      return total + affected;
    });
  }

  static List<RescueMissionHistoryItem> sortNewestFirst(
    Iterable<RescueMissionHistoryItem> items,
  ) {
    final result = List<RescueMissionHistoryItem>.of(items);
    result.sort((a, b) {
      final aDate = a.completedAt;
      final bDate = b.completedAt;
      if (aDate == null && bDate == null) {
        return b.mission.missionId.compareTo(a.mission.missionId);
      }
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return result;
  }

  static String _firebaseMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'ไม่มีสิทธิ์ดูประวัติภารกิจ';
      case 'unavailable':
        return 'ไม่สามารถเชื่อมต่อฐานข้อมูลได้ กรุณาลองใหม่อีกครั้ง';
      case 'failed-precondition':
        return 'ยังไม่ได้ตั้งค่า Firestore index สำหรับประวัติภารกิจ';
      default:
        return 'ไม่สามารถโหลดประวัติภารกิจได้';
    }
  }
}

class RescueMissionHistoryException implements Exception {
  const RescueMissionHistoryException(this.message);

  final String message;
}
