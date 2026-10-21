import 'package:flutter/foundation.dart';

import '../../data/models/rescue_account_model.dart';
import 'rescue_session.dart';
import 'rescue_session_storage.dart';

enum AppUserRole { guest, rescueTeam, admin }

class AuthSessionController extends ChangeNotifier {
  AuthSessionController({RescueSessionStorage? sessionStorage})
    : _sessionStorage = sessionStorage ?? RescueSessionStorage();

  final RescueSessionStorage _sessionStorage;

  AppUserRole _role = AppUserRole.guest;

  RescueSession? _rescueSession;

  bool _isRestoring = true;

  // ==================================================
  // Getters
  // ==================================================

  AppUserRole get role => _role;

  RescueSession? get rescueSession => _rescueSession;

  bool get isAuthenticated => _role != AppUserRole.guest;

  bool get isGuest => _role == AppUserRole.guest;

  bool get isRescueTeam => _role == AppUserRole.rescueTeam;

  bool get isAdmin => _role == AppUserRole.admin;

  bool get isRestoring => _isRestoring;

  // ==================================================
  // Restore Session
  // ==================================================

  Future<void> restoreSession() async {
    _isRestoring = true;

    notifyListeners();

    try {
      final session = await _sessionStorage.load();

      if (session == null) {
        _role = AppUserRole.guest;

        _rescueSession = null;

        return;
      }

      _rescueSession = session;

      _role = AppUserRole.rescueTeam;

      debugPrint(
        'Rescue session restored: '
        '${session.username}',
      );
    } catch (error) {
      debugPrint('Restore rescue session failed: $error');

      _role = AppUserRole.guest;

      _rescueSession = null;
    } finally {
      _isRestoring = false;

      notifyListeners();
    }
  }

  // ==================================================
  // Rescue Login
  // ==================================================

  Future<void> signInRescue(RescueAccount account) async {
    final session = RescueSession.fromAccount(account);

    // เปลี่ยน State
    _role = AppUserRole.rescueTeam;

    _rescueSession = session;

    notifyListeners();

    // Save ลงเครื่อง
    await _sessionStorage.save(session);

    debugPrint(
      'Rescue session created: '
      '${session.username}',
    );
  }

  // ==================================================
  // Admin
  // ==================================================

  void signInAdmin() {
    _role = AppUserRole.admin;

    _rescueSession = null;

    notifyListeners();
  }

  // ==================================================
  // Logout
  // ==================================================

  Future<void> signOut() async {
    await _sessionStorage.clear();

    _role = AppUserRole.guest;

    _rescueSession = null;

    notifyListeners();

    debugPrint('Rescue session cleared');
  }
}
