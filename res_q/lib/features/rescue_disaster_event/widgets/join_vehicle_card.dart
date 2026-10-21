import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/rescue_vehicle.dart';

class JoinVehicleCard extends StatelessWidget {
  const JoinVehicleCard({
    super.key,
    required this.vehicle,
    required this.onRemove,
  });

  final RescueVehicle vehicle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ReadOnlyField(
                  label: 'ประเภทยานพาหนะ',
                  value: vehicle.vehicleType,
                ),
              ),

              const SizedBox(width: 8),

              IconButton(
                tooltip: 'นำยานพาหนะออก',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.emergency,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _ReadOnlyField(
            label: 'ป้ายทะเบียน (ถ้ามี)',
            value: vehicle.vehiclePlate,
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 6),

        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            value.trim().isEmpty ? '-' : value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
