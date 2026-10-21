import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum SosCameraStatus { idle, capturing, ready, error }

class SosCameraController extends ChangeNotifier {
  SosCameraController({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  // ==================================================
  // Validation Configuration
  // ==================================================

  static const int maxImageBytes = 5 * 1024 * 1024;

  static const Set<String> allowedExtensions = {'jpg', 'jpeg', 'png'};

  // ==================================================
  // State
  // ==================================================

  XFile? _image;

  int? _imageSizeBytes;

  SosCameraStatus _status = SosCameraStatus.idle;

  String? _errorMessage;

  bool _isDisposed = false;

  // ==================================================
  // Getters
  // ==================================================

  XFile? get image => _image;

  String? get imagePath => _image?.path;

  int? get imageSizeBytes => _imageSizeBytes;

  SosCameraStatus get status => _status;

  String? get errorMessage => _errorMessage;

  bool get hasImage => _image != null;

  bool get isCapturing => _status == SosCameraStatus.capturing;

  bool get isReady => _status == SosCameraStatus.ready && _image != null;

  bool get hasError => _status == SosCameraStatus.error;

  // ==================================================
  // Initialize
  //
  // Android อาจ destroy MainActivity
  // ตอนเปิดกล้อง จึงตรวจ lost data
  // ==================================================

  Future<void> initialize() async {
    await _recoverLostImage();
  }

  // ==================================================
  // Capture
  // ==================================================

  Future<void> captureImage() async {
    await pickImage(ImageSource.camera);
  }

  Future<void> pickFromGallery() async {
    await pickImage(ImageSource.gallery);
  }

  Future<void> pickImage(ImageSource source) async {
    if (_isDisposed || isCapturing) {
      return;
    }

    _status = SosCameraStatus.capturing;

    _errorMessage = null;

    _notify();

    try {
      final capturedImage = await _imagePicker.pickImage(
        source: source,

        // ใช้กล้องหลัง
        preferredCameraDevice: CameraDevice.rear,

        // ลดขนาดไฟล์เล็กน้อย
        // แต่ยังคงรายละเอียดสำหรับทีมกู้ภัย
        imageQuality: 85,

        // ไม่จำเป็นต้องอ่าน metadata เต็ม
        requestFullMetadata: false,
      );

      if (_isDisposed) {
        return;
      }

      // ผู้ใช้กด Back / Cancel จากกล้อง
      if (capturedImage == null) {
        _status = _image != null ? SosCameraStatus.ready : SosCameraStatus.idle;

        _notify();

        return;
      }

      await _validateAndSetImage(capturedImage);
    } on PlatformException catch (error) {
      if (_isDisposed) {
        return;
      }

      debugPrint(
        'SOS camera PlatformException: '
        '${error.code}',
      );

      _status = SosCameraStatus.error;

      _errorMessage = _mapCameraError(error);

      _notify();
    } catch (error) {
      if (_isDisposed) {
        return;
      }

      debugPrint('SOS camera failed: $error');

      _status = SosCameraStatus.error;

      _errorMessage = 'ไม่สามารถเปิดกล้องหรือถ่ายภาพได้';

      _notify();
    }
  }

  // ==================================================
  // Validate Image
  // ==================================================

  Future<void> _validateAndSetImage(XFile image) async {
    try {
      // ==============================================
      // 1. File Extension
      // ==============================================

      final extension = _getExtension(image.path);

      if (!allowedExtensions.contains(extension)) {
        await _deleteTemporaryFile(image);

        _status = SosCameraStatus.error;

        _errorMessage = 'รองรับเฉพาะไฟล์ JPG, JPEG และ PNG';

        _notify();

        return;
      }

      // ==============================================
      // 2. File Size
      // ==============================================

      final size = await image.length();

      if (size <= 0) {
        await _deleteTemporaryFile(image);

        _status = SosCameraStatus.error;

        _errorMessage = 'ไม่สามารถอ่านไฟล์รูปภาพได้';

        _notify();

        return;
      }

      if (size > maxImageBytes) {
        await _deleteTemporaryFile(image);

        _status = SosCameraStatus.error;

        _errorMessage = 'รูปภาพต้องมีขนาดไม่เกิน 5 MB';

        _notify();

        return;
      }

      // ==============================================
      // 3. ลบรูปเก่าถ้ามี
      // ==============================================

      final previousImage = _image;

      if (previousImage != null && previousImage.path != image.path) {
        await _deleteTemporaryFile(previousImage);
      }

      // ==============================================
      // 4. Save State
      // ==============================================

      _image = image;

      _imageSizeBytes = size;

      _status = SosCameraStatus.ready;

      _errorMessage = null;

      _notify();
    } catch (error) {
      debugPrint(
        'SOS image validation failed: '
        '$error',
      );

      await _deleteTemporaryFile(image);

      if (_isDisposed) {
        return;
      }

      _status = SosCameraStatus.error;

      _errorMessage = 'ไม่สามารถตรวจสอบรูปภาพได้';

      _notify();
    }
  }

  // ==================================================
  // Recover Lost Image
  //
  // Android:
  // ระบบอาจปิด Activity ของ Flutter
  // ขณะ Camera App เปิดอยู่
  // ==================================================

  Future<void> _recoverLostImage() async {
    try {
      final response = await _imagePicker.retrieveLostData();

      if (_isDisposed || response.isEmpty) {
        return;
      }

      if (response.exception != null) {
        debugPrint(
          'Recover SOS camera failed: '
          '${response.exception}',
        );

        return;
      }

      final files = response.files;

      if (files == null || files.isEmpty) {
        return;
      }

      // เราใช้กล้องทีละ 1 รูปเท่านั้น
      await _validateAndSetImage(files.first);
    } catch (error) {
      // การ Recover ไม่ควรทำให้หน้า SOS พัง
      debugPrint(
        'Recover SOS camera data failed: '
        '$error',
      );
    }
  }

  // ==================================================
  // Remove
  // ==================================================

  Future<void> removeImage() async {
    final currentImage = _image;

    _image = null;

    _imageSizeBytes = null;

    _errorMessage = null;

    _status = SosCameraStatus.idle;

    _notify();

    if (currentImage != null) {
      await _deleteTemporaryFile(currentImage);
    }
  }

  // ==================================================
  // Error Mapping
  // ==================================================

  String _mapCameraError(PlatformException error) {
    switch (error.code) {
      case 'camera_access_denied':
        return 'ไม่ได้รับสิทธิ์ใช้งานกล้อง';

      case 'camera_access_denied_without_prompt':
        return 'สิทธิ์ใช้งานกล้องถูกปิด กรุณาเปิดจากการตั้งค่าอุปกรณ์';

      case 'camera_access_restricted':
        return 'อุปกรณ์นี้จำกัดการใช้งานกล้อง';

      case 'photo_access_denied':
        return 'ไม่ได้รับสิทธิ์เข้าถึงคลังภาพ';

      case 'photo_access_denied_without_prompt':
        return 'สิทธิ์เข้าถึงคลังภาพถูกปิด กรุณาเปิดจากการตั้งค่าอุปกรณ์';

      default:
        return 'ไม่สามารถเปิดกล้องได้ กรุณาลองใหม่อีกครั้ง';
    }
  }

  // ==================================================
  // Extension
  // ==================================================

  String _getExtension(String path) {
    final fileName = path.replaceAll('\\', '/').split('/').last;

    final index = fileName.lastIndexOf('.');

    if (index == -1 || index == fileName.length - 1) {
      return '';
    }

    return fileName.substring(index + 1).toLowerCase();
  }

  // ==================================================
  // Temporary File
  // ==================================================

  Future<void> _deleteTemporaryFile(XFile file) async {
    try {
      final localFile = File(file.path);

      if (await localFile.exists()) {
        await localFile.delete();
      }
    } catch (error) {
      debugPrint(
        'Delete temporary SOS image failed: '
        '$error',
      );
    }
  }

  // ==================================================
  // Display Size
  // ==================================================

  String get formattedImageSize {
    final bytes = _imageSizeBytes;

    if (bytes == null) {
      return '';
    }

    final megabytes = bytes / (1024 * 1024);

    return '${megabytes.toStringAsFixed(2)} MB';
  }

  // ==================================================
  // Notify
  // ==================================================

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // ==================================================
  // Dispose
  // ==================================================

  @override
  void dispose() {
    _isDisposed = true;

    final currentImage = _image;

    if (currentImage != null) {
      unawaited(_deleteTemporaryFile(currentImage));
    }

    super.dispose();
  }
}
