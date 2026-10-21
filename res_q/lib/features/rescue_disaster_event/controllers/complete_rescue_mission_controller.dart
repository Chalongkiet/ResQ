import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/cloudinary_config.dart';
import '../../../shared/validators/rescue_action_validator.dart';
import '../services/exceptions/rescue_mission_action_exception.dart';
import '../services/rescue_evidence_image_service.dart';
import '../services/rescue_mission_action_service.dart';

class CompleteRescueMissionController extends ChangeNotifier {
  CompleteRescueMissionController({
    RescueMissionActionService? missionService,
    RescueEvidenceImageService? imageService,
    ImagePicker? imagePicker,
  }) : _missionService = missionService ?? RescueMissionActionService(),
       _imageService = imageService ?? const RescueEvidenceImageService(),
       _imagePicker = imagePicker ?? ImagePicker();

  final RescueMissionActionService _missionService;
  final RescueEvidenceImageService _imageService;
  final ImagePicker _imagePicker;

  XFile? _selectedImage;
  bool _isPickingImage = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _disposed = false;

  XFile? get selectedImage => _selectedImage;
  bool get isPickingImage => _isPickingImage;
  bool get isSubmitting => _isSubmitting;
  bool get isBusy => _isPickingImage || _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<void> pickImage(ImageSource source) async {
    if (_disposed || isBusy) return;

    _isPickingImage = true;
    _errorMessage = null;
    _notify();

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (!_disposed && image != null) _selectedImage = image;
    } catch (error, stackTrace) {
      debugPrint('[COMPLETE MISSION] PICK IMAGE ERROR: $error');
      debugPrint('$stackTrace');
      _errorMessage = 'ไม่สามารถเลือกรูปภาพได้ กรุณาลองใหม่อีกครั้ง';
    } finally {
      if (!_disposed) {
        _isPickingImage = false;
        _notify();
      }
    }
  }

  void removeImage() {
    if (_disposed || _isSubmitting) return;
    _selectedImage = null;
    _errorMessage = null;
    _notify();
  }

  void clearError() {
    if (_disposed || _errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  Future<bool> submit({
    required String requestId,
    required String missionId,
    required String deploymentId,
    required String safeLocationName,
  }) async {
    if (_disposed || _isSubmitting) return false;

    final safeLocation = safeLocationName.trim();
    final detailError = RescueActionValidator.validateSafeLocationName(
      safeLocation,
    );
    if (detailError != null) {
      _setError(detailError);
      return false;
    }

    final image = _selectedImage;
    if (image == null) {
      _setError('กรุณาแนบรูปภาพยืนยันการจบภารกิจ');
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _notify();

    try {
      final upload = await _imageService.upload(
        image: image,
        purpose: CloudinaryUploadPurpose.updateMissionStatus,
      );
      if (_disposed) return false;

      await _missionService.complete(
        requestId: requestId,
        missionId: missionId,
        deploymentId: deploymentId,
        proofImageUrl: upload.url,
        safeLocationName: safeLocation,
      );
      return !_disposed;
    } on RescueEvidenceImageException catch (error) {
      _errorMessage = error.message;
      return false;
    } on RescueMissionActionException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (error, stackTrace) {
      debugPrint('[COMPLETE MISSION] ERROR: $error');
      debugPrint('$stackTrace');
      _errorMessage = 'เกิดข้อผิดพลาดในการจบภารกิจ กรุณาลองใหม่อีกครั้ง';
      return false;
    } finally {
      if (!_disposed) {
        _isSubmitting = false;
        _notify();
      }
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
