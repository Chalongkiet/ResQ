import 'package:cloud_firestore/cloud_firestore.dart';

import 'disaster_boundary_point.dart';

class DisasterEvent {
  const DisasterEvent({
    required this.id,
    required this.eventName,
    required this.disasterType,
    required this.areaDescription,
    required this.eventDetail,
    required this.eventStartDate,
    required this.eventEndDate,
    required this.eventStatus,
    required this.disasterBoundary,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Firestore Document ID
  final String id;

  final String eventName;
  final String disasterType;
  final String areaDescription;
  final String eventDetail;

  final DateTime eventStartDate;
  final DateTime? eventEndDate;

  final bool eventStatus;

  final List<DisasterBoundaryPoint> disasterBoundary;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => eventStatus;

  bool get hasValidBoundary {
    // Polygon ต้องมีอย่างน้อย 3 จุด
    if (disasterBoundary.length < 3) {
      return false;
    }

    // ทุกจุดต้องเป็นพิกัดที่ถูกต้อง
    final everyPointIsValid = disasterBoundary.every(
      (point) => point.isValidCoordinate,
    );

    if (!everyPointIsValid) {
      return false;
    }

    // ต้องมีอย่างน้อย 3 พิกัดที่ไม่ซ้ำกัน
    final uniquePoints = disasterBoundary
        .map((point) => '${point.latitude},${point.longitude}')
        .toSet();

    return uniquePoints.length >= 3;
  }

  factory DisasterEvent.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw const FormatException('Disaster event document has no data');
    }

    return DisasterEvent.fromMap(id: document.id, data: data);
  }

  factory DisasterEvent.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final rawBoundary = data['disasterBoundary'];

    if (rawBoundary is! List) {
      throw const FormatException('disasterBoundary must be a List');
    }

    final boundary = rawBoundary
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid disasterBoundary item');
          }

          return DisasterBoundaryPoint.fromMap(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);

    return DisasterEvent(
      id: id,
      eventName: _requiredString(data, 'eventName'),
      disasterType: _requiredString(data, 'disasterType'),
      areaDescription: _requiredString(data, 'areaDescription'),
      eventDetail: _optionalString(data, 'eventDetail'),
      eventStartDate: _requiredDate(data, 'eventStartDate'),
      eventEndDate: _nullableDate(data['eventEndDate']),
      eventStatus: _requiredBool(data, 'eventStatus'),
      disasterBoundary: boundary,
      createdAt: _requiredDate(data, 'createdAt'),
      updatedAt: _requiredDate(data, 'updatedAt'),
    );
  }

  /// ใช้ตอนเก็บ Local Cache
  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      'eventName': eventName,
      'disasterType': disasterType,
      'areaDescription': areaDescription,
      'eventDetail': eventDetail,
      'eventStartDate': eventStartDate.toIso8601String(),
      'eventEndDate': eventEndDate?.toIso8601String(),
      'eventStatus': eventStatus,
      'disasterBoundary': disasterBoundary
          .map((point) => point.toMap())
          .toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// ใช้ตอนอ่านข้อมูลกลับจาก Local Cache
  factory DisasterEvent.fromCacheMap(Map<String, dynamic> data) {
    final rawBoundary = data['disasterBoundary'];

    if (rawBoundary is! List) {
      throw const FormatException('Cached disasterBoundary must be a List');
    }

    final boundary = rawBoundary
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid cached boundary item');
          }

          return DisasterBoundaryPoint.fromMap(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);

    return DisasterEvent(
      id: _requiredString(data, 'id'),
      eventName: _requiredString(data, 'eventName'),
      disasterType: _requiredString(data, 'disasterType'),
      areaDescription: _requiredString(data, 'areaDescription'),
      eventDetail: _optionalString(data, 'eventDetail'),
      eventStartDate: _requiredIsoDate(data, 'eventStartDate'),
      eventEndDate: _nullableIsoDate(data['eventEndDate']),
      eventStatus: _requiredBool(data, 'eventStatus'),
      disasterBoundary: boundary,
      createdAt: _requiredIsoDate(data, 'createdAt'),
      updatedAt: _requiredIsoDate(data, 'updatedAt'),
    );
  }

  static String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty String');
    }

    return value.trim();
  }

  static String _optionalString(Map<String, dynamic> data, String key) {
    final value = data[key];

    if (value == null) {
      return '';
    }

    if (value is! String) {
      throw FormatException('$key must be a String');
    }

    return value.trim();
  }

  static bool _requiredBool(Map<String, dynamic> data, String key) {
    final value = data[key];

    if (value is! bool) {
      throw FormatException('$key must be a bool');
    }

    return value;
  }

  static DateTime _requiredDate(Map<String, dynamic> data, String key) {
    final value = data[key];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    throw FormatException('$key must be a Timestamp');
  }

  static DateTime? _nullableDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    throw const FormatException('Invalid nullable timestamp');
  }

  static DateTime _requiredIsoDate(Map<String, dynamic> data, String key) {
    final value = data[key];

    if (value is! String) {
      throw FormatException('$key must be an ISO date String');
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      throw FormatException('$key contains an invalid date');
    }

    return date;
  }

  static DateTime? _nullableIsoDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw const FormatException('Nullable date must be an ISO String');
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      throw const FormatException('Invalid nullable ISO date');
    }

    return date;
  }
}
