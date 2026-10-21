import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/emergency_request_status.dart';

class EmergencyRequest {
  const EmergencyRequest({
    required this.requestId,
    required this.userId,
    required this.disasterEventId,
    required this.requestType,
    required this.latitude,
    required this.longitude,
    required this.requestDetail,
    required this.requestStatus,
    required this.safeStatus,
    this.situationTags = const <String>[],
    this.affectedCount = 1,
    this.requestImage,
    this.safeImage,
    this.createdAt,
    this.updatedAt,
    this.cancelledAt,
    this.requestImagePublicId,
  });

  // ==================================================
  // Identity
  // ==================================================

  final String requestId;

  /// Firebase Anonymous UID ของผู้ประสบภัย
  final String userId;

  final String? requestImagePublicId;

  // ==================================================
  // Disaster Event
  // ==================================================

  /// Document ID จาก disasterEvents
  final String disasterEventId;

  /// ประเภทภัยที่ดึงมาจาก disasterEvents
  final String requestType;

  // ==================================================
  // Incident Location
  // ==================================================

  final double latitude;

  final double longitude;

  // ==================================================
  // Request Information
  // ==================================================

  final String requestDetail;

  /// รหัสสถานการณ์ที่ผู้ประสบภัยเลือกจากหน้า SOS
  /// เอกสารเก่าที่ไม่มี field นี้จะอ่านเป็นรายการว่าง
  final List<String> situationTags;

  /// จำนวนผู้ประสบภัยที่อยู่ในคำร้องนี้
  /// เอกสารเก่าที่ไม่มี field นี้จะอ่านเป็น 1 คน
  final int affectedCount;

  /// URL ของรูป
  final String? requestImage;

  // ==================================================
  // Status
  // ==================================================

  final String requestStatus;

  final bool safeStatus;

  final String? safeImage;

  // ==================================================
  // Timestamp
  // ==================================================

  final DateTime? createdAt;

  final DateTime? updatedAt;

  final DateTime? cancelledAt;

  // ==================================================
  // State Helpers
  // ==================================================

  bool get isWaiting {
    return requestStatus == EmergencyRequestStatus.waiting;
  }

  bool get isAccepted => requestStatus == EmergencyRequestStatus.accepted;

  bool get isCompleted => requestStatus == EmergencyRequestStatus.completed;

  bool get isCancelled {
    return requestStatus == EmergencyRequestStatus.cancelled;
  }

  bool get hasValidLocation {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  // ==================================================
  // Firestore
  // ==================================================

  factory EmergencyRequest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return EmergencyRequest(
      requestId: document.id,
      userId: _asString(data['userId']),
      disasterEventId: _asString(data['disasterEventId']),
      requestType: _asString(data['requestType']),
      latitude: _asDouble(data['latitude']),
      longitude: _asDouble(data['longitude']),
      requestDetail: _asString(data['requestDetail']),
      situationTags: _asStringList(data['situationTags']),
      affectedCount: _asPositiveInt(data['affectedCount']),
      requestImage: _asNullableString(data['requestImage']),
      requestStatus: _asString(data['requestStatus']),
      safeStatus: _asBool(data['safeStatus']),
      safeImage: _asNullableString(data['safeImage']),
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
      cancelledAt: _asDateTime(data['cancelledAt']),
      requestImagePublicId: _asNullableString(data['requestImagePublicId']),
    );
  }

  // ==================================================
  // Helpers
  // ==================================================

  static String _asString(dynamic value) {
    return value?.toString() ?? '';
  }

  static String? _asNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return text;
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    return false;
  }

  static int _asPositiveInt(dynamic value) {
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    return parsed == null || parsed <= 0 ? 1 : parsed;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  // ==================================================
  // Copy With
  // ==================================================

  EmergencyRequest copyWith({
    String? requestId,
    String? userId,
    String? disasterEventId,
    String? requestType,
    double? latitude,
    double? longitude,
    String? requestDetail,
    String? requestImage,
    String? requestStatus,
    bool? safeStatus,
    List<String>? situationTags,
    int? affectedCount,
    String? safeImage,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? cancelledAt,
    String? requestImagePublicId,
  }) {
    return EmergencyRequest(
      requestId: requestId ?? this.requestId,
      userId: userId ?? this.userId,
      disasterEventId: disasterEventId ?? this.disasterEventId,
      requestType: requestType ?? this.requestType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      requestDetail: requestDetail ?? this.requestDetail,
      requestImage: requestImage ?? this.requestImage,
      requestStatus: requestStatus ?? this.requestStatus,
      safeStatus: safeStatus ?? this.safeStatus,
      situationTags: situationTags ?? this.situationTags,
      affectedCount: affectedCount ?? this.affectedCount,
      safeImage: safeImage ?? this.safeImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      requestImagePublicId: requestImagePublicId ?? this.requestImagePublicId,
    );
  }
}
