import 'emergency_request_model.dart';
import 'rescue_mission_model.dart';

class RescueMissionHistoryItem {
  const RescueMissionHistoryItem({
    required this.request,
    required this.mission,
    this.disasterEventName = '',
    this.victimName = '',
  });

  final EmergencyRequest request;
  final RescueMission mission;
  final String disasterEventName;
  final String victimName;

  DateTime? get completedAt =>
      mission.missionEndDate ?? mission.missionStartDate;

  bool get isSafetyConfirmed => request.safeStatus;

  String get displayDisasterEventName {
    final name = disasterEventName.trim();
    return name.isEmpty ? request.requestType : name;
  }

  String get displayVictimName {
    final name = victimName.trim();
    return name.isEmpty ? 'ไม่พบข้อมูลชื่อผู้ประสบภัย' : name;
  }
}

enum RescueMissionHistoryFilter { all, safetyConfirmed, awaitingSafety }

class RescueMissionHistoryDisasterOption {
  const RescueMissionHistoryDisasterOption({
    required this.eventId,
    required this.eventName,
    required this.disasterType,
  });

  final String eventId;
  final String eventName;
  final String disasterType;

  String get displayLabel {
    final type = disasterType.trim();
    final name = eventName.trim();

    if (type.isEmpty) return name;
    if (name.isEmpty || name == type) return type;
    return '$type — $name';
  }
}
