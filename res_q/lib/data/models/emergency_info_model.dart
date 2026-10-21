import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyInfo {
  const EmergencyInfo({
    required this.uid,
    required this.fullName,
    required this.phoneNumber,
    required this.bloodGroup,
    required this.medicalCondition,
    required this.allergy,
    required this.regularMedication,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.consentAccepted,
    required this.consentAcceptedAt,
    required this.consentVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Firebase Anonymous UID
  final String uid;

  // --------------------------------------------------
  // Personal Information
  // --------------------------------------------------

  final String fullName;
  final String phoneNumber;
  final String bloodGroup;

  // --------------------------------------------------
  // Medical Information
  // Optional
  // --------------------------------------------------

  final String? medicalCondition;
  final String? allergy;
  final String? regularMedication;

  // --------------------------------------------------
  // Emergency Contact
  // --------------------------------------------------

  final String emergencyContactName;
  final String emergencyContactPhone;

  // --------------------------------------------------
  // Consent
  // --------------------------------------------------

  final bool consentAccepted;
  final DateTime? consentAcceptedAt;
  final String consentVersion;

  // --------------------------------------------------
  // System
  // --------------------------------------------------

  final DateTime createdAt;
  final DateTime updatedAt;

  // --------------------------------------------------
  // Firestore
  // --------------------------------------------------

  factory EmergencyInfo.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw const FormatException('Emergency info document has no data');
    }

    return EmergencyInfo.fromMap(uid: document.id, data: data);
  }

  factory EmergencyInfo.fromMap({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    return EmergencyInfo(
      uid: uid,
      fullName: _requiredString(data, 'fullName'),
      phoneNumber: _requiredString(data, 'phoneNumber'),
      bloodGroup: _requiredString(data, 'bloodGroup'),
      medicalCondition: _optionalString(data['medicalCondition']),
      allergy: _optionalString(data['allergy']),
      regularMedication: _optionalString(data['regularMedication']),
      emergencyContactName: _requiredString(data, 'emergencyContactName'),
      emergencyContactPhone: _requiredString(data, 'emergencyContactPhone'),
      consentAccepted: _requiredBool(data, 'consentAccepted'),
      consentAcceptedAt: _nullableDate(data['consentAcceptedAt']),
      consentVersion: _requiredString(data, 'consentVersion'),
      createdAt: _requiredDate(data, 'createdAt'),
      updatedAt: _requiredDate(data, 'updatedAt'),
    );
  }

  // --------------------------------------------------
  // Convert to Firestore
  // --------------------------------------------------

  Map<String, dynamic> toFirestore() {
    return {
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'bloodGroup': bloodGroup.trim(),
      'medicalCondition': _normalizeOptional(medicalCondition),
      'allergy': _normalizeOptional(allergy),
      'regularMedication': _normalizeOptional(regularMedication),
      'emergencyContactName': emergencyContactName.trim(),
      'emergencyContactPhone': emergencyContactPhone.trim(),
      'consentAccepted': consentAccepted,
      'consentAcceptedAt': consentAcceptedAt,
      'consentVersion': consentVersion,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // --------------------------------------------------
  // Copy
  // --------------------------------------------------

  EmergencyInfo copyWith({
    String? fullName,
    String? phoneNumber,
    String? bloodGroup,
    String? medicalCondition,
    String? allergy,
    String? regularMedication,
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool? consentAccepted,
    DateTime? consentAcceptedAt,
    String? consentVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmergencyInfo(
      uid: uid,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      medicalCondition: medicalCondition ?? this.medicalCondition,
      allergy: allergy ?? this.allergy,
      regularMedication: regularMedication ?? this.regularMedication,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      consentAccepted: consentAccepted ?? this.consentAccepted,
      consentAcceptedAt: consentAcceptedAt ?? this.consentAcceptedAt,
      consentVersion: consentVersion ?? this.consentVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // --------------------------------------------------
  // Helpers
  // --------------------------------------------------

  static String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty String');
    }

    return value.trim();
  }

  static String? _optionalString(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw const FormatException('Optional field must be a String');
    }

    final normalized = value.trim();

    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
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

  static String? _normalizeOptional(String? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim();

    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
