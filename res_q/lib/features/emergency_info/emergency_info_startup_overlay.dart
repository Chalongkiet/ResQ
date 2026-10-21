import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/emergency_info/emergency_info_setup_controller.dart';
import 'prepare_emergency_info_page.dart';

class EmergencyInfoStartupOverlay extends StatelessWidget {
  const EmergencyInfoStartupOverlay({
    super.key,
    required this.controller,
    required this.child,
  });

  final EmergencyInfoSetupController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // ============================================
            // Main Application
            //
            // Home / Map / Bottom Navigation
            // ถูกสร้างและทำงานตามปกติอยู่ด้านหลัง
            // ============================================
            child,

            // ============================================
            // Checking
            // ============================================
            if (controller.isChecking) const _CheckingOverlay(),

            // ============================================
            // Emergency Info Required
            // ============================================
            if (controller.isRequired)
              _PrepareEmergencyInfoOverlay(controller: controller),

            // ============================================
            // Error
            // ============================================
            if (controller.hasError) _ErrorOverlay(onRetry: controller.refresh),
          ],
        );
      },
    );
  }
}

class _PrepareEmergencyInfoOverlay extends StatelessWidget {
  const _PrepareEmergencyInfoOverlay({required this.controller});

  final EmergencyInfoSetupController controller;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Positioned.fill(
      child: Stack(
        children: [
          // ============================================
          // Blur Home
          // ============================================
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.black.withValues(alpha: 0.18)),
            ),
          ),

          // ============================================
          // Block interaction with Home
          // ============================================
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Colors.transparent),
          ),

          // ============================================
          // Popup
          // ============================================
          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  mediaQuery.viewInsets.bottom + 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 560,
                    maxHeight: mediaQuery.size.height * 0.88,
                  ),
                  child: PrepareEmergencyInfoPage(
                    onCompleted: () {
                      controller.markCompleted();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckingOverlay extends StatelessWidget {
  const _CheckingOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(color: Colors.black.withValues(alpha: 0.08)),
            ),
          ),

          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Colors.transparent),
          ),

          Center(
            child: Material(
              color: theme.colorScheme.surface,
              elevation: 8,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('กำลังตรวจสอบข้อมูลฉุกเฉิน...'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.black.withValues(alpha: 0.18)),
            ),
          ),

          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Colors.transparent),
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Material(
                  color: theme.colorScheme.surface,
                  elevation: 10,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 56,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'ไม่สามารถตรวจสอบข้อมูลฉุกเฉินได้',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ตแล้วลองใหม่อีกครั้ง',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () {
                              onRetry();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('ลองใหม่'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
