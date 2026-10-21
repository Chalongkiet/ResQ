import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class LeaveImagePicker extends StatelessWidget {
  const LeaveImagePicker({
    super.key,
    required this.image,
    required this.isPicking,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? image;

  final bool isPicking;

  final bool enabled;

  final VoidCallback onPick;

  final VoidCallback onRemove;

  // ==================================================
  // Build
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final selectedImage = image;

    if (selectedImage == null) {
      return _buildEmptyState(context);
    }

    return _buildPreview(context, selectedImage);
  }

  // ==================================================
  // Empty
  // ==================================================

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled && !isPicking ? onPick : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 145,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Center(
            child: isPicking
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      SizedBox(height: 10),
                      Text('กำลังเปิดรูปภาพ...'),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 38,
                        color: theme.colorScheme.primary,
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'เลือกรูปภาพยืนยัน',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'JPG, JPEG หรือ PNG ไม่เกิน 5 MB',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ==================================================
  // Preview
  // ==================================================

  Widget _buildPreview(BuildContext context, XFile selectedImage) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // ==================================================
              // Image
              // ==================================================
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.file(
                  File(selectedImage.path),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: theme.colorScheme.surfaceContainerLow,
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined, size: 34),
                          SizedBox(height: 6),
                          Text('ไม่สามารถแสดงรูปภาพได้'),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ==================================================
              // Remove
              // ==================================================
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.58),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: enabled ? onRemove : null,
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ==================================================
        // Change Image
        // ==================================================
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: enabled && !isPicking ? onPick : null,
            icon: const Icon(Icons.image_outlined, size: 18),
            label: const Text('เปลี่ยนรูปภาพ'),
          ),
        ),
      ],
    );
  }
}
