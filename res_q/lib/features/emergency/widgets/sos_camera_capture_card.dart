import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../controllers/sos_camera_controller.dart';
import '../../../shared/widgets/image_source_picker.dart';

class SosCameraCaptureCard extends StatelessWidget {
  const SosCameraCaptureCard({super.key, required this.controller});

  final SosCameraController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.hasImage)
          _buildImagePreview(context)
        else
          _buildCameraButton(context),

        if (controller.errorMessage != null) ...[
          const SizedBox(height: 8),
          _buildError(context),
        ],

        const SizedBox(height: 8),

        _buildRequirement(context),
      ],
    );
  }

  // ==================================================
  // No Image
  // ==================================================

  Widget _buildCameraButton(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: controller.isCapturing ? null : () => _chooseImage(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: controller.isCapturing
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('กำลังเปิดรูปภาพ...'),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 28,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'เพิ่มรูปสถานที่เกิดเหตุ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'ถ่ายรูปใหม่หรือเลือกจากคลังภาพ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ==================================================
  // Preview
  // ==================================================

  Widget _buildImagePreview(BuildContext context) {
    final theme = Theme.of(context);

    final imagePath = controller.imagePath;

    if (imagePath == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==========================================
          // Image
          // ==========================================
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.file(
              File(imagePath),
              fit: BoxFit.cover,

              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined, size: 42),
                  ),
                );
              },
            ),
          ),

          // ==========================================
          // Image Info + Actions
          // ==========================================
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 20,
                    ),

                    const SizedBox(width: 7),

                    Expanded(
                      child: Text(
                        'เพิ่มรูปภาพแล้ว',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    if (controller.formattedImageSize.isNotEmpty)
                      Text(
                        controller.formattedImageSize,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.isCapturing
                            ? null
                            : () => _chooseImage(context),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('เปลี่ยนรูป'),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.removeImage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('ลบรูป'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseImage(BuildContext context) async {
    final source = await showImageSourcePicker(context);
    if (source != null) await controller.pickImage(source);
  }

  // ==================================================
  // Error
  // ==================================================

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.onErrorContainer,
            size: 20,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              controller.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // Requirement
  // ==================================================

  Widget _buildRequirement(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),

        const SizedBox(width: 6),

        Expanded(
          child: Text(
            'รองรับ JPG, JPEG, PNG ขนาดไม่เกิน 5 MB และสามารถไม่แนบรูปได้',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
