import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/validators/rescue_action_validator.dart';
import '../../controllers/leave_disaster_event_controller.dart';
import '../../../../shared/widgets/image_source_picker.dart';

import 'leave_image_picker.dart';

// ==================================================
// Show Popup
// ==================================================

Future<bool> showLeaveDisasterEventPopup({
  required BuildContext context,
  required String eventId,
  required String deploymentId,
  required String rescueTeamId,
  required LeaveDisasterEventController controller,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return LeaveDisasterEventPopup(
        eventId: eventId,
        deploymentId: deploymentId,
        rescueTeamId: rescueTeamId,
        controller: controller,
      );
    },
  );

  return result ?? false;
}

// ==================================================
// Popup
// ==================================================

class LeaveDisasterEventPopup extends StatefulWidget {
  const LeaveDisasterEventPopup({
    super.key,
    required this.eventId,
    required this.deploymentId,
    required this.rescueTeamId,
    required this.controller,
  });

  final String eventId;

  final String deploymentId;

  final String rescueTeamId;

  final LeaveDisasterEventController controller;

  @override
  State<LeaveDisasterEventPopup> createState() =>
      _LeaveDisasterEventPopupState();
}

class _LeaveDisasterEventPopupState extends State<LeaveDisasterEventPopup> {
  // ==================================================
  // Inputs
  // ==================================================

  final TextEditingController _reasonController = TextEditingController();

  final TextEditingController _detailController = TextEditingController();

  final FocusNode _reasonFocus = FocusNode();

  // ==================================================
  // Lifecycle
  // ==================================================

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(_handleControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _reasonFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);

    _reasonController.dispose();

    _detailController.dispose();

    _reasonFocus.dispose();

    super.dispose();
  }

  // ==================================================
  // Controller Listener
  // ==================================================

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // ==================================================
  // Submit
  // ==================================================

  Future<void> _submit() async {
    if (widget.controller.isBusy) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final success = await widget.controller.submit(
      eventId: widget.eventId,
      deploymentId: widget.deploymentId,
      rescueTeamId: widget.rescueTeamId,
      leaveReason: _reasonController.text,
      leaveDetail: _detailController.text,
    );

    if (!mounted || !success) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  // ==================================================
  // Close
  // ==================================================

  void _close() {
    if (widget.controller.isBusy) {
      return;
    }

    Navigator.of(context).pop(false);
  }

  // ==================================================
  // Build
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final screen = MediaQuery.sizeOf(context);

    final controller = widget.controller;

    return PopScope(
      canPop: !controller.isBusy,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: screen.height * 0.90,
          ),
          child: Column(
            children: [
              // ==================================================
              // Header
              // ==================================================
              _buildHeader(theme),

              Divider(height: 1, color: theme.colorScheme.outlineVariant),

              // ==================================================
              // Form
              // ==================================================
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ==================================================
                        // Reason
                        // ==================================================
                        const _FieldTitle(title: 'เหตุผล', requiredField: true),

                        const SizedBox(height: 7),

                        TextFormField(
                          controller: _reasonController,
                          focusNode: _reasonFocus,
                          enabled: !controller.isBusy,
                          maxLength: 255,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            controller.clearError();
                          },
                          validator: RescueActionValidator.validateLeaveReason,
                          decoration: const InputDecoration(
                            hintText: 'เช่น เข้าถึงพื้นที่ไม่ได้ / น้ำท่วมสูง',
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ==================================================
                        // Detail
                        // ==================================================
                        const _FieldTitle(
                          title: 'รายละเอียดเพิ่มเติม',
                          subtitle: 'ไม่บังคับ',
                        ),

                        const SizedBox(height: 7),

                        TextFormField(
                          controller: _detailController,
                          enabled: !controller.isBusy,
                          maxLength: 255,
                          minLines: 3,
                          maxLines: 5,
                          onChanged: (_) {
                            controller.clearError();
                          },
                          validator:
                              RescueActionValidator.validateOptionalDetail,
                          decoration: const InputDecoration(
                            hintText:
                                'ระบุรายละเอียดเพิ่มเติมเกี่ยวกับการถอนกำลัง',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ==================================================
                        // Confirmation Image
                        // ==================================================
                        const _FieldTitle(
                          title: 'รูปภาพยืนยัน',
                          requiredField: true,
                        ),

                        const SizedBox(height: 8),

                        LeaveImagePicker(
                          image: controller.selectedImage,
                          isPicking: controller.isPickingImage,
                          enabled: !controller.isSubmitting,
                          onPick: () async {
                            final source = await showImageSourcePicker(context);
                            if (source != null) {
                              await controller.pickImage(source);
                            }
                          },
                          onRemove: () {
                            controller.removeImage();
                          },
                        ),

                        // ==================================================
                        // Error
                        // ==================================================
                        if (controller.errorMessage != null) ...[
                          const SizedBox(height: 12),

                          _ErrorMessage(message: controller.errorMessage!),
                        ],

                        const SizedBox(height: 18),

                        // ==================================================
                        // Submit
                        //
                        // ใช้ Material แทน FilledButton
                        // เพื่อไม่ชน global button constraint
                        // ==================================================
                        _LeaveSubmitButton(
                          loading: controller.isSubmitting,
                          enabled: !controller.isBusy,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================================================
  // Header
  // ==================================================

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 15, 8, 15),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.lightEmergencyContainer,
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: AppColors.emergency,
              size: 21,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'ยืนยันการถอนกำลัง',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          IconButton(
            tooltip: 'ปิด',
            onPressed: widget.controller.isBusy ? null : _close,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

// ==================================================
// Field Title
// ==================================================

class _FieldTitle extends StatelessWidget {
  const _FieldTitle({
    required this.title,
    this.requiredField = false,
    this.subtitle,
  });

  final String title;

  final bool requiredField;

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),

        if (requiredField)
          Text(
            ' *',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w800,
            ),
          ),

        if (subtitle != null) ...[
          const SizedBox(width: 6),

          Text(
            '(${subtitle!})',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

// ==================================================
// Error Message
// ==================================================

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 19,
            color: theme.colorScheme.onErrorContainer,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================
// Submit Button
// ==================================================

class _LeaveSubmitButton extends StatelessWidget {
  const _LeaveSubmitButton({
    required this.loading,
    required this.enabled,
    required this.onPressed,
  });

  final bool loading;

  final bool enabled;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final background = enabled
        ? AppColors.emergency
        : AppColors.emergency.withValues(alpha: 0.45);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'ถอนกำลัง',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

final _formKey = GlobalKey<FormState>();
