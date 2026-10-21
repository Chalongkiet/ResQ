import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/public_alert_model.dart';
import '../../features/emergency_tracking/emergency_tracking_page.dart';
import '../../features/emergency/sos_page.dart';
import '../../core/emergency_info/emergency_info_setup_controller.dart';
import '../../features/emergency_info/emergency_info_startup_overlay.dart';
import '../../features/home/citizen_home_page.dart';
import '../../features/news/news_detail_page.dart';
import '../../features/news/news_detail_from_id_page.dart';
import '../../features/news/news_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/rescue/auth/rescue_login_page.dart';
import '../../features/rescue/home/rescue_home_page.dart';
import '../../features/rescue/mission_history/rescue_mission_history_page.dart';
import '../../features/shell/main_shell_page.dart';
import '../auth/auth_session_controller.dart';
import '../auth/auth_scope.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter({
    required AuthSessionController authController,
    required EmergencyInfoSetupController emergencyInfoController,
    String initialLocation = AppRoutePaths.home,
  }) : _authController = authController,
       _emergencyInfoController = emergencyInfoController {
    router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: initialLocation,
      debugLogDiagnostics: true,

      // Auth เปลี่ยนเมื่อ Login / Logout / Restore
      refreshListenable: _authController,

      redirect: _redirect,

      routes: [
        // ==================================================
        // Main Citizen Shell
        // ==================================================
        StatefulShellRoute.indexedStack(
          builder:
              (
                BuildContext context,
                GoRouterState state,
                StatefulNavigationShell navigationShell,
              ) {
                return EmergencyInfoStartupOverlay(
                  controller: _emergencyInfoController,
                  child: MainShellPage(navigationShell: navigationShell),
                );
              },
          branches: [
            // ------------------------------------------------
            // Rescue Login
            // ------------------------------------------------
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutePaths.rescueLogin,
                  name: AppRouteNames.rescueLogin,
                  builder: (context, state) {
                    return const RescueLoginPage();
                  },
                ),
              ],
            ),

            // ------------------------------------------------
            // Citizen Home
            // ------------------------------------------------
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutePaths.home,
                  name: AppRouteNames.home,
                  builder: (context, state) {
                    return const CitizenHomePage();
                  },
                ),
              ],
            ),

            // ------------------------------------------------
            // News
            // ------------------------------------------------
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutePaths.news,
                  name: AppRouteNames.news,
                  builder: (context, state) {
                    return const NewsPage();
                  },
                ),
              ],
            ),

            // ------------------------------------------------
            // Profile
            // ------------------------------------------------
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutePaths.profile,
                  name: AppRouteNames.profile,
                  builder: (context, state) {
                    return const ProfilePage();
                  },
                ),
              ],
            ),
          ],
        ),

        // ==================================================
        // Rescue Team Home
        //
        // อยู่นอก Citizen Bottom Navigation
        // ==================================================
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: AppRoutePaths.rescueHome,
          name: AppRouteNames.rescueHome,
          builder: (context, state) {
            return const RescueHomePage();
          },
          routes: [
            GoRoute(
              path: 'history',
              name: AppRouteNames.rescueMissionHistory,
              builder: (context, state) {
                final teamId = AuthScope.of(
                  context,
                ).rescueSession?.rescueTeamId;
                if (teamId == null || teamId.trim().isEmpty) {
                  return const _InvalidRouteDataPage(
                    message: 'ไม่พบข้อมูลทีมกู้ภัย',
                  );
                }
                return RescueMissionHistoryPage(rescueTeamId: teamId);
              },
            ),
          ],
        ),

        // ==================================================
        // News Detail
        // ==================================================
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: AppRoutePaths.newsDetail,
          name: AppRouteNames.newsDetail,
          builder: (context, state) {
            final alert = state.extra;

            if (alert is! PublicAlert) {
              return NewsDetailFromIdPage(
                newsId: state.pathParameters['newsId'] ?? '',
              );
            }

            return NewsDetailPage(alert: alert);
          },
        ),

        // ==================================================
        // SOS
        // ==================================================
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: AppRoutePaths.sos,
          name: AppRouteNames.sos,
          builder: (context, state) {
            return const SosPage();
          },
        ),

        // ==================================================
        // Emergency Tracking
        // ==================================================
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: AppRoutePaths.emergencyTracking,
          name: AppRouteNames.emergencyTracking,
          builder: (context, state) {
            final requestId = state.pathParameters['requestId'] ?? '';

            return EmergencyTrackingPage(requestId: requestId);
          },
        ),
      ],

      errorBuilder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('ไม่พบหน้าที่ต้องการ')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                state.error?.toString() ?? 'ไม่สามารถเปิดหน้านี้ได้',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }

  final AuthSessionController _authController;

  final EmergencyInfoSetupController _emergencyInfoController;

  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root-navigator');

  late final GoRouter router;

  // ==================================================
  // Route Guard
  // ==================================================

  String? _redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;

    final isRescueHome =
        location == AppRoutePaths.rescueHome ||
        location == AppRoutePaths.rescueMissionHistory;

    final isRescueLogin = location == AppRoutePaths.rescueLogin;

    // ==================================================
    // Restore Session กำลังทำงาน
    //
    // รอให้ Restore เสร็จก่อน
    // ==================================================

    if (_authController.isRestoring) {
      return null;
    }

    // ==================================================
    // ยังไม่ได้ Login
    // แต่พยายามเข้า Rescue Home
    // ==================================================

    if (isRescueHome && !_authController.isAuthenticated) {
      return AppRoutePaths.rescueLogin;
    }

    // ==================================================
    // Login แล้วแต่ไม่ใช่ Rescue Team/Admin
    // ==================================================

    if (isRescueHome &&
        !_authController.isRescueTeam &&
        !_authController.isAdmin) {
      return AppRoutePaths.home;
    }

    // ==================================================
    // มี Rescue Session อยู่แล้ว
    // ถ้ากลับมาหน้า Login ให้เข้า Rescue Home
    // ==================================================

    if (isRescueLogin &&
        _authController.isAuthenticated &&
        (_authController.isRescueTeam || _authController.isAdmin)) {
      return AppRoutePaths.rescueHome;
    }

    return null;
  }

  void dispose() {
    router.dispose();
  }
}

// ====================================================
// Invalid Route
// ====================================================

class _InvalidRouteDataPage extends StatelessWidget {
  const _InvalidRouteDataPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ไม่พบข้อมูล')),
      body: Center(child: Text(message)),
    );
  }
}
