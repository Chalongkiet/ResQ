import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/auth/citizen_identity_service.dart';
import '../../core/constants/emergency_request_status.dart';
import '../../shared/validators/emergency_request_validator.dart';
import '../models/emergency_request_model.dart';
import 'exceptions/emergency_request_exception.dart';

class EmergencyRequestService {
  EmergencyRequestService({
    FirebaseFirestore? firestore,
    CitizenIdentityService? identityService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _identityService = identityService ?? CitizenIdentityService();

  final FirebaseFirestore _firestore;

  final CitizenIdentityService _identityService;

  static const String _collectionName = 'emergencyRequests';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionName);

  // ==================================================
  // Create Request
  //
  // S6 จะเรียก method นี้หลัง:
  // - ตรวจภัยพิบัติ
  // - ตรวจ location
  // - upload รูปเสร็จ
  // ==================================================

  Future<EmergencyRequest> create({
    required String disasterEventId,
    required String requestType,
    required double latitude,
    required double longitude,
    required String requestDetail,
    required List<String> situationTags,
    required int affectedCount,
    String? requestImage,
  }) async {
    final normalizedEventId = disasterEventId.trim();
    final normalizedRequestType = requestType.trim();
    final detailError = EmergencyRequestValidator.validateDetail(requestDetail);
    final normalizedSituationTags = situationTags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final affectedCountError = EmergencyRequestValidator.validateAffectedCount(
      affectedCount,
    );

    if (normalizedEventId.isEmpty || normalizedRequestType.isEmpty) {
      throw const EmergencyRequestException(
        'ข้อมูลเหตุภัยพิบัติไม่ครบถ้วน',
        code: 'invalid-disaster-event',
      );
    }

    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const EmergencyRequestException(
        'ตำแหน่งของคำร้องไม่ถูกต้อง',
        code: 'invalid-request-location',
      );
    }

    if (detailError != null) {
      throw EmergencyRequestException(
        detailError,
        code: 'invalid-request-detail',
      );
    }

    if (normalizedSituationTags.isEmpty) {
      throw const EmergencyRequestException(
        'กรุณาเลือกสถานการณ์อย่างน้อย 1 ข้อ',
        code: 'missing-situation',
      );
    }

    if (affectedCountError != null) {
      throw EmergencyRequestException(
        affectedCountError,
        code: 'invalid-affected-count',
      );
    }

    try {
      final user = await _identityService.ensureIdentity();

      final document = _collection.doc();

      final normalizedImage = _normalizeOptional(requestImage);

      await document.set({
        // ============================================
        // Identity
        // ============================================
        'requestId': document.id,

        'userId': user.uid,

        // ============================================
        // Disaster
        // ============================================
        'disasterEventId': normalizedEventId,

        'requestType': normalizedRequestType,

        // ============================================
        // Current incident location
        // ============================================
        'latitude': latitude,

        'longitude': longitude,

        // ============================================
        // Request
        // ============================================
        'requestDetail': requestDetail.trim(),

        'situationTags': normalizedSituationTags,

        'affectedCount': affectedCount,

        'requestImage': normalizedImage,

        // ============================================
        // Initial status
        // ============================================
        'requestStatus': EmergencyRequestStatus.waiting,

        'safeStatus': false,

        'safeImage': null,

        // ============================================
        // Timestamp
        // ============================================
        'createdAt': FieldValue.serverTimestamp(),

        'updatedAt': FieldValue.serverTimestamp(),

        'cancelledAt': null,
      });

      final snapshot = await document.get();

      if (!snapshot.exists) {
        throw const EmergencyRequestException(
          'ไม่สามารถสร้างคำร้องขอความช่วยเหลือได้',
          code: 'request-create-failed',
        );
      }

      return EmergencyRequest.fromFirestore(snapshot);
    } on EmergencyRequestException {
      rethrow;
    } on FirebaseException catch (error) {
      throw EmergencyRequestException(
        'ไม่สามารถบันทึกคำร้องขอความช่วยเหลือได้',
        code: error.code,
      );
    } catch (error) {
      throw EmergencyRequestException(
        'เกิดข้อผิดพลาดในการส่งคำร้องขอความช่วยเหลือ',
        code: 'unknown-error',
      );
    }
  }

  // ==================================================
  // Get Request
  //
  // ใช้หน้า Monitor Rescue Progress
  // ==================================================

  Future<EmergencyRequest?> getById(String requestId) async {
    try {
      final snapshot = await _collection.doc(requestId).get();

      if (!snapshot.exists) {
        return null;
      }

      return EmergencyRequest.fromFirestore(snapshot);
    } on FirebaseException catch (error) {
      throw EmergencyRequestException(
        'ไม่สามารถโหลดคำร้องขอความช่วยเหลือได้',
        code: error.code,
      );
    }
  }

  // ==================================================
  // Realtime Watch
  //
  // สำคัญสำหรับ Monitor Rescue Progress
  //
  // เมื่อ Rescue Team เปลี่ยน requestStatus
  // หน้าผู้ประสบภัยจะเปลี่ยนตามแบบ realtime
  // ==================================================

  Stream<EmergencyRequest?> watchById(String requestId) {
    return _collection.doc(requestId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return EmergencyRequest.fromFirestore(snapshot);
    });
  }

  // ==================================================
  // Update Victim Live Location
  //
  // Controller เป็นผู้ throttle การเขียนก่อนเรียก method นี้ ส่วน service
  // ตรวจ ownership และสถานะล่าสุดซ้ำใน transaction เพื่อไม่ให้ผู้ใช้อื่น
  // เปลี่ยนตำแหน่งของคำร้อง หรือเขียนต่อหลังคำร้องสิ้นสุดแล้ว
  // ==================================================

  Future<void> updateLiveLocation({
    required String requestId,
    required double latitude,
    required double longitude,
  }) async {
    final normalizedRequestId = requestId.trim();

    if (normalizedRequestId.isEmpty) {
      throw const EmergencyRequestNotFoundException();
    }

    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const EmergencyRequestException(
        'ตำแหน่งของคำร้องไม่ถูกต้อง',
        code: 'invalid-request-location',
      );
    }

    try {
      final user = await _identityService.ensureIdentity();
      final reference = _collection.doc(normalizedRequestId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);

        if (!snapshot.exists) {
          throw const EmergencyRequestNotFoundException();
        }

        final request = EmergencyRequest.fromFirestore(snapshot);

        if (request.userId != user.uid) {
          throw const EmergencyRequestOwnerMismatchException();
        }

        if (!request.isWaiting && !request.isAccepted) {
          throw const EmergencyRequestException(
            'ไม่สามารถอัปเดตตำแหน่งของคำร้องในสถานะปัจจุบันได้',
            code: 'request-location-update-not-allowed',
          );
        }

        transaction.update(reference, {
          'latitude': latitude,
          'longitude': longitude,
          'locationUpdatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on EmergencyRequestException {
      rethrow;
    } on FirebaseException catch (error) {
      throw EmergencyRequestException(
        'ไม่สามารถอัปเดตตำแหน่งของผู้ประสบภัยได้',
        code: error.code,
      );
    }
  }

  // ==================================================
  // Cancel Request
  //
  // เตรียมไว้สำหรับ S8
  //
  // ลบได้เมื่อ WAITING เท่านั้น
  // ==================================================

  Future<void> cancel(String requestId) async {
    final normalizedRequestId = requestId.trim();

    if (normalizedRequestId.isEmpty) {
      throw const EmergencyRequestNotFoundException();
    }

    try {
      // ==================================================
      // Current Citizen
      // ==================================================

      final user = await _identityService.ensureIdentity();

      final reference = _collection.doc(normalizedRequestId);

      // ==================================================
      // Transaction
      //
      // ต้องอ่านสถานะล่าสุดก่อน Delete
      // ป้องกันกรณี Rescue Team รับเรื่องพอดี
      // ==================================================

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);

        // ==============================================
        // Request ไม่มี
        // ==============================================

        if (!snapshot.exists) {
          throw const EmergencyRequestNotFoundException();
        }

        final request = EmergencyRequest.fromFirestore(snapshot);

        // ==============================================
        // Ownership
        // ==============================================

        if (request.userId != user.uid) {
          throw const EmergencyRequestOwnerMismatchException();
        }

        // ==============================================
        // Cancel ได้เฉพาะ WAITING
        //
        // ถ้าอนาคต Rescue รับแล้วเป็น ACCEPTED
        // จะไม่สามารถ Cancel ด้วย Flow นี้
        // ==============================================

        if (request.requestStatus != EmergencyRequestStatus.waiting) {
          throw const EmergencyRequestCannotCancelException();
        }

        // ==============================================
        // Delete WAITING Request
        //
        // Request สถานะ WAITING ยังไม่มี RescueMission subcollection
        // และ transaction จะชนกับ Accept transaction อย่างปลอดภัย:
        // ฝั่งที่ commit ทีหลังต้องอ่านสถานะ/document ใหม่ก่อนเสมอ
        // ==============================================

        transaction.delete(reference);
      });
    } on EmergencyRequestException {
      rethrow;
    } on FirebaseException catch (error) {
      throw EmergencyRequestException(
        'ไม่สามารถยกเลิกคำร้องได้',
        code: error.code,
      );
    } catch (error) {
      throw const EmergencyRequestException(
        'เกิดข้อผิดพลาดในการยกเลิกคำร้อง',
        code: 'cancel-request-failed',
      );
    }
  }

  Future<EmergencyRequest?> getActiveRequestByUserId({
    required String userId,
  }) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return null;
    }

    try {
      final snapshot = await _collection
          .where('userId', isEqualTo: normalizedUserId)
          .get();

      final requests = snapshot.docs
          .map(EmergencyRequest.fromFirestore)
          .where(
            (request) =>
                request.requestStatus == EmergencyRequestStatus.waiting ||
                request.requestStatus == EmergencyRequestStatus.accepted,
          )
          .toList();

      if (requests.isEmpty) {
        return null;
      }

      // createdAt อาจยังเป็น null ชั่วคราวระหว่างรอ serverTimestamp
      // จึงต้องเรียงแบบรองรับ null แทนการเรียก compareTo โดยตรง
      requests.sort((a, b) {
        final aCreatedAt = a.createdAt;
        final bCreatedAt = b.createdAt;

        if (aCreatedAt == null && bCreatedAt == null) {
          return b.requestId.compareTo(a.requestId);
        }

        if (aCreatedAt == null) {
          return 1;
        }

        if (bCreatedAt == null) {
          return -1;
        }

        return bCreatedAt.compareTo(aCreatedAt);
      });

      return requests.first;
    } on FirebaseException catch (error) {
      throw EmergencyRequestException(
        'ไม่สามารถตรวจสอบคำร้องที่กำลังดำเนินการได้',
        code: error.code,
      );
    } catch (error) {
      throw const EmergencyRequestException(
        'เกิดข้อผิดพลาดในการตรวจสอบคำร้องที่กำลังดำเนินการ',
        code: 'load-active-request-failed',
      );
    }
  }

  /// ค้นหาคำร้อง WAITING/ACCEPTED ของ Anonymous Citizen ปัจจุบัน
  ///
  /// ใช้ทั้งตอนเปิดหน้า SOS เพื่อ restore flow เดิม และก่อน create
  /// เพื่อป้องกันการส่งคำร้องซ้ำโดยไม่ได้ตั้งใจ
  Future<EmergencyRequest?> getActiveRequestForCurrentUser() async {
    final user = await _identityService.ensureIdentity();

    return getActiveRequestByUserId(userId: user.uid);
  }

  // ==================================================
  // Get Waiting Requests By Disaster Event
  //
  // ใช้สำหรับ Rescue Team:
  // List Emergency Request
  //
  // แสดงเฉพาะ Request ของ Disaster Event ที่ทีมกำลังเข้าร่วม
  // และต้องยังอยู่ในสถานะ WAITING
  // ==================================================

  Future<List<EmergencyRequest>> getWaitingByDisasterEvent({
    required String disasterEventId,
  }) async {
    final normalizedEventId = disasterEventId.trim();

    if (normalizedEventId.isEmpty) {
      return const <EmergencyRequest>[];
    }

    try {
      final snapshot = await _collection
          .where('disasterEventId', isEqualTo: normalizedEventId)
          .where('requestStatus', isEqualTo: EmergencyRequestStatus.waiting)
          .get();

      final requests = snapshot.docs
          .map(EmergencyRequest.fromFirestore)
          .toList();

      // ใหม่สุดขึ้นก่อน
      requests.sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;

        if (aDate == null && bDate == null) {
          return 0;
        }

        if (aDate == null) {
          return 1;
        }

        if (bDate == null) {
          return -1;
        }

        return bDate.compareTo(aDate);
      });

      return requests;
    } on FirebaseException catch (error) {
      throw EmergencyRequestException(
        'ไม่สามารถโหลดรายการขอความช่วยเหลือได้',
        code: error.code,
      );
    } catch (_) {
      throw const EmergencyRequestException(
        'เกิดข้อผิดพลาดในการโหลดรายการขอความช่วยเหลือ',
        code: 'load-emergency-requests-failed',
      );
    }
  }

  // ==================================================
  // Watch Waiting Requests By Disaster Event
  //
  // ใช้หน้า Operational Mode ของ Rescue Team
  // เมื่อมี Request ใหม่เข้ามา List/Map สามารถอัปเดตได้
  // ==================================================

  Stream<List<EmergencyRequest>> watchWaitingByDisasterEvent({
    required String disasterEventId,
  }) {
    final normalizedEventId = disasterEventId.trim();

    if (normalizedEventId.isEmpty) {
      return Stream.value(const <EmergencyRequest>[]);
    }

    return _collection
        .where('disasterEventId', isEqualTo: normalizedEventId)
        .where('requestStatus', isEqualTo: EmergencyRequestStatus.waiting)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map(EmergencyRequest.fromFirestore)
              .toList();

          requests.sort((a, b) {
            final aDate = a.createdAt;
            final bDate = b.createdAt;

            if (aDate == null && bDate == null) {
              return 0;
            }

            if (aDate == null) {
              return 1;
            }

            if (bDate == null) {
              return -1;
            }

            return bDate.compareTo(aDate);
          });

          return requests;
        });
  }

  // ==================================================
  // Normalize
  // ==================================================

  String? _normalizeOptional(String? value) {
    final text = value?.trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  Future<void> attachImage({
    required String requestId,
    required String imageUrl,
    required String imagePublicId,
  }) async {
    try {
      final user = await _identityService.ensureIdentity();

      final reference = _collection.doc(requestId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);

        if (!snapshot.exists) {
          throw const EmergencyRequestNotFoundException();
        }

        final data = snapshot.data() ?? {};

        final ownerUserId = data['userId']?.toString();

        // ป้องกัน Citizen ไปแก้ Request ของคนอื่น
        if (ownerUserId != user.uid) {
          throw const EmergencyRequestException(
            'ไม่มีสิทธิ์แก้ไขคำร้องนี้',
            code: 'request-owner-mismatch',
          );
        }

        transaction.update(reference, {
          'requestImage': imageUrl,

          'requestImagePublicId': imagePublicId,

          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on EmergencyRequestException {
      rethrow;
    } on FirebaseException catch (error) {
      throw EmergencyRequestException(
        'ไม่สามารถบันทึกรูปภาพของคำร้องได้',
        code: error.code,
      );
    }
  }

  /// บันทึกการยืนยันว่าผู้ประสบภัยปลอดภัยแล้ว
  ///
  /// ทำได้เฉพาะเจ้าของคำร้องหลัง Mission ปิดเป็น COMPLETED เท่านั้น
  /// เพื่อป้องกันการยืนยันก่อนการช่วยเหลือเสร็จสิ้น
  Future<void> updateSafetyStatus({
    required String requestId,
    required String safeImage,
  }) async {
    final normalizedRequestId = requestId.trim();
    final normalizedSafeImage = safeImage.trim();

    if (normalizedRequestId.isEmpty) {
      throw const EmergencyRequestNotFoundException();
    }
    if (normalizedSafeImage.isEmpty) {
      throw const EmergencyRequestException(
        'กรุณาแนบรูปภาพยืนยันความปลอดภัย',
        code: 'safe-image-required',
      );
    }

    try {
      final user = await _identityService.ensureIdentity();
      final reference = _collection.doc(normalizedRequestId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);
        if (!snapshot.exists) {
          throw const EmergencyRequestNotFoundException();
        }

        final request = EmergencyRequest.fromFirestore(snapshot);
        if (request.userId != user.uid) {
          throw const EmergencyRequestOwnerMismatchException();
        }
        if (request.safeStatus) {
          throw const EmergencyRequestAlreadySafeException();
        }
        if (request.requestStatus != EmergencyRequestStatus.completed) {
          throw const EmergencyRequestCannotUpdateSafetyException();
        }

        transaction.update(reference, {
          'safeStatus': true,
          'safeImage': normalizedSafeImage,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on EmergencyRequestException {
      rethrow;
    } on FirebaseException catch (error) {
      throw EmergencyRequestException(
        'ไม่สามารถบันทึกการยืนยันความปลอดภัยได้',
        code: error.code,
      );
    } catch (error) {
      throw const EmergencyRequestException(
        'เกิดข้อผิดพลาดในการยืนยันความปลอดภัย',
        code: 'update-safety-failed',
      );
    }
  }
}
