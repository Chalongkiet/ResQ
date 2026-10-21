import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/cloudinary_config.dart';
import '../../../shared/validators/rescue_action_validator.dart';
import '../services/exceptions/leave_disaster_event_exception.dart';
import '../services/leave_disaster_event_service.dart';
import '../services/rescue_evidence_image_service.dart';

class LeaveDisasterEventController extends ChangeNotifier {
  LeaveDisasterEventController({
    LeaveDisasterEventService? leaveService,
    RescueEvidenceImageService? imageService,
    ImagePicker? imagePicker,
  }) : _leaveService = leaveService ?? LeaveDisasterEventService(),
       _imageService = imageService ?? const RescueEvidenceImageService(),
       _imagePicker = imagePicker ?? ImagePicker();

  final LeaveDisasterEventService _leaveService;
  final RescueEvidenceImageService _imageService;
  final ImagePicker _imagePicker;

  // ==================================================
  // Image
  // ==================================================

  XFile? _selectedImage;

  bool _isPickingImage = false;

  // ==================================================
  // Submit
  // ==================================================

  bool _isSubmitting = false;

  String? _errorMessage;

  bool _disposed = false;

  // ==================================================
  // Getters
  // ==================================================

  XFile? get selectedImage => _selectedImage;

  bool get hasSelectedImage => _selectedImage != null;

  bool get isPickingImage => _isPickingImage;

  bool get isSubmitting => _isSubmitting;

  bool get isBusy => _isPickingImage || _isSubmitting;

  String? get errorMessage => _errorMessage;

  // ==================================================
  // Pick Image
  // ==================================================

  Future<void> pickImage(ImageSource source) async {
    if (_disposed || isBusy) {
      return;
    }

    _isPickingImage = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
        requestFullMetadata: false,
      );

      if (_disposed) {
        return;
      }

      // ผู้ใช้กดยกเลิก Image Picker
      if (image == null) {
        return;
      }

      _selectedImage = image;
      _errorMessage = null;
    } catch (error, stackTrace) {
      debugPrint('[LEAVE IMAGE] PICK ERROR');
      debugPrint('[LEAVE IMAGE] $error');
      debugPrint('[LEAVE IMAGE] $stackTrace');

      _errorMessage = 'ไม่สามารถเลือกรูปภาพได้ กรุณาลองใหม่อีกครั้ง';
    } finally {
      if (!_disposed) {
        _isPickingImage = false;
        _safeNotifyListeners();
      }
    }
  }

  // ==================================================
  // Remove Image
  // ==================================================

  void removeImage() {
    if (_disposed || _isSubmitting) {
      return;
    }

    _selectedImage = null;
    _errorMessage = null;
    _safeNotifyListeners();
  }

  // ==================================================
  // Clear Error
  // ==================================================

  void clearError() {
    if (_disposed || _errorMessage == null) {
      return;
    }

    _errorMessage = null;
    _safeNotifyListeners();
  }

  // ==================================================
  // Submit Leave
  // ==================================================

  Future<bool> submit({
    required String eventId,
    required String deploymentId,
    required String rescueTeamId,
    required String leaveReason,
    String? leaveDetail,
  }) async {
    if (_disposed || _isSubmitting) {
      return false;
    }

    // ==================================================
    // Normalize
    // ==================================================

    final normalizedReason = leaveReason.trim();

    final normalizedDetail = _normalizeOptional(leaveDetail);

    // ==================================================
    // Validate Reason
    // ==================================================

    final reasonError = RescueActionValidator.validateLeaveReason(
      normalizedReason,
    );
    if (reasonError != null) {
      _setError(reasonError);
      return false;
    }

    // ==================================================
    // Validate Detail
    // ==================================================

    final detailError = RescueActionValidator.validateOptionalDetail(
      normalizedDetail,
    );
    if (detailError != null) {
      _setError(detailError);
      return false;
    }

    // ==================================================
    // Validate Image
    // ==================================================

    final image = _selectedImage;

    if (image == null) {
      _setError('กรุณาแนบรูปภาพยืนยันการถอนกำลัง');
      return false;
    }

    // ==================================================
    // Submit
    // ==================================================

    _isSubmitting = true;
    _errorMessage = null;
    _safeNotifyListeners();

    debugPrint('================================');
    debugPrint('[LEAVE CONTROLLER] SUBMIT START');
    debugPrint('[LEAVE CONTROLLER] event=$eventId');
    debugPrint('[LEAVE CONTROLLER] deployment=$deploymentId');
    debugPrint('[LEAVE CONTROLLER] team=$rescueTeamId');

    try {
      // ==================================================
      // 1. Upload Confirmation Image
      //
      // ใช้ Rescue Team Cloudinary Upload Preset
      // ผ่าน RescueEvidenceImageService
      // ==================================================

      debugPrint('[LEAVE CONTROLLER] uploading rescue-team image...');

      final upload = await _imageService.upload(
        image: image,
        purpose: CloudinaryUploadPurpose.leaveDisasterEvent,
      );

      if (_disposed) {
        return false;
      }

      debugPrint(
        '[LEAVE CONTROLLER] '
        'image uploaded publicId=${upload.publicId}',
      );

      // ==================================================
      // 2. Update Firestore
      // ==================================================

      debugPrint('[LEAVE CONTROLLER] updating deployment...');

      await _leaveService.leave(
        eventId: eventId,
        deploymentId: deploymentId,
        rescueTeamId: rescueTeamId,
        leaveReason: normalizedReason,
        leaveDetail: normalizedDetail,
        leaveImageUrl: upload.url,
      );

      if (_disposed) {
        return false;
      }

      debugPrint('[LEAVE CONTROLLER] SUCCESS');

      return true;
    } on RescueEvidenceImageException catch (error) {
      debugPrint(
        '[LEAVE CONTROLLER] IMAGE ERROR '
        '${error.code}',
      );

      _errorMessage = error.message;

      return false;
    } on LeaveDisasterEventException catch (error) {
      debugPrint(
        '[LEAVE CONTROLLER] LEAVE ERROR '
        '${error.code}',
      );

      _errorMessage = error.message;

      return false;
    } catch (error, stackTrace) {
      debugPrint('[LEAVE CONTROLLER] ERROR');
      debugPrint('[LEAVE CONTROLLER] $error');
      debugPrint('[LEAVE CONTROLLER] $stackTrace');

      _errorMessage = 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';

      return false;
    } finally {
      if (!_disposed) {
        _isSubmitting = false;
        _safeNotifyListeners();
      }

      debugPrint('[LEAVE CONTROLLER] SUBMIT FINISHED');
      debugPrint('================================');
    }
  }

  // ==================================================
  // Error
  // ==================================================

  void _setError(String message) {
    if (_disposed) {
      return;
    }

    _errorMessage = message;
    _safeNotifyListeners();
  }

  // ==================================================
  // Normalize
  // ==================================================

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  // ==================================================
  // Notify
  // ==================================================

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // ==================================================
  // Dispose
  // ==================================================

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
