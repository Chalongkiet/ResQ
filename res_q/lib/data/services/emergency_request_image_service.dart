import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../core/config/cloudinary_config.dart';

class EmergencyRequestImageUpload {
  const EmergencyRequestImageUpload({
    required this.url,
    required this.publicId,
  });

  /// HTTPS URL สำหรับเก็บใน Firestore
  final String url;

  /// Cloudinary public_id
  ///
  /// เก็บไว้เผื่ออนาคตต้องจัดการ/ลบ Asset
  final String publicId;
}

class EmergencyRequestImageService {
  const EmergencyRequestImageService();

  static const int _maxImageBytes = 5 * 1024 * 1024;

  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png'};

  static const Duration _uploadTimeout = Duration(seconds: 45);

  // ==================================================
  // Upload
  // ==================================================

  Future<EmergencyRequestImageUpload> upload({
    required XFile image,
    CloudinaryUploadPurpose purpose =
        CloudinaryUploadPurpose.submitEmergencyRequest,
  }) async {
    if (!CloudinaryConfig.isConfiguredFor(purpose)) {
      throw const EmergencyRequestImageException(
        'ยังไม่ได้ตั้งค่า Cloudinary สำหรับผู้ประสบภัย',
        code: 'cloudinary-victim-not-configured',
      );
    }

    try {
      // ==============================================
      // Validate Local File
      // ==============================================

      final file = File(image.path);

      if (!await file.exists()) {
        throw const EmergencyRequestImageException(
          'ไม่พบไฟล์รูปภาพ',
          code: 'image-not-found',
        );
      }

      final size = await file.length();

      if (size <= 0) {
        throw const EmergencyRequestImageException(
          'ไฟล์รูปภาพไม่ถูกต้อง',
          code: 'invalid-image',
        );
      }

      if (size > _maxImageBytes) {
        throw const EmergencyRequestImageException(
          'รูปภาพต้องมีขนาดไม่เกิน 5 MB',
          code: 'image-too-large',
        );
      }

      final extension = _getExtension(image.path);

      if (!_allowedExtensions.contains(extension)) {
        throw const EmergencyRequestImageException(
          'รองรับเฉพาะ JPG, JPEG และ PNG',
          code: 'unsupported-image',
        );
      }

      // ==============================================
      // Multipart Request
      // ==============================================

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(CloudinaryConfig.uploadUrl),
      );

      // unsigned upload preset
      request.fields['upload_preset'] = CloudinaryConfig.uploadPresetFor(
        purpose,
      );

      // ไม่ส่ง API Secret
      // ไม่ส่ง API Key

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          image.path,
          filename: '${_filenamePrefix(purpose)}.$extension',
        ),
      );

      // ==============================================
      // Send
      // ==============================================

      final streamedResponse = await request.send().timeout(_uploadTimeout);

      final response = await http.Response.fromStream(streamedResponse);

      // ==============================================
      // Parse
      // ==============================================

      Map<String, dynamic> data;

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) {
          throw const FormatException();
        }

        data = decoded;
      } on FormatException {
        throw const EmergencyRequestImageException(
          'Cloudinary ส่งข้อมูลตอบกลับไม่ถูกต้อง',
          code: 'invalid-cloudinary-response',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final cloudinaryMessage = _extractCloudinaryError(data);

        throw EmergencyRequestImageException(
          cloudinaryMessage ?? 'ไม่สามารถอัปโหลดรูปภาพได้',
          code: 'cloudinary-upload-failed',
        );
      }

      // Cloudinary response
      final secureUrl = data['secure_url']?.toString().trim();

      final publicId = data['public_id']?.toString().trim();

      if (secureUrl == null ||
          secureUrl.isEmpty ||
          publicId == null ||
          publicId.isEmpty) {
        throw const EmergencyRequestImageException(
          'ไม่พบ URL ของรูปภาพจาก Cloudinary',
          code: 'cloudinary-response-incomplete',
        );
      }

      return EmergencyRequestImageUpload(url: secureUrl, publicId: publicId);
    } on EmergencyRequestImageException {
      rethrow;
    } on TimeoutException {
      throw const EmergencyRequestImageException(
        'อัปโหลดรูปภาพใช้เวลานานเกินไป กรุณาตรวจสอบอินเทอร์เน็ต',
        code: 'upload-timeout',
      );
    } on SocketException {
      throw const EmergencyRequestImageException(
        'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตเพื่ออัปโหลดรูปภาพได้',
        code: 'network-error',
      );
    } catch (error) {
      throw const EmergencyRequestImageException(
        'เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ',
        code: 'upload-error',
      );
    }
  }

  // ==================================================
  // Cloudinary Error
  // ==================================================

  String? _extractCloudinaryError(Map<String, dynamic> data) {
    final error = data['error'];

    if (error is Map) {
      final message = error['message']?.toString().trim();

      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    return null;
  }

  // ==================================================
  // Extension
  // ==================================================

  String _getExtension(String path) {
    final filename = path.replaceAll('\\', '/').split('/').last;

    final index = filename.lastIndexOf('.');

    if (index == -1 || index == filename.length - 1) {
      return '';
    }

    return filename.substring(index + 1).toLowerCase();
  }

  String _filenamePrefix(CloudinaryUploadPurpose purpose) {
    switch (purpose) {
      case CloudinaryUploadPurpose.submitEmergencyRequest:
        return 'incident';
      case CloudinaryUploadPurpose.updateSafetyStatus:
        return 'safety-evidence';
      case CloudinaryUploadPurpose.leaveDisasterEvent:
      case CloudinaryUploadPurpose.cancelRescueMission:
      case CloudinaryUploadPurpose.updateMissionStatus:
        return 'evidence';
    }
  }
}

class EmergencyRequestImageException implements Exception {
  const EmergencyRequestImageException(
    this.message, {
    this.code = 'emergency-image-error',
  });

  final String message;

  final String code;

  @override
  String toString() {
    return 'EmergencyRequestImageException('
        'code: $code, '
        'message: $message'
        ')';
  }
}
