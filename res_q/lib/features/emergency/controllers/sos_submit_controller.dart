import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/cloudinary_config.dart';
import '../../../data/models/current_disaster_event_match.dart';
import '../../../data/models/emergency_request_model.dart';
import '../../../data/services/emergency_request_image_service.dart';
import '../../../data/services/emergency_request_service.dart';
import '../../../shared/validators/emergency_request_validator.dart';

enum SosSubmitStatus {
  idle,

  savingRequest,

  uploadingImage,

  attachingImage,

  success,

  error,
}

class SosSubmitResult {
  const SosSubmitResult({
    required this.request,
    required this.imageUploaded,
    this.reusedActiveRequest = false,
    this.warningMessage,
  });

  final EmergencyRequest request;

  final bool imageUploaded;

  /// true เมื่อพบ WAITING/ACCEPTED เดิมและไม่ได้สร้างเอกสารใหม่
  final bool reusedActiveRequest;

  /// เช่น SOS สำเร็จ แต่รูป Upload ไม่ผ่าน
  final String? warningMessage;
}

class SosSubmitController extends ChangeNotifier {
  SosSubmitController({
    EmergencyRequestService? requestService,
    EmergencyRequestImageService? imageService,
  }) : _requestService = requestService ?? EmergencyRequestService(),
       _imageService = imageService ?? const EmergencyRequestImageService();

  final EmergencyRequestService _requestService;

  final EmergencyRequestImageService _imageService;

  SosSubmitStatus _status = SosSubmitStatus.idle;

  String? _errorMessage;

  String? _warningMessage;

  SosSubmitResult? _result;

  bool _isDisposed = false;

  // ==================================================
  // Getters
  // ==================================================

  SosSubmitStatus get status => _status;

  String? get errorMessage => _errorMessage;

  String? get warningMessage => _warningMessage;

  SosSubmitResult? get result => _result;

  bool get isSavingRequest => _status == SosSubmitStatus.savingRequest;

  bool get isUploadingImage => _status == SosSubmitStatus.uploadingImage;

  bool get isAttachingImage => _status == SosSubmitStatus.attachingImage;

  bool get isSubmitting =>
      isSavingRequest || isUploadingImage || isAttachingImage;

  bool get isSuccess => _status == SosSubmitStatus.success;

  Future<EmergencyRequest?> findActiveRequest() {
    return _requestService.getActiveRequestForCurrentUser();
  }

  // ==================================================
  // Submit
  // ==================================================

  Future<SosSubmitResult?> submit({
    required CurrentDisasterEventMatch disasterEvent,
    required double latitude,
    required double longitude,
    required String requestDetail,
    required List<String> situationTags,
    required int affectedCount,
    XFile? image,
  }) async {
    if (_isDisposed || isSubmitting) {
      return null;
    }

    // ================================================
    // Validate Detail
    // ================================================

    final detailError = EmergencyRequestValidator.validateDetail(requestDetail);

    if (detailError != null) {
      _setError(detailError);

      return null;
    }

    final situationError = EmergencyRequestValidator.validateSituationSelection(
      situationTags,
    );

    if (situationError != null) {
      _setError(situationError);
      return null;
    }

    final affectedCountError = EmergencyRequestValidator.validateAffectedCount(
      affectedCount,
    );
    if (affectedCountError != null) {
      _setError(affectedCountError);
      return null;
    }

    _errorMessage = null;

    _warningMessage = null;

    _result = null;

    try {
      // ==============================================
      // STEP 1
      //
      // สร้าง SOS ก่อนเสมอ
      //
      // รูปภาพ OPTIONAL
      // ดังนั้นรูปต้องไม่ขวางการส่ง SOS
      // ==============================================

      _status = SosSubmitStatus.savingRequest;

      _notify();

      // ==============================================
      // ตรวจซ้ำก่อน Create
      //
      // หน้า SOS ตรวจตอนเปิดแล้ว แต่ระหว่างที่หน้ายังเปิดอยู่
      // อาจมี Request ถูกสร้างจากอีก flow ได้ จึงต้องตรวจที่
      // controller อีกชั้นก่อนสร้างเอกสารใหม่
      // ==============================================

      final activeRequest = await _requestService
          .getActiveRequestForCurrentUser();

      if (_isDisposed) {
        return null;
      }

      if (activeRequest != null) {
        final result = SosSubmitResult(
          request: activeRequest,
          imageUploaded: activeRequest.requestImage != null,
          reusedActiveRequest: true,
        );

        _complete(result);

        return result;
      }

      final request = await _requestService.create(
        disasterEventId: disasterEvent.disasterEventId,

        requestType: disasterEvent.disasterType,

        latitude: latitude,

        longitude: longitude,

        requestDetail: requestDetail.trim(),

        situationTags: situationTags,

        affectedCount: affectedCount,

        // สร้าง Request ก่อน
        requestImage: null,
      );

      if (_isDisposed) {
        return null;
      }

      // ==============================================
      // ไม่มีรูป
      //
      // Request สำเร็จทันที
      // ==============================================

      if (image == null) {
        final result = SosSubmitResult(request: request, imageUploaded: false);

        _complete(result);

        return result;
      }

      // ==============================================
      // STEP 2
      //
      // Upload Cloudinary
      // ==============================================

      _status = SosSubmitStatus.uploadingImage;

      _notify();

      EmergencyRequestImageUpload upload;

      try {
        upload = await _imageService.upload(
          image: image,
          purpose: CloudinaryUploadPurpose.submitEmergencyRequest,
        );
      } on EmergencyRequestImageException catch (error) {
        // ============================================
        // SOS ถูกสร้างแล้ว
        //
        // ห้าม Fail Request ทั้งรายการ
        // ============================================

        final result = SosSubmitResult(
          request: request,

          imageUploaded: false,

          warningMessage:
              'ส่งคำร้องสำเร็จแล้ว แต่รูปภาพอัปโหลดไม่สำเร็จ: '
              '${error.message}',
        );

        _complete(result);

        return result;
      }

      if (_isDisposed) {
        return null;
      }

      // ==============================================
      // STEP 3
      //
      // Attach Cloudinary URL → Firestore
      // ==============================================

      _status = SosSubmitStatus.attachingImage;

      _notify();

      try {
        await _requestService.attachImage(
          requestId: request.requestId,

          imageUrl: upload.url,

          imagePublicId: upload.publicId,
        );
      } catch (error) {
        // SOS ยังคงสำเร็จ
        //
        // แต่ URL ยังไม่ถูกผูกกับ Firestore
        final result = SosSubmitResult(
          request: request,

          imageUploaded: false,

          warningMessage:
              'ส่งคำร้องสำเร็จแล้ว แต่ไม่สามารถบันทึกรูปภาพประกอบคำร้องได้',
        );

        _complete(result);

        return result;
      }

      // ==============================================
      // Complete
      // ==============================================

      final updatedRequest = request.copyWith(
        requestImage: upload.url,

        requestImagePublicId: upload.publicId,
      );

      final result = SosSubmitResult(
        request: updatedRequest,

        imageUploaded: true,
      );

      _complete(result);

      return result;
    } catch (error) {
      if (_isDisposed) {
        return null;
      }

      debugPrint(
        'Submit emergency request failed: '
        '$error',
      );

      _setError('ไม่สามารถส่งคำร้องขอความช่วยเหลือได้');

      return null;
    }
  }

  // ==================================================
  // Complete
  // ==================================================

  void _complete(SosSubmitResult result) {
    if (_isDisposed) {
      return;
    }

    _result = result;

    _warningMessage = result.warningMessage;

    _errorMessage = null;

    _status = SosSubmitStatus.success;

    _notify();
  }

  // ==================================================
  // Error
  // ==================================================

  void _setError(String message) {
    if (_isDisposed) {
      return;
    }

    _errorMessage = message;

    _status = SosSubmitStatus.error;

    _notify();
  }

  void reset() {
    if (_isDisposed) {
      return;
    }

    _status = SosSubmitStatus.idle;

    _errorMessage = null;

    _warningMessage = null;

    _result = null;

    _notify();
  }

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    super.dispose();
  }
}
