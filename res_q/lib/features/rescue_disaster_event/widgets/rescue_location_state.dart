import 'package:flutter/material.dart';

import '../../../core/location/location_result.dart';
import '../../home/controllers/home_map_controller.dart';

class RescueLocationState extends StatelessWidget {
  const RescueLocationState({super.key, required this.controller});

  final HomeMapController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.locationStatus;

    switch (status) {
      // ==================================================
      // GPS Disabled
      // ==================================================

      case LocationResultStatus.serviceDisabled:
        return _LocationProblem(
          icon: Icons.location_off_rounded,
          title: 'ยังไม่ได้เปิดบริการตำแหน่ง',
          description: 'กรุณาเปิด GPS หรือบริการตำแหน่งเพื่อใช้งานแผนที่',
          buttonText: 'เปิดการตั้งค่าตำแหน่ง',
          onPressed: controller.openLocationSettings,
        );

      // ==================================================
      // Permission Denied
      // ==================================================

      case LocationResultStatus.permissionDenied:
        return _LocationProblem(
          icon: Icons.location_disabled_rounded,
          title: 'ยังไม่ได้อนุญาตตำแหน่ง',
          description: 'ResQ ต้องใช้ตำแหน่งของทีมกู้ภัยเพื่อแสดงบนแผนที่',
          buttonText: 'ลองอีกครั้ง',
          onPressed: controller.refreshLocation,
        );

      // ==================================================
      // Permission Denied Forever
      // ==================================================

      case LocationResultStatus.permissionDeniedForever:
        return _LocationProblem(
          icon: Icons.settings_rounded,
          title: 'ไม่ได้รับสิทธิ์ตำแหน่ง',
          description: 'กรุณาเปิดสิทธิ์ตำแหน่งจากการตั้งค่าของแอป',
          buttonText: 'เปิดการตั้งค่า',
          onPressed: controller.openAppSettings,
        );

      // ==================================================
      // Timeout / Error
      // ==================================================

      case LocationResultStatus.timeout:
      case LocationResultStatus.error:
        return _LocationProblem(
          icon: Icons.location_searching_rounded,
          title: 'ไม่สามารถหาตำแหน่งได้',
          description: controller.locationMessage ?? 'กรุณาลองใหม่อีกครั้ง',
          buttonText: 'ลองอีกครั้ง',
          onPressed: controller.refreshLocation,
        );

      // ==================================================
      // Loading
      // ==================================================

      case LocationResultStatus.success:
      case null:
        return const _LocationLoading();
    }
  }
}

// ==================================================
// Loading
// ==================================================

class _LocationLoading extends StatelessWidget {
  const _LocationLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 16),
            Text('กำลังค้นหาตำแหน่งของคุณ...', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ==================================================
// Problem
// ==================================================

class _LocationProblem extends StatelessWidget {
  const _LocationProblem({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;

  final String title;

  final String description;

  final String buttonText;

  final Future<dynamic> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.primary),

            const SizedBox(height: 20),

            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: 22),

            FilledButton.icon(
              onPressed: () async {
                await onPressed();
              },
              icon: const Icon(Icons.settings_rounded),
              label: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
