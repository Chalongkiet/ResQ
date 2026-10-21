import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CitizenIdentityService {
  CitizenIdentityService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Anonymous user ปัจจุบัน
  User? get currentUser => _auth.currentUser;

  /// UID ที่ใช้ผูกข้อมูลประชาชน
  String? get currentUid => _auth.currentUser?.uid;

  bool get hasIdentity => currentUid != null;

  /// ตรวจให้แน่ใจว่า installation นี้มี Firebase UID
  ///
  /// - ถ้ามี user อยู่แล้ว → ใช้ user เดิม
  /// - ถ้ายังไม่มี → Anonymous Sign-in
  Future<User> ensureIdentity() async {
    final existingUser = _auth.currentUser;

    if (existingUser != null) {
      debugPrint(
        'Citizen identity already exists: '
        '${existingUser.uid}',
      );

      return existingUser;
    }

    try {
      final credential = await _auth.signInAnonymously();

      final user = credential.user;

      if (user == null) {
        throw const CitizenIdentityException(
          'Firebase did not return an anonymous user.',
        );
      }

      debugPrint(
        'Anonymous citizen identity created: '
        '${user.uid}',
      );

      return user;
    } on FirebaseAuthException catch (error) {
      debugPrint(
        'Anonymous authentication failed: '
        '${error.code} ${error.message}',
      );

      throw CitizenIdentityException(_messageForFirebaseError(error));
    } catch (error) {
      debugPrint('Citizen identity error: $error');

      if (error is CitizenIdentityException) {
        rethrow;
      }

      throw const CitizenIdentityException(
        'ไม่สามารถสร้างตัวตนสำหรับอุปกรณ์นี้ได้',
      );
    }
  }

  /// เผื่อ Phase ต่อไปต้องฟัง Auth State
  Stream<User?> watchIdentity() {
    return _auth.authStateChanges();
  }

  static String _messageForFirebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'operation-not-allowed':
        return 'ยังไม่ได้เปิดใช้งาน Anonymous Authentication';

      case 'network-request-failed':
        return 'ไม่สามารถเชื่อมต่อระบบยืนยันตัวตนได้';

      case 'too-many-requests':
        return 'มีการร้องขอมากเกินไป กรุณาลองใหม่ภายหลัง';

      default:
        return 'ไม่สามารถสร้างตัวตนสำหรับอุปกรณ์นี้ได้';
    }
  }
}

class CitizenIdentityException implements Exception {
  const CitizenIdentityException(this.message);

  final String message;

  @override
  String toString() => message;
}
