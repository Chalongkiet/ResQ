import 'package:cloud_firestore/cloud_firestore.dart';

class RescueVehicle {
  const RescueVehicle({
    required this.vehicleId,
    required this.vehiclePlate,
    required this.vehicleType,
    this.createdAt,
  });

  final String vehicleId;
  final String vehiclePlate;
  final String vehicleType;
  final DateTime? createdAt;

  factory RescueVehicle.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    final timestamp = data['createdAt'];

    return RescueVehicle(
      vehicleId: document.id,
      vehiclePlate: (data['vehiclePlate'] ?? '').toString(),
      vehicleType: (data['vehicleType'] ?? '').toString(),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}
