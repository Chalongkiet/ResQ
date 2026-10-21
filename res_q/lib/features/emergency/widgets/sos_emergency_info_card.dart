import 'package:flutter/material.dart';

import '../controllers/sos_emergency_info_controller.dart';
import '../models/sos_emergency_info_summary.dart';

class SosEmergencyInfoCard extends StatelessWidget {
  const SosEmergencyInfoCard({super.key, required this.controller});

  final SosEmergencyInfoController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);

    if (controller.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (controller.isNotFound) {
      return _ErrorContent(
        title: 'ไม่พบข้อมูลผู้ประสบภัย',
        message: 'กรุณาบันทึกข้อมูลฉุกเฉินส่วนตัวก่อนส่งคำร้องขอความช่วยเหลือ',
        onRetry: controller.retry,
      );
    }

    if (controller.hasError) {
      return _ErrorContent(
        title: 'ไม่สามารถโหลดข้อมูลได้',
        message: controller.errorMessage ?? 'กรุณาลองใหม่อีกครั้ง',
        onRetry: controller.retry,
      );
    }

    final info = controller.info;

    if (info == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.personal_injury_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'ข้อมูลผู้ประสบภัย',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildInformation(context, info),
      ],
    );
  }

  Widget _buildInformation(BuildContext context, SosEmergencyInfoSummary info) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 480;

        if (!useTwoColumns) {
          return Column(
            children: [
              _InformationRow(label: 'ชื่อ - นามสกุล', value: info.fullName),
              _InformationRow(label: 'เบอร์โทร', value: info.phoneNumber),
              _InformationRow(label: 'กรุ๊ปเลือด', value: info.bloodGroup),
              _InformationRow(
                label: 'โรคประจำตัว',
                value: info.displayValue(info.medicalCondition),
              ),
              _InformationRow(
                label: 'ประวัติการแพ้',
                value: info.displayValue(info.allergy),
              ),
              _InformationRow(
                label: 'ยาประจำตัว',
                value: info.displayValue(info.regularMedication),
              ),
              _InformationRow(
                label: 'ผู้ติดต่อฉุกเฉิน',
                value: info.emergencyContactName,
              ),
              _InformationRow(
                label: 'เบอร์ผู้ติดต่อ',
                value: info.emergencyContactPhone,
                showDivider: false,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _InformationRow(
                    label: 'ชื่อ - นามสกุล',
                    value: info.fullName,
                  ),
                  _InformationRow(label: 'เบอร์โทร', value: info.phoneNumber),
                  _InformationRow(
                    label: 'โรคประจำตัว',
                    value: info.displayValue(info.medicalCondition),
                  ),
                  _InformationRow(
                    label: 'ประวัติการแพ้',
                    value: info.displayValue(info.allergy),
                    showDivider: false,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 20),

            Expanded(
              child: Column(
                children: [
                  _InformationRow(label: 'กรุ๊ปเลือด', value: info.bloodGroup),
                  _InformationRow(
                    label: 'ยาประจำตัว',
                    value: info.displayValue(info.regularMedication),
                  ),
                  _InformationRow(
                    label: 'ผู้ติดต่อฉุกเฉิน',
                    value: info.emergencyContactName,
                  ),
                  _InformationRow(
                    label: 'เบอร์ผู้ติดต่อ',
                    value: info.emergencyContactPhone,
                    showDivider: false,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 105,
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (showDivider)
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
      ],
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 34),

        const SizedBox(height: 8),

        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('ลองใหม่'),
        ),
      ],
    );
  }
}
