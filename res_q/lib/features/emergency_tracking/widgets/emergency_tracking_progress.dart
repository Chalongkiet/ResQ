import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class EmergencyTrackingProgress extends StatelessWidget {
  const EmergencyTrackingProgress({super.key, required this.currentStep});

  final int currentStep;

  static const int _totalSteps = 6;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_totalSteps * 2 - 1, (index) {
        // ==========================================
        // Circle
        // ==========================================

        if (index.isEven) {
          final step = (index ~/ 2) + 1;

          return _StepCircle(step: step, active: step <= currentStep);
        }

        // ==========================================
        // Connector
        // ==========================================

        final previousStep = (index ~/ 2) + 1;

        return Expanded(
          child: Container(
            height: 3,
            color: previousStep < currentStep
                ? AppColors.emergency
                : const Color(0xFFE5E7EB),
          ),
        );
      }),
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({required this.step, required this.active});

  final int step;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.emergency : Colors.white,
        border: Border.all(
          color: active ? AppColors.emergency : const Color(0xFFD1D5DB),
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$step',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : const Color(0xFF6B7280),
        ),
      ),
    );
  }
}
