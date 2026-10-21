import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/core/config/cloudinary_config.dart';

void main() {
  group('CloudinaryConfig', () {
    test('uses the configured cloud and auto upload endpoint', () {
      expect(CloudinaryConfig.cloudName, 'prex3io1');
      expect(
        CloudinaryConfig.uploadUrl,
        'https://api.cloudinary.com/v1_1/prex3io1/auto/upload',
      );
    });

    test('maps every use case to its own upload preset', () {
      expect(
        CloudinaryConfig.uploadPresetFor(
          CloudinaryUploadPurpose.submitEmergencyRequest,
        ),
        'req_sos_preset',
      );
      expect(
        CloudinaryConfig.uploadPresetFor(
          CloudinaryUploadPurpose.leaveDisasterEvent,
        ),
        'leave_disas_preset',
      );
      expect(
        CloudinaryConfig.uploadPresetFor(
          CloudinaryUploadPurpose.cancelRescueMission,
        ),
        'cancel_mission_preset',
      );
      expect(
        CloudinaryConfig.uploadPresetFor(
          CloudinaryUploadPurpose.updateMissionStatus,
        ),
        'update_mission_preset',
      );
      expect(
        CloudinaryConfig.uploadPresetFor(
          CloudinaryUploadPurpose.updateSafetyStatus,
        ),
        'update_safety_preset',
      );
    });

    test('reports every default preset as configured', () {
      for (final purpose in CloudinaryUploadPurpose.values) {
        expect(CloudinaryConfig.isConfiguredFor(purpose), isTrue);
      }
    });
  });
}
