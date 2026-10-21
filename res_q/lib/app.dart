import 'dart:async';

import 'package:flutter/material.dart';

import 'core/auth/auth_scope.dart';
import 'core/auth/auth_session_controller.dart';
import 'core/auth/citizen_identity_service.dart';
import 'core/emergency_info/emergency_info_setup_controller.dart';
import 'core/routing/app_router.dart';
import 'core/routing/app_routes.dart';
import 'core/routing/last_page_store.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/theme_scope.dart';
import 'data/services/emergency_request_service.dart';

class ResQApp extends StatefulWidget {
  const ResQApp({
    super.key,
    required this.authController,
    required this.lastPageStore,
    required this.initialLocation,
  });

  final AuthSessionController authController;
  final LastPageStore lastPageStore;
  final String initialLocation;

  @override
  State<ResQApp> createState() => _ResQAppState();
}

class _ResQAppState extends State<ResQApp> {
  late final ThemeController _themeController;

  late final AuthSessionController _authController;

  late final CitizenIdentityService _citizenIdentityService;

  late final EmergencyRequestService _emergencyRequestService;

  late final EmergencyInfoSetupController _emergencyInfoController;

  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();

    // ==================================================
    // Theme
    // ==================================================

    _themeController = ThemeController();

    // ==================================================
    // Rescue Authentication Session
    // ==================================================

    _authController = widget.authController;

    // ==================================================
    // Citizen Anonymous Identity
    // ==================================================

    _citizenIdentityService = CitizenIdentityService();

    _emergencyRequestService = EmergencyRequestService(
      identityService: _citizenIdentityService,
    );

    // ==================================================
    // Emergency Info Setup State
    // ==================================================

    _emergencyInfoController = EmergencyInfoSetupController();

    // ==================================================
    // Router
    // ==================================================

    _appRouter = AppRouter(
      authController: _authController,
      emergencyInfoController: _emergencyInfoController,
      initialLocation: widget.initialLocation,
    );

    _appRouter.router.routeInformationProvider.addListener(_rememberLastPage);

    // ==================================================
    // Startup
    // ==================================================

    _initializeCitizen();
  }

  void _rememberLastPage() {
    final location = _appRouter.router.routeInformationProvider.value.uri
        .toString();
    unawaited(widget.lastPageStore.save(location));
  }

  // ==================================================
  // Initial Citizen Flow
  // ==================================================

  Future<void> _initializeCitizen() async {
    try {
      // 1. สร้าง/โหลด Anonymous UID ก่อน
      final user = await _citizenIdentityService.ensureIdentity();

      debugPrint('CITIZEN UID => ${user.uid}');

      // 2. เริ่มโหลด Emergency Info พร้อมกับตรวจคำร้องเดิม
      // เพื่อไม่ให้ startup งานหนึ่งขวางอีกงานหนึ่ง
      final emergencyInfoInitialization = _emergencyInfoController.initialize();

      if (!_authController.isAuthenticated) {
        await _restoreActiveEmergencyRequestAtStartup(user.uid);
      }

      await emergencyInfoInitialization;
    } on CitizenIdentityException catch (error) {
      debugPrint(
        'Citizen identity initialization failed: '
        '${error.message}',
      );
    } catch (error) {
      debugPrint('App initialization failed: $error');
    }
  }

  Future<void> _restoreActiveEmergencyRequestAtStartup(String userId) async {
    try {
      // WAITING  -> หน้ารอกู้ภัย
      // ACCEPTED -> หน้าติดตามการช่วยเหลือ
      final activeRequest = await _emergencyRequestService
          .getActiveRequestByUserId(userId: userId)
          .timeout(const Duration(seconds: 6));

      if (!mounted || activeRequest == null) {
        return;
      }

      // อย่าเปลี่ยนหน้า หากระหว่างรอตรวจ Firestore
      // ผู้ใช้เข้าสู่ระบบทีมกู้ภัยไปแล้ว
      if (_authController.isAuthenticated) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _authController.isAuthenticated) {
          return;
        }

        _appRouter.router.goNamed(
          AppRouteNames.emergencyTracking,
          pathParameters: {'requestId': activeRequest.requestId},
        );
      });
    } catch (error) {
      // Startup ต้องยังเข้า Home ได้ แม้ตรวจคำร้องเดิมชั่วคราวไม่สำเร็จ
      // เมื่อเปิดหน้า SOS จะมีการตรวจซ้ำและแสดงปุ่มลองใหม่อีกชั้น
      debugPrint('Restore active emergency request at startup failed: $error');
    }
  }

  @override
  void dispose() {
    _appRouter.router.routeInformationProvider.removeListener(
      _rememberLastPage,
    );

    _appRouter.dispose();

    _emergencyInfoController.dispose();

    _authController.dispose();

    _themeController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_themeController, _authController]),
      builder: (context, child) {
        return AuthScope(
          controller: _authController,
          child: ThemeScope(
            controller: _themeController,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              title: 'ResQ',

              theme: AppTheme.light,

              darkTheme: AppTheme.dark,

              themeMode: _themeController.themeMode,

              routerConfig: _appRouter.router,
            ),
          ),
        );
      },
    );
  }
}
