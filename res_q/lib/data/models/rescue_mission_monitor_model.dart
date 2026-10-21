import 'emergency_request_model.dart';
import 'rescue_mission_model.dart';

class RescueMissionAssignment {
  const RescueMissionAssignment({required this.request, required this.mission});

  final EmergencyRequest request;
  final RescueMission mission;
}

class RescueMissionDeploymentInfo {
  const RescueMissionDeploymentInfo({
    required this.deploymentId,
    required this.rescueTeamId,
    required this.latitude,
    required this.longitude,
  });

  final String deploymentId;
  final String rescueTeamId;
  final double latitude;
  final double longitude;

  bool get hasValidLocation {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        !(latitude == 0 && longitude == 0);
  }
}

class RescueMissionMemberInfo {
  const RescueMissionMemberInfo({
    required this.memberId,
    required this.fullName,
    required this.phoneNumber,
    required this.position,
  });

  final String memberId;
  final String fullName;
  final String phoneNumber;
  final String position;
}

class RescueMissionVehicleInfo {
  const RescueMissionVehicleInfo({
    required this.vehicleId,
    required this.vehiclePlate,
    required this.vehicleType,
  });

  final String vehicleId;
  final String vehiclePlate;
  final String vehicleType;
}

class RescueMissionTeamInfo {
  const RescueMissionTeamInfo({
    required this.rescueTeamId,
    required this.teamName,
    required this.members,
    required this.vehicles,
  });

  final String rescueTeamId;
  final String teamName;
  final List<RescueMissionMemberInfo> members;
  final List<RescueMissionVehicleInfo> vehicles;
}
