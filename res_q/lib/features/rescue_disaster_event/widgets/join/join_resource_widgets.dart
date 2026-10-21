import 'package:flutter/material.dart';

import '../../models/rescue_member.dart';
import '../../models/rescue_vehicle.dart';

// ==================================================
// Select Button
// ==================================================

class JoinSelectButton extends StatelessWidget {
  const JoinSelectButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

// ==================================================
// Empty Box
// ==================================================

class JoinEmptyBox extends StatelessWidget {
  const JoinEmptyBox({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================
// Selected Vehicle
// ==================================================

class JoinSelectedVehicleItem extends StatelessWidget {
  const JoinSelectedVehicleItem({
    super.key,
    required this.vehicle,
    required this.enabled,
    required this.onRemove,
  });

  final RescueVehicle vehicle;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ประเภทยานพาหนะ',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 6),

        JoinValueBox(
          text: vehicle.vehicleType.trim().isEmpty ? '-' : vehicle.vehicleType,
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            const Expanded(
              child: Text(
                'ป้ายทะเบียน (ถ้ามี)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),

            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'ลบ',
              onPressed: enabled ? onRemove : null,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),

        JoinValueBox(
          text: vehicle.vehiclePlate.trim().isEmpty
              ? '-'
              : vehicle.vehiclePlate,
        ),
      ],
    );
  }
}

// ==================================================
// Selected Member
// ==================================================

class JoinSelectedMemberItem extends StatelessWidget {
  const JoinSelectedMemberItem({
    super.key,
    required this.number,
    required this.member,
    required this.enabled,
    required this.onRemove,
  });

  final int number;
  final RescueMember member;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          child: Text(
            '$number',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ชื่อ-นามสกุล',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 5),

              JoinValueBox(
                text: member.fullName.trim().isEmpty ? '-' : member.fullName,
              ),

              const SizedBox(height: 10),

              const Text(
                'เบอร์โทร',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 5),

              JoinValueBox(
                text: member.phoneNumber.trim().isEmpty
                    ? '-'
                    : member.phoneNumber,
              ),

              const SizedBox(height: 10),

              const Text(
                'ตำแหน่ง',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 5),

              JoinValueBox(
                text: member.position.trim().isEmpty ? '-' : member.position,
              ),
            ],
          ),
        ),

        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'ลบ',
          onPressed: enabled ? onRemove : null,
          icon: Icon(
            Icons.delete_outline_rounded,
            color: theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}

// ==================================================
// Value Box
// ==================================================

class JoinValueBox extends StatelessWidget {
  const JoinValueBox({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 40),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}
