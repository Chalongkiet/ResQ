import 'package:cloud_firestore/cloud_firestore.dart';

class RescueMission {
  const RescueMission({
    required this.missionId,
    required this.missionName,
    required this.missionStatus,
    required this.deploymentId,
    this.missionAcceptedDate,
    this.missionStartDate,
    this.queuePosition,
    this.missionEndDate,
    this.missionResult,
    this.totalAffected,
    this.proofImage,
    this.safeLocationName,
    this.cancelReason,
    this.cancelDetail,
    this.cancelImage,
  });

  // ==================================================
  // Identity
  // ==================================================

  final String missionId;

  final String missionName;

  // ==================================================
  // Status
  // ==================================================

  final String missionStatus;

  // ==================================================
  // Deployment
  // ==================================================

  /// deploymentId ของ Rescue Team ที่รับ Mission นี้
  final String deploymentId;

  // ==================================================
  // Mission Lifecycle
  // ==================================================

  /// เวลาที่ทีมกู้ภัยรับคำร้อง ไม่ว่ารับเป็นงานปัจจุบันหรือเข้าคิว
  final DateTime? missionAcceptedDate;

  final DateTime? missionStartDate;

  /// ลำดับคิว เริ่มจาก 1 และเป็น null เมื่อเริ่มปฏิบัติภารกิจแล้ว
  final int? queuePosition;

  final DateTime? missionEndDate;

  // ==================================================
  // Mission Result
  // ==================================================

  /// ผลลัพธ์ภารกิจ: PENDING ระหว่างดำเนินงาน และ SUCCESS เมื่อจบสำเร็จ
  final String? missionResult;

  /// จำนวนผู้ประสบภัยที่ช่วยเหลือจริง
  ///
  /// คัดลอกจากจำนวนผู้ประสบภัยในคำร้องเมื่อ Complete Mission
  final int? totalAffected;

  final String? proofImage;

  /// ชื่อจุดปลอดภัย / จุดอพยพ
  ///
  /// ระบุเมื่อปิดภารกิจ
  final String? safeLocationName;

  // ==================================================
  // Cancellation
  // ==================================================

  final String? cancelReason;

  final String? cancelDetail;

  final String? cancelImage;

  // ==================================================
  // Firestore
  // ==================================================

  factory RescueMission.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return RescueMission(
      missionId: (data['missionId'] ?? document.id).toString().trim(),

      missionName: (data['missionName'] ?? '').toString().trim(),

      missionStatus: (data['missionStatus'] ?? '').toString().trim(),

      deploymentId: (data['deploymentId'] ?? '').toString().trim(),

      missionAcceptedDate: _readDateTime(data['missionAcceptedDate']),

      missionStartDate: _readDateTime(data['missionStartDate']),

      queuePosition: _readNullableInt(data['queuePosition']),

      missionEndDate: _readDateTime(data['missionEndDate']),

      missionResult: _readNullableString(data['missionResult']),

      totalAffected: _readNullableInt(data['totalAffected']),

      proofImage: _readNullableString(data['proofImage']),

      safeLocationName: _readNullableString(data['safeLocationName']),

      cancelReason: _readNullableString(data['cancelReason']),

      cancelDetail: _readNullableString(data['cancelDetail']),

      cancelImage: _readNullableString(data['cancelImage']),
    );
  }

  RescueMission copyWith({
    String? missionStatus,
    int? queuePosition,
    bool clearQueuePosition = false,
  }) {
    return RescueMission(
      missionId: missionId,
      missionName: missionName,
      missionStatus: missionStatus ?? this.missionStatus,
      deploymentId: deploymentId,
      missionAcceptedDate: missionAcceptedDate,
      missionStartDate: missionStartDate,
      queuePosition: clearQueuePosition
          ? null
          : queuePosition ?? this.queuePosition,
      missionEndDate: missionEndDate,
      missionResult: missionResult,
      totalAffected: totalAffected,
      proofImage: proofImage,
      safeLocationName: safeLocationName,
      cancelReason: cancelReason,
      cancelDetail: cancelDetail,
      cancelImage: cancelImage,
    );
  }

  // ==================================================
  // Helpers
  // ==================================================

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();

    return result.isEmpty ? null : result;
  }

  static int? _readNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }
}
