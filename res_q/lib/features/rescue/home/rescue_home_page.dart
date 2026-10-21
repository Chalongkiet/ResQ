import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_scope.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/success_alert_dialog.dart';
import '../../rescue_disaster_event/rescue_disaster_event_page.dart';

class RescueHomePage extends StatefulWidget {
  const RescueHomePage({super.key});

  @override
  State<RescueHomePage> createState() => _RescueHomePageState();
}

class _RescueHomePageState extends State<RescueHomePage> {
  bool _isLoggingOut = false;

  // ==================================================
  // Logout
  //
  // แสดง Dialog ก่อน จากนั้นล้าง Rescue Session
  // และกลับไปหน้า Rescue Login
  // ==================================================

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _showLogoutSuccessDialog();

      if (!mounted) {
        return;
      }

      final authController = AuthScope.of(context);

      await authController.signOut();

      if (!mounted) {
        return;
      }

      debugPrint('RESCUE LOGOUT SUCCESS');
      debugPrint('AUTHENTICATED: ${authController.isAuthenticated}');

      context.go(AppRoutePaths.rescueLogin);
    } catch (error, stackTrace) {
      debugPrint('Rescue logout error: $error');
      debugPrint('$stackTrace');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถออกจากระบบได้ กรุณาลองใหม่อีกครั้ง'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  // ==================================================
  // Logout Success Dialog
  // ==================================================

  Future<void> _showLogoutSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: SuccessAlertDialog(
            title: 'ออกจากระบบสำเร็จ',
            message: 'คุณได้ทำการออกจากระบบแล้ว',
            onConfirm: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
  }

  void _openMissionHistory(String? rescueTeamId) {
    final normalizedTeamId = rescueTeamId?.trim() ?? '';
    if (normalizedTeamId.isEmpty) return;

    context.pushNamed(AppRouteNames.rescueMissionHistory);
  }

  // ==================================================
  // Build
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authController = AuthScope.of(context);
    final session = authController.rescueSession;
    final teamName = session?.rescueTeamName;

    final displayTeamName = teamName != null && teamName.trim().isNotEmpty
        ? teamName
        : 'ทีมกู้ภัย';

    return PopScope(
      // ป้องกันการกด Back แล้วหลุดไปหน้า Citizen
      // ขณะที่ Rescue Session ยังทำงานอยู่
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerLowest,

        // ==============================================
        // Rescue Team App Bar
        // ==============================================
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.health_and_safety_outlined,
                  size: 22,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayTeamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'ทีมกู้ภัย',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Tooltip(
              message: 'ประวัติการช่วยเหลือ',
              child: IconButton(
                onPressed:
                    _isLoggingOut ||
                        (session?.rescueTeamId ?? '').trim().isEmpty
                    ? null
                    : () => _openMissionHistory(session?.rescueTeamId),
                icon: const Icon(Icons.history_rounded),
              ),
            ),
            Tooltip(
              message: 'ออกจากระบบ',
              child: IconButton(
                onPressed: _isLoggingOut ? null : _logout,
                icon: _isLoggingOut
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),

        // ==============================================
        // View Disaster Event
        //
        // อยู่ใน Rescue Home โดยตรง จึงไม่ต้องเพิ่ม Route ใหม่
        // ==============================================
        body: const RescueDisasterEventPage(),
      ),
    );
  }
}
