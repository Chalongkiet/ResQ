import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/image_source_picker.dart';
import '../controllers/emergency_tracking_controller.dart';

Future<bool> showSafetyConfirmationPopup({
  required BuildContext context,
  required EmergencyTrackingController controller,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SafetyConfirmationPopup(controller: controller),
      ) ??
      false;
}

class _SafetyConfirmationPopup extends StatefulWidget {
  const _SafetyConfirmationPopup({required this.controller});

  final EmergencyTrackingController controller;

  @override
  State<_SafetyConfirmationPopup> createState() =>
      _SafetyConfirmationPopupState();
}

class _SafetyConfirmationPopupState extends State<_SafetyConfirmationPopup> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    final success = await widget.controller.updateSafetyStatus();
    if (mounted && success) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !controller.isUpdatingSafety,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Text(
                    'ยืนยันความปลอดภัย',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'ยืนยันว่าขณะนี้คุณปลอดภัยแล้ว เพื่อให้ระบบปิดการติดตามคำร้องนี้',
                        textAlign: TextAlign.center,
                        style: TextStyle(height: 1.45),
                      ),
                      const SizedBox(height: 18),
                      const _FieldLabel(
                        text: 'รูปภาพยืนยัน',
                        requiredField: true,
                      ),
                      const SizedBox(height: 8),
                      _SafetyImagePicker(
                        image: controller.selectedSafetyImage,
                        isPicking: controller.isPickingSafetyImage,
                        enabled: !controller.isUpdatingSafetyStatus,
                        onPick: () async {
                          final source = await showImageSourcePicker(context);
                          if (source != null) {
                            await controller.pickSafetyImage(source);
                          }
                        },
                        onRemove: controller.removeSafetyImage,
                      ),
                      if (controller.safetyErrorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          controller.safetyErrorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: controller.isUpdatingSafety ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: controller.isUpdatingSafetyStatus
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'ยืนยัน',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                      ),
                      TextButton(
                        onPressed: controller.isUpdatingSafety
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('ยังไม่ยืนยัน'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SafetyImagePicker extends StatelessWidget {
  const _SafetyImagePicker({
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

  @override
  Widget build(BuildContext context) {
    final selectedImage = image;
    final theme = Theme.of(context);

    if (selectedImage == null) {
      return Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled && !isPicking ? onPick : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Center(
              child: isPicking
                  ? const CircularProgressIndicator()
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 38),
                        SizedBox(height: 8),
                        Text(
                          'เพิ่มรูปภาพยืนยัน',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.file(
              File(selectedImage.path),
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: theme.colorScheme.surfaceContainerLow,
                alignment: Alignment.center,
                child: const Text('ไม่สามารถแสดงรูปภาพได้'),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(
              onPressed: enabled ? onRemove : null,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, this.requiredField = false});

  final String text;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (requiredField)
            TextSpan(
              text: ' *',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
  }
}
