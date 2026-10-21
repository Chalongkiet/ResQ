import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/auth/citizen_identity_service.dart';
import '../../core/constants/consent_constants.dart';
import '../../shared/validators/emergency_info_validator.dart';
import '../models/emergency_info_model.dart';
import 'exceptions/emergency_info_exception.dart';

class EmergencyInfoService {
  EmergencyInfoService({
    FirebaseFirestore? firestore,
    CitizenIdentityService? identityService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _identityService = identityService ?? CitizenIdentityService();

  final FirebaseFirestore _firestore;
  final CitizenIdentityService _identityService;

  static const String _collectionName = 'emergencyInfos';

  CollectionReference<Map<String, dynamic>> get _collection {
    return _firestore.collection(_collectionName);
  }

  // ==================================================
  // Current UID
  // ==================================================

  Future<String> _getCurrentUid() async {
    final user = await _identityService.ensureIdentity();

    return user.uid;
  }

  // ==================================================
  // Document Reference
  // ==================================================

  Future<DocumentReference<Map<String, dynamic>>> _currentDocument() async {
    final uid = await _getCurrentUid();

    return _collection.doc(uid);
  }

  // ==================================================
  // Exists
  // ==================================================

  Future<bool> exists() async {
    try {
      final document = await _currentDocument();

      final snapshot = await document.get();

      return snapshot.exists;
    } on FirebaseException catch (error) {
      debugPrint(
        'EmergencyInfo exists error: '
        '${error.code} ${error.message}',
      );

      throw EmergencyInfoException(
        _firebaseErrorMessage(error),
        code: error.code,
      );
    }
  }

  // ==================================================
  // Get
  // ==================================================

  Future<EmergencyInfo?> get() async {
    try {
      final document = await _currentDocument();

      final snapshot = await document.get();

      if (!snapshot.exists) {
        return null;
      }

      return EmergencyInfo.fromFirestore(snapshot);
    } on FirebaseException catch (error) {
      debugPrint(
        'EmergencyInfo get error: '
        '${error.code} ${error.message}',
      );

      throw EmergencyInfoException(
        _firebaseErrorMessage(error),
        code: error.code,
      );
    } on FormatException catch (error) {
      debugPrint('EmergencyInfo parse error: $error');

      throw const EmergencyInfoException(
        'ข้อมูลฉุกเฉินที่บันทึกไว้ไม่ถูกต้อง',
        code: 'invalid-data',
      );
    }
  }

  // ==================================================
  // Watch
  // ==================================================

  Stream<EmergencyInfo?> watch() async* {
    final uid = await _getCurrentUid();

    yield* _collection.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return EmergencyInfo.fromFirestore(snapshot);
    });
  }

  // ==================================================
  // Create
  //
  // Prepare Emergency Info
  //
  // สร้างได้เพียงครั้งเดียว
  // ==================================================

  Future<EmergencyInfo> create({
    required String fullName,
    required String phoneNumber,
    required String bloodGroup,
    String? medicalCondition,
    String? allergy,
    String? regularMedication,
    required String emergencyContactName,
    required String emergencyContactPhone,
  }) async {
    _validateInput(
      fullName: fullName,
      phoneNumber: phoneNumber,
      bloodGroup: bloodGroup,
      medicalCondition: medicalCondition,
      allergy: allergy,
      regularMedication: regularMedication,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
    );

    final uid = await _getCurrentUid();
    final document = _collection.doc(uid);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(document);

        // ------------------------------------------
        // ห้าม Prepare ซ้ำ
        // ------------------------------------------

        if (snapshot.exists) {
          throw const EmergencyInfoAlreadyExistsException();
        }

        final now = DateTime.now();

        final info = EmergencyInfo(
          uid: uid,
          fullName: fullName.trim(),
          phoneNumber: phoneNumber.trim(),
          bloodGroup: bloodGroup.trim(),
          medicalCondition: _normalizeOptional(medicalCondition),
          allergy: _normalizeOptional(allergy),
          regularMedication: _normalizeOptional(regularMedication),
          emergencyContactName: emergencyContactName.trim(),
          emergencyContactPhone: emergencyContactPhone.trim(),

          // Consent ถูกบังคับจาก Prepare UI
          consentAccepted: true,
          consentAcceptedAt: now,
          consentVersion: ConsentConstants.emergencyInfoVersion,

          createdAt: now,
          updatedAt: now,
        );

        transaction.set(document, info.toFirestore());
      });

      final created = await document.get();

      if (!created.exists) {
        throw const EmergencyInfoException(
          'ไม่สามารถตรวจสอบข้อมูลหลังการบันทึกได้',
          code: 'create-verification-failed',
        );
      }

      return EmergencyInfo.fromFirestore(created);
    } on EmergencyInfoAlreadyExistsException {
      rethrow;
    } on FirebaseException catch (error) {
      debugPrint(
        'EmergencyInfo create error: '
        '${error.code} ${error.message}',
      );

      throw EmergencyInfoException(
        _firebaseErrorMessage(error),
        code: error.code,
      );
    }
  }

  // ==================================================
  // Update
  //
  // Edit Emergency Info
  //
  // Update ได้เฉพาะ document ที่มีอยู่แล้ว
  // ==================================================

  Future<EmergencyInfo> update({
    required String fullName,
    required String phoneNumber,
    required String bloodGroup,
    String? medicalCondition,
    String? allergy,
    String? regularMedication,
    required String emergencyContactName,
    required String emergencyContactPhone,
  }) async {
    _validateInput(
      fullName: fullName,
      phoneNumber: phoneNumber,
      bloodGroup: bloodGroup,
      medicalCondition: medicalCondition,
      allergy: allergy,
      regularMedication: regularMedication,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
    );

    final uid = await _getCurrentUid();
    final document = _collection.doc(uid);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(document);

        // ------------------------------------------
        // Edit ต้องมีข้อมูลเดิมก่อน
        // ------------------------------------------

        if (!snapshot.exists) {
          throw const EmergencyInfoNotFoundException();
        }

        final existing = EmergencyInfo.fromFirestore(snapshot);

        final updated = EmergencyInfo(
          uid: uid,
          fullName: fullName.trim(),
          phoneNumber: phoneNumber.trim(),
          bloodGroup: bloodGroup.trim(),
          medicalCondition: _normalizeOptional(medicalCondition),
          allergy: _normalizeOptional(allergy),
          regularMedication: _normalizeOptional(regularMedication),
          emergencyContactName: emergencyContactName.trim(),
          emergencyContactPhone: emergencyContactPhone.trim(),

          // ----------------------------------------
          // Consent เดิม
          // ไม่ให้ Edit Form เปลี่ยนเอง
          // ----------------------------------------
          consentAccepted: existing.consentAccepted,
          consentAcceptedAt: existing.consentAcceptedAt,
          consentVersion: existing.consentVersion,

          // ----------------------------------------
          // createdAt ห้ามเปลี่ยน
          // ----------------------------------------
          createdAt: existing.createdAt,

          // ----------------------------------------
          // เปลี่ยนเฉพาะ updatedAt
          // ----------------------------------------
          updatedAt: DateTime.now(),
        );

        transaction.update(document, updated.toFirestore());
      });

      final updated = await document.get();

      if (!updated.exists) {
        throw const EmergencyInfoNotFoundException();
      }

      return EmergencyInfo.fromFirestore(updated);
    } on EmergencyInfoNotFoundException {
      rethrow;
    } on FirebaseException catch (error) {
      debugPrint(
        'EmergencyInfo update error: '
        '${error.code} ${error.message}',
      );

      throw EmergencyInfoException(
        _firebaseErrorMessage(error),
        code: error.code,
      );
    } on FormatException catch (error) {
      debugPrint(
        'EmergencyInfo update parse error: '
        '$error',
      );

      throw const EmergencyInfoException(
        'ข้อมูลฉุกเฉินที่บันทึกไว้ไม่ถูกต้อง',
        code: 'invalid-data',
      );
    }
  }

  // ==================================================
  // Helpers
  // ==================================================

  static String? _normalizeOptional(String? value) {
    final text = value?.trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static void _validateInput({
    required String fullName,
    required String phoneNumber,
    required String bloodGroup,
    String? medicalCondition,
    String? allergy,
    String? regularMedication,
    required String emergencyContactName,
    required String emergencyContactPhone,
  }) {
    final errors = <String?>[
      EmergencyInfoValidator.validateFullName(fullName),
      EmergencyInfoValidator.validatePhoneNumber(phoneNumber),
      EmergencyInfoValidator.validateBloodGroup(bloodGroup),
      EmergencyInfoValidator.validateMedicalCondition(medicalCondition),
      EmergencyInfoValidator.validateAllergy(allergy),
      EmergencyInfoValidator.validateRegularMedication(regularMedication),
      EmergencyInfoValidator.validateEmergencyContactName(emergencyContactName),
      EmergencyInfoValidator.validateEmergencyContactPhone(
        emergencyContactPhone,
        victimPhoneNumber: phoneNumber,
      ),
    ];

    for (final error in errors) {
      if (error != null) {
        throw EmergencyInfoException(error, code: 'validation-error');
      }
    }
  }

  static String _firebaseErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'ไม่มีสิทธิ์เข้าถึงข้อมูลฉุกเฉิน';

      case 'unavailable':
        return 'ไม่สามารถเชื่อมต่อฐานข้อมูลได้ กรุณาลองใหม่อีกครั้ง';

      case 'cancelled':
        return 'การดำเนินการถูกยกเลิก';

      case 'deadline-exceeded':
        return 'การเชื่อมต่อใช้เวลานานเกินไป กรุณาลองใหม่';

      default:
        return 'เกิดข้อผิดพลาดในการจัดการข้อมูลฉุกเฉิน';
    }
  }

  // ==================================================
  // Get By UID
  //
  // ใช้สำหรับ Rescue Team:
  // View Emergency Request Detail
  //
  // EmergencyRequest.userId
  //      ↓
  // emergencyInfos/{userId}
  // ==================================================

  Future<EmergencyInfo?> getByUid(String uid) async {
    final normalizedUid = uid.trim();

    if (normalizedUid.isEmpty) {
      return null;
    }

    try {
      final snapshot = await _collection.doc(normalizedUid).get();

      if (!snapshot.exists) {
        return null;
      }

      return EmergencyInfo.fromFirestore(snapshot);
    } on FirebaseException catch (error) {
      debugPrint(
        'EmergencyInfo getByUid error: '
        '${error.code} ${error.message}',
      );

      throw EmergencyInfoException(
        _firebaseErrorMessage(error),
        code: error.code,
      );
    } on FormatException catch (error) {
      debugPrint(
        'EmergencyInfo getByUid parse error: '
        '$error',
      );

      throw const EmergencyInfoException(
        'ข้อมูลฉุกเฉินของผู้ประสบภัยไม่ถูกต้อง',
        code: 'invalid-data',
      );
    }
  }
}
