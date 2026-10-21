import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/config/cloudinary_config.dart';

class RescueEvidenceImageUpload {
  const RescueEvidenceImageUpload({required this.url, required this.publicId});

  final String url;
  final String publicId;
}

class RescueEvidenceImageService {
  const RescueEvidenceImageService();

  static const int _maxImageBytes = 5 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png'};
  static const Duration _uploadTimeout = Duration(seconds: 45);

  Future<RescueEvidenceImageUpload> upload({
    required XFile image,
    required CloudinaryUploadPurpose purpose,
  }) async {
    if (!_supportedPurposes.contains(purpose)) {
      throw const RescueEvidenceImageException(
        'ประเภทการอัปโหลดรูปภาพไม่ถูกต้อง',
        code: 'unsupported-upload-purpose',
      );
    }

    if (!CloudinaryConfig.isConfiguredFor(purpose)) {
      throw const RescueEvidenceImageException(
        'ยังไม่ได้ตั้งค่า Cloudinary สำหรับรูปภาพยืนยัน',
        code: 'cloudinary-preset-not-configured',
      );
    }

    try {
      final file = File(image.path);

      if (!await file.exists()) {
        throw const RescueEvidenceImageException(
          'ไม่พบไฟล์รูปภาพ',
          code: 'image-not-found',
        );
      }

      final size = await file.length();
      if (size <= 0) {
        throw const RescueEvidenceImageException(
          'ไฟล์รูปภาพไม่ถูกต้อง',
          code: 'invalid-image',
        );
      }

      if (size > _maxImageBytes) {
        throw const RescueEvidenceImageException(
          'รูปภาพต้องมีขนาดไม่เกิน 5 MB',
          code: 'image-too-large',
        );
      }

      final extension = _getExtension(image.path);
      if (!_allowedExtensions.contains(extension)) {
        throw const RescueEvidenceImageException(
          'รองรับเฉพาะ JPG, JPEG และ PNG',
          code: 'unsupported-image',
        );
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(CloudinaryConfig.uploadUrl),
      );
      request.fields['upload_preset'] = CloudinaryConfig.uploadPresetFor(
        purpose,
      );
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          image.path,
          filename: '${_filenamePrefix(purpose)}.$extension',
        ),
      );

      final streamedResponse = await request.send().timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      Map<String, dynamic> data;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException();
        }
        data = decoded;
      } on FormatException {
        throw const RescueEvidenceImageException(
          'Cloudinary ส่งข้อมูลตอบกลับไม่ถูกต้อง',
          code: 'invalid-cloudinary-response',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RescueEvidenceImageException(
          _extractCloudinaryError(data) ?? 'ไม่สามารถอัปโหลดรูปภาพยืนยันได้',
          code: 'cloudinary-upload-failed',
        );
      }

      final secureUrl = data['secure_url']?.toString().trim();
      final publicId = data['public_id']?.toString().trim();
      if (secureUrl == null ||
          secureUrl.isEmpty ||
          publicId == null ||
          publicId.isEmpty) {
        throw const RescueEvidenceImageException(
          'ไม่พบ URL ของรูปภาพจาก Cloudinary',
          code: 'cloudinary-response-incomplete',
        );
      }

      return RescueEvidenceImageUpload(url: secureUrl, publicId: publicId);
    } on RescueEvidenceImageException {
      rethrow;
    } on TimeoutException {
      throw const RescueEvidenceImageException(
        'อัปโหลดรูปภาพใช้เวลานานเกินไป กรุณาตรวจสอบอินเทอร์เน็ต',
        code: 'upload-timeout',
      );
    } on SocketException {
      throw const RescueEvidenceImageException(
        'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตเพื่ออัปโหลดรูปภาพได้',
        code: 'network-error',
      );
    } catch (_) {
      throw const RescueEvidenceImageException(
        'เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ',
        code: 'upload-error',
      );
    }
  }

  static const Set<CloudinaryUploadPurpose> _supportedPurposes = {
    CloudinaryUploadPurpose.leaveDisasterEvent,
    CloudinaryUploadPurpose.cancelRescueMission,
    CloudinaryUploadPurpose.updateMissionStatus,
  };

  static String? _extractCloudinaryError(Map<String, dynamic> data) {
    final error = data['error'];
    if (error is Map) {
      final message = error['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    return null;
  }

  static String _getExtension(String path) {
    final filename = path.replaceAll('\\', '/').split('/').last;
    final index = filename.lastIndexOf('.');
    if (index == -1 || index == filename.length - 1) return '';
    return filename.substring(index + 1).toLowerCase();
  }

  static String _filenamePrefix(CloudinaryUploadPurpose purpose) {
    switch (purpose) {
      case CloudinaryUploadPurpose.leaveDisasterEvent:
        return 'leave-evidence';
      case CloudinaryUploadPurpose.cancelRescueMission:
        return 'cancel-mission-evidence';
      case CloudinaryUploadPurpose.updateMissionStatus:
        return 'mission-result-evidence';
      case CloudinaryUploadPurpose.submitEmergencyRequest:
      case CloudinaryUploadPurpose.updateSafetyStatus:
        return 'evidence';
    }
  }
}

class RescueEvidenceImageException implements Exception {
  const RescueEvidenceImageException(
    this.message, {
    this.code = 'rescue-evidence-image-error',
  });

  final String message;
  final String code;

  @override
  String toString() {
    return 'RescueEvidenceImageException(code: $code, message: $message)';
  }
}
