import 'package:cloud_firestore/cloud_firestore.dart';

class RescueDeployment {
  const RescueDeployment({
    required this.deploymentId,
    required this.rescueTeamId,
    required this.deploymentStatus,
    required this.latitude,
    required this.longitude,
    this.deploymentTime,
    this.leaveReason,
    this.leaveDetail,
    this.leaveImage,
  });

  final String deploymentId;

  /// Document ID ของ RescueOrganization
  final String rescueTeamId;

  final String deploymentStatus;

  final double latitude;
  final double longitude;

  final DateTime? deploymentTime;

  final String? leaveReason;
  final String? leaveDetail;
  final String? leaveImage;

  bool get isActive => deploymentStatus == 'ACTIVE';

  factory RescueDeployment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    final deploymentTime = data['deploymentTime'];

    final currentLocation = data['currentLocation'];

    double latitude = 0;
    double longitude = 0;

    if (currentLocation is GeoPoint) {
      latitude = currentLocation.latitude;
      longitude = currentLocation.longitude;
    }

    return RescueDeployment(
      deploymentId: (data['deploymentId'] ?? document.id).toString(),

      rescueTeamId: (data['rescueTeamId'] ?? '').toString(),

      deploymentStatus: (data['deploymentStatus'] ?? '').toString(),

      latitude: latitude,
      longitude: longitude,

      deploymentTime: deploymentTime is Timestamp
          ? deploymentTime.toDate()
          : null,

      leaveReason: _readNullableString(data['leaveReason']),

      leaveDetail: _readNullableString(data['leaveDetail']),

      leaveImage: _readNullableString(data['leaveImage']),
    );
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();

    return result.isEmpty ? null : result;
  }
}
