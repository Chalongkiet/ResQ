enum CloudinaryUploadPurpose {
  submitEmergencyRequest,
  leaveDisasterEvent,
  cancelRescueMission,
  updateMissionStatus,
  updateSafetyStatus,
}

abstract final class CloudinaryConfig {
  // ==================================================
  // Cloudinary Product Environment
  // ==================================================

  static const String cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'prex3io1',
  );

  // ==================================================
  // Upload Presets
  // ==================================================

  static const String requestSosUploadPreset = String.fromEnvironment(
    'CLOUDINARY_REQUEST_SOS_UPLOAD_PRESET',
    defaultValue: 'req_sos_preset',
  );

  static const String leaveDisasterEventUploadPreset = String.fromEnvironment(
    'CLOUDINARY_LEAVE_DISASTER_EVENT_UPLOAD_PRESET',
    defaultValue: 'leave_disas_preset',
  );

  static const String cancelRescueMissionUploadPreset = String.fromEnvironment(
    'CLOUDINARY_CANCEL_RESCUE_MISSION_UPLOAD_PRESET',
    defaultValue: 'cancel_mission_preset',
  );

  static const String updateMissionStatusUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPDATE_MISSION_STATUS_UPLOAD_PRESET',
    defaultValue: 'update_mission_preset',
  );

  static const String updateSafetyStatusUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPDATE_SAFETY_STATUS_UPLOAD_PRESET',
    defaultValue: 'update_safety_preset',
  );

  // ==================================================
  // Configuration Check
  // ==================================================

  static bool get hasCloudName {
    return cloudName.trim().isNotEmpty;
  }

  static bool isConfiguredFor(CloudinaryUploadPurpose purpose) {
    return hasCloudName && uploadPresetFor(purpose).trim().isNotEmpty;
  }

  static String uploadPresetFor(CloudinaryUploadPurpose purpose) {
    switch (purpose) {
      case CloudinaryUploadPurpose.submitEmergencyRequest:
        return requestSosUploadPreset;
      case CloudinaryUploadPurpose.leaveDisasterEvent:
        return leaveDisasterEventUploadPreset;
      case CloudinaryUploadPurpose.cancelRescueMission:
        return cancelRescueMissionUploadPreset;
      case CloudinaryUploadPurpose.updateMissionStatus:
        return updateMissionStatusUploadPreset;
      case CloudinaryUploadPurpose.updateSafetyStatus:
        return updateSafetyStatusUploadPreset;
    }
  }

  // ==================================================
  // Upload URL
  // ==================================================

  static String get uploadUrl {
    if (!hasCloudName) {
      throw const CloudinaryConfigurationException(
        'ยังไม่ได้ตั้งค่า Cloudinary Cloud Name',
      );
    }

    return 'https://api.cloudinary.com/v1_1/'
        '$cloudName/auto/upload';
  }

  CloudinaryConfig._();
}

class CloudinaryConfigurationException implements Exception {
  const CloudinaryConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}
