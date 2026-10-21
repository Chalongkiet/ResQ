import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/rescue_member.dart';

class JoinMemberCard extends StatelessWidget {
  const JoinMemberCard({
    super.key,
    required this.index,
    required this.member,
    required this.onRemove,
  });

  final int index;
  final RescueMember member;
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
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _ReadOnlyField(
                  label: 'ชื่อ-นามสกุล',
                  value: member.fullName,
                ),
              ),

              IconButton(
                tooltip: 'นำสมาชิกออก',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.emergency,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Column(
              children: [
                _ReadOnlyField(label: 'เบอร์โทร', value: member.phoneNumber),

                const SizedBox(height: 12),

                _ReadOnlyField(label: 'ตำแหน่ง', value: member.position),
              ],
            ),
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
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
