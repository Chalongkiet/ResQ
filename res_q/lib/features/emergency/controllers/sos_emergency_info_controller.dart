import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/auth/citizen_identity_service.dart';
import '../models/sos_emergency_info_summary.dart';

enum SosEmergencyInfoStatus { loading, ready, notFound, error }

class SosEmergencyInfoController extends ChangeNotifier {
  SosEmergencyInfoController({
    FirebaseFirestore? firestore,
    CitizenIdentityService? identityService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _identityService = identityService ?? CitizenIdentityService();

  final FirebaseFirestore _firestore;
  final CitizenIdentityService _identityService;

  static const String _collectionName = 'emergencyInfos';

  SosEmergencyInfoStatus _status = SosEmergencyInfoStatus.loading;

  SosEmergencyInfoSummary? _info;

  String? _errorMessage;

  bool _isDisposed = false;

  SosEmergencyInfoStatus get status => _status;

  SosEmergencyInfoSummary? get info => _info;

  String? get errorMessage => _errorMessage;

  bool get isLoading => _status == SosEmergencyInfoStatus.loading;

  bool get isReady => _status == SosEmergencyInfoStatus.ready;

  bool get isNotFound => _status == SosEmergencyInfoStatus.notFound;

  bool get hasError => _status == SosEmergencyInfoStatus.error;

  // ==================================================
  // Load
  // ==================================================

  Future<void> load() async {
    _status = SosEmergencyInfoStatus.loading;

    _info = null;

    _errorMessage = null;

    _notify();

    try {
      // Citizen ของระบบเราใช้ Anonymous Firebase UID
      final user = await _identityService.ensureIdentity();

      if (_isDisposed) {
        return;
      }

      // emergencyInfos/{uid}
      //
      // อ่านเพียง Document ของผู้ใช้ปัจจุบัน
      final snapshot = await _firestore
          .collection(_collectionName)
          .doc(user.uid)
          .get();

      if (_isDisposed) {
        return;
      }

      if (!snapshot.exists) {
        _status = SosEmergencyInfoStatus.notFound;

        _notify();

        return;
      }

      final data = snapshot.data();

      if (data == null) {
        _status = SosEmergencyInfoStatus.notFound;

        _notify();

        return;
      }

      final emergencyInfo = SosEmergencyInfoSummary.fromMap(data);

      // Required fields ที่ควรมีจาก Prepare Emergency Info
      if (emergencyInfo.fullName.isEmpty ||
          emergencyInfo.phoneNumber.isEmpty ||
          emergencyInfo.bloodGroup.isEmpty ||
          emergencyInfo.emergencyContactName.isEmpty ||
          emergencyInfo.emergencyContactPhone.isEmpty) {
        _status = SosEmergencyInfoStatus.error;

        _errorMessage = 'ข้อมูลฉุกเฉินของคุณไม่สมบูรณ์';

        _notify();

        return;
      }

      _info = emergencyInfo;

      _status = SosEmergencyInfoStatus.ready;

      _notify();
    } on FirebaseException catch (error) {
      if (_isDisposed) {
        return;
      }

      debugPrint('Load SOS emergency info failed: ${error.code}');

      _status = SosEmergencyInfoStatus.error;

      _errorMessage = 'ไม่สามารถโหลดข้อมูลผู้ประสบภัยได้';

      _notify();
    } catch (error) {
      if (_isDisposed) {
        return;
      }

      debugPrint('Load SOS emergency info failed: $error');

      _status = SosEmergencyInfoStatus.error;

      _errorMessage = 'เกิดข้อผิดพลาดในการโหลดข้อมูลผู้ประสบภัย';

      _notify();
    }
  }

  Future<void> retry() async {
    await load();
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
