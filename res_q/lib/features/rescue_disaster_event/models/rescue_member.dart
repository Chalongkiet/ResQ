import 'package:cloud_firestore/cloud_firestore.dart';

class RescueMember {
  const RescueMember({
    required this.memberId,
    required this.fullName,
    required this.phoneNumber,
    required this.position,
    this.createdAt,
  });

  final String memberId;
  final String fullName;
  final String phoneNumber;
  final String position;
  final DateTime? createdAt;

  factory RescueMember.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    final timestamp = data['createdAt'];

    return RescueMember(
      memberId: document.id,
      fullName: (data['fullName'] ?? '').toString(),
      phoneNumber: (data['phoneNumber'] ?? '').toString(),
      position: (data['position'] ?? '').toString(),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}
