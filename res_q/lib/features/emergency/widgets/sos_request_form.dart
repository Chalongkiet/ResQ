import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/validators/emergency_request_validator.dart';
import '../models/emergency_situation.dart';
import '../controllers/sos_camera_controller.dart';
import '../controllers/sos_location_controller.dart';
import 'sos_camera_capture_card.dart';

class SosRequestForm extends StatelessWidget {
  const SosRequestForm({
    super.key,
    required this.locationController,
    required this.cameraController,
    required this.detailController,
    required this.selectedSituations,
    required this.onSituationToggled,
    required this.affectedCount,
    required this.onDecreaseAffectedCount,
    required this.onIncreaseAffectedCount,
  });

  final SosLocationController locationController;

  final SosCameraController cameraController;

  final TextEditingController detailController;

  final Set<EmergencySituation> selectedSituations;

  final ValueChanged<EmergencySituation> onSituationToggled;

  final int affectedCount;

  final VoidCallback onDecreaseAffectedCount;

  final VoidCallback onIncreaseAffectedCount;

  @override
  Widget build(BuildContext context) {
    final disaster = locationController.currentDisasterEvent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==================================================
        // Disaster Type
        // ==================================================
        const _FieldTitle(title: 'ประเภทเหตุฉุกเฉิน', required: true),

        const SizedBox(height: 8),

        _DisasterTypeField(locationController: locationController),

        const SizedBox(height: 20),

        const _FieldTitle(
          title: 'สถานการณ์ของคุณ',
          subtitle:
              'เลือกได้มากกว่า 1 ข้อ เพื่อช่วยให้ทีมกู้ภัยประเมินเหตุได้เร็วขึ้น',
          required: true,
        ),

        const SizedBox(height: 10),

        _SituationSelector(
          selectedSituations: selectedSituations,
          onToggled: onSituationToggled,
        ),

        if (selectedSituations.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'กรุณาเลือกอย่างน้อย 1 ข้อ',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),

        const SizedBox(height: 20),

        const _FieldTitle(
          title: 'จำนวนผู้ประสบภัย',
          subtitle: 'รวมตัวคุณและผู้ที่อยู่ด้วยกันในจุดเกิดเหตุ',
          required: true,
        ),

        const SizedBox(height: 8),

        _AffectedCountSelector(
          count: affectedCount,
          onDecrease: onDecreaseAffectedCount,
          onIncrease: onIncreaseAffectedCount,
        ),

        const SizedBox(height: 20),

        // ==================================================
        // Camera
        // ==================================================
        const _FieldTitle(
          title: 'แนบรูปถ่าย',
          subtitle:
              'ถ่ายภาพบริเวณรอบตัวเพื่อให้ทีมกู้ภัยเห็นจุดสังเกตและสภาพแวดล้อม',
        ),

        const SizedBox(height: 8),

        SosCameraCaptureCard(controller: cameraController),

        const SizedBox(height: 20),

        // ==================================================
        // Request Detail
        // ==================================================
        const _FieldTitle(
          title: 'รายละเอียดเพิ่มเติม (ไม่บังคับ)',
          subtitle: 'พิมพ์เฉพาะข้อมูลที่ตัวเลือกด้านบนยังบอกไม่ครบ',
        ),

        const SizedBox(height: 8),

        TextFormField(
          controller: detailController,
          minLines: 2,
          maxLines: 4,
          maxLength: EmergencyRequestValidator.maxAdditionalDetailLength,
          textInputAction: TextInputAction.newline,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) =>
              EmergencyRequestValidator.validateOtherSituationDetail(
                otherSelected: selectedSituations.contains(
                  EmergencySituation.other,
                ),
                value: value,
              ),
          decoration: InputDecoration(
            hintText: 'เช่น อยู่ชั้น 2 ประตูสีแดง...',
            alignLabelWithHint: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ),

        // ==================================================
        // Outside Disaster Area
        // ==================================================
        if (disaster == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                  size: 19,
                ),

                const SizedBox(width: 7),

                Expanded(
                  child: Text(
                    'ไม่สามารถส่งคำร้องได้จนกว่าจะตรวจพบว่าคุณอยู่ในหรือใกล้พื้นที่ภัยพิบัติ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AffectedCountSelector extends StatelessWidget {
  const _AffectedCountSelector({
    required this.count,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int count;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'ลดจำนวนผู้ประสบภัย',
            onPressed: count > 1 ? onDecrease : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: 'จำนวนผู้ประสบภัย $count คน',
              child: Column(
                children: [
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text('คน'),
                ],
              ),
            ),
          ),
          IconButton.filled(
            tooltip: 'เพิ่มจำนวนผู้ประสบภัย',
            onPressed: count < EmergencyRequestValidator.maxAffectedCount
                ? onIncrease
                : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _SituationSelector extends StatelessWidget {
  const _SituationSelector({
    required this.selectedSituations,
    required this.onToggled,
  });

  final Set<EmergencySituation> selectedSituations;
  final ValueChanged<EmergencySituation> onToggled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 9,
      children: EmergencySituation.values
          .map((situation) {
            final selected = selectedSituations.contains(situation);
            return FilterChip(
              selected: selected,
              showCheckmark: true,
              avatar: Icon(_iconOf(situation), size: 19),
              label: Text(situation.label),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              selectedColor: AppColors.lightEmergencyContainer,
              checkmarkColor: AppColors.emergency,
              labelStyle: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
              onSelected: (_) => onToggled(situation),
            );
          })
          .toList(growable: false),
    );
  }

  static IconData _iconOf(EmergencySituation situation) {
    return switch (situation) {
      EmergencySituation.trapped => Icons.home_work_outlined,
      EmergencySituation.injured => Icons.medical_services_outlined,
      EmergencySituation.child => Icons.child_care_rounded,
      EmergencySituation.elderly => Icons.elderly_rounded,
      EmergencySituation.worsening => Icons.trending_up_rounded,
      EmergencySituation.urgentEvacuation => Icons.directions_run_rounded,
      EmergencySituation.other => Icons.more_horiz_rounded,
    };
  }
}

// ====================================================
// Disaster Type
// ====================================================

class _DisasterTypeField extends StatelessWidget {
  const _DisasterTypeField({required this.locationController});

  final SosLocationController locationController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final disaster = locationController.currentDisasterEvent;

    if (locationController.isDetectingDisaster) {
      return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: _decoration(context),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),

            SizedBox(width: 12),

            Text('กำลังตรวจสอบประเภทภัย...'),
          ],
        ),
      );
    }

    if (disaster == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: _decoration(context, error: true),
        child: Row(
          children: [
            Icon(Icons.location_off_outlined, color: theme.colorScheme.error),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                'ไม่พบเหตุภัยพิบัติในตำแหน่งปัจจุบัน',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _decoration(context),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.lightWarningContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  disaster.disasterType,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                if (disaster.eventName.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),

                  Text(
                    disaster.eventName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Icon(Icons.lock_outline, size: 18),
        ],
      ),
    );
  }

  BoxDecoration _decoration(BuildContext context, {bool error = false}) {
    final theme = Theme.of(context);

    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: error
            ? theme.colorScheme.error.withValues(alpha: 0.5)
            : theme.colorScheme.outlineVariant,
      ),
    );
  }
}

// ====================================================
// Field Title
// ====================================================

class _FieldTitle extends StatelessWidget {
  const _FieldTitle({
    required this.title,
    this.subtitle,
    this.required = false,
  });

  final String title;

  final String? subtitle;

  final bool required;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            if (required) ...[
              const SizedBox(width: 4),

              Text('*', style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),

        if (subtitle != null) ...[
          const SizedBox(height: 3),

          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
