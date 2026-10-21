import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/rescue_account_model.dart';
import 'rescue_login_result.dart';

class RescueAccountService {
  RescueAccountService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ต้องตรงกับชื่อ Collection ใน Firestore
  static const String _collectionName = 'RescueOrganization';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionName);

  // ==================================================
  // Find Rescue Account by Username
  // ==================================================

  Future<RescueAccount?> findByUsername(String username) async {
    final normalizedUsername = username.trim();

    if (normalizedUsername.isEmpty) {
      return null;
    }

    try {
      if (kDebugMode) {
        debugPrint(
          'Searching rescue account: '
          '$normalizedUsername',
        );
      }

      final snapshot = await _collection
          .where('rescue_username', isEqualTo: normalizedUsername)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (kDebugMode) {
          debugPrint('Rescue account not found');
        }

        return null;
      }

      final document = snapshot.docs.first;

      if (kDebugMode) {
        debugPrint(
          'Rescue account found: '
          '${document.id}',
        );
      }

      return RescueAccount.fromFirestore(document);
    } on FirebaseException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Find rescue account failed: '
          '${error.code}',
        );
      }

      rethrow;
    }
  }

  // ==================================================
  // Login
  // ==================================================

  Future<RescueLoginResult> login({
    required String username,
    required String password,
  }) async {
    // --------------------------------------------------
    // 1. Find Account
    // --------------------------------------------------

    final account = await findByUsername(username);

    if (account == null) {
      return const RescueLoginResult(status: RescueLoginStatus.accountNotFound);
    }

    // --------------------------------------------------
    // 2. Check Password
    // --------------------------------------------------

    if (account.password != password) {
      return const RescueLoginResult(status: RescueLoginStatus.wrongPassword);
    }

    // --------------------------------------------------
    // 3. Verify Status
    // --------------------------------------------------

    if (!account.verifyStatus) {
      return RescueLoginResult(
        status: RescueLoginStatus.notApproved,
        account: account,
      );
    }

    // --------------------------------------------------
    // 4. Account Active
    // --------------------------------------------------

    if (!account.isActive) {
      return RescueLoginResult(
        status: RescueLoginStatus.inactive,
        account: account,
      );
    }

    // --------------------------------------------------
    // 5. Success
    // --------------------------------------------------

    return RescueLoginResult(
      status: RescueLoginStatus.success,
      account: account,
    );
  }
}
