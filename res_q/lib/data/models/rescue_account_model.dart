import 'package:cloud_firestore/cloud_firestore.dart';

class RescueAccount {
  const RescueAccount({
    required this.id,
    required this.username,
    required this.password,
    required this.verifyStatus,
    required this.isActive,
    this.rescueTeamId,
    this.rescueTeamName,
    this.email,
    this.operationalStatus = false,
  });

  // ==================================================
  // Fields
  // ==================================================

  final String id;

  final String username;

  final String password;

  final bool verifyStatus;

  final bool isActive;

  /// Document ID ของ RescueOrganization
  ///
  /// ตัวอย่าง:
  /// RescueOrganization/LuuvuyT8swLe7vJzXbP6
  ///
  /// rescueTeamId = LuuvuyT8swLe7vJzXbP6
  final String? rescueTeamId;

  final String? rescueTeamName;

  final String? email;

  final bool operationalStatus;

  // ==================================================
  // Firestore
  // ==================================================

  factory RescueAccount.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return RescueAccount(
      // ==============================================
      // Account ID
      // ==============================================
      id: document.id,

      // ==============================================
      // Login
      // ==============================================
      username: (data['rescue_username'] ?? '').toString().trim(),

      password: (data['rescue_password'] ?? '').toString(),

      // ==============================================
      // Rescue Team
      //
      // สำคัญ:
      // Firestore ปัจจุบันไม่ได้เก็บ rescueTeamId
      // เป็น field ภายใน document
      //
      // Document ID คือ rescueTeamId
      // ==============================================
      rescueTeamId: document.id,

      rescueTeamName: _toNullableString(data['rescueTeamName']),

      // ==============================================
      // Email
      // ==============================================
      email: _toNullableString(data['email']),

      // ==============================================
      // Account Status
      // ==============================================
      verifyStatus: _toBool(data['verifyStatus']),

      isActive: data.containsKey('isActive') ? _toBool(data['isActive']) : true,

      // ==============================================
      // Operational Status
      // ==============================================
      operationalStatus: _toBool(data['operationalStatus']),
    );
  }

  // ==================================================
  // Nullable String
  // ==================================================

  static String? _toNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();

    if (result.isEmpty) {
      return null;
    }

    return result;
  }

  // ==================================================
  // Boolean
  // ==================================================

  static bool _toBool(dynamic value) {
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
}
