import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/validators/rescue_action_validator.dart';
import '../../controllers/cancel_rescue_mission_controller.dart';
import '../../../../shared/widgets/image_source_picker.dart';
import '../leave/leave_image_picker.dart';

Future<bool> showCancelRescueMissionPopup({
  required BuildContext context,
  required String requestId,
  required String missionId,
  required String deploymentId,
  required CancelRescueMissionController controller,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CancelRescueMissionPopup(
          requestId: requestId,
          missionId: missionId,
          deploymentId: deploymentId,
          controller: controller,
        ),
      ) ??
      false;
}

class _CancelRescueMissionPopup extends StatefulWidget {
  const _CancelRescueMissionPopup({
    required this.requestId,
    required this.missionId,
    required this.deploymentId,
    required this.controller,
  });

  final String requestId;
  final String missionId;
  final String deploymentId;
  final CancelRescueMissionController controller;

  @override
  State<_CancelRescueMissionPopup> createState() =>
      _CancelRescueMissionPopupState();
}

class _CancelRescueMissionPopupState extends State<_CancelRescueMissionPopup> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _detailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _reasonController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await widget.controller.submit(
      requestId: widget.requestId,
      missionId: widget.missionId,
      deploymentId: widget.deploymentId,
      cancelReason: _reasonController.text,
      cancelDetail: _detailController.text,
    );
    if (mounted && success) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !controller.isBusy,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.sizeOf(context).height * 0.90,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cancel_outlined,
                      color: AppColors.emergency,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ยืนยันการยกเลิกภารกิจ',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'ปิด',
                      onPressed: controller.isBusy
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _FieldLabel(text: 'เหตุผล', requiredField: true),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _reasonController,
                          enabled: !controller.isBusy,
                          maxLength: 255,
                          onChanged: (_) => controller.clearError(),
                          validator:
                              RescueActionValidator.validateCancelMissionReason,
                          decoration: const InputDecoration(
                            hintText: 'เช่น เข้าถึงพื้นที่ไม่ได้ / น้ำท่วมสูง',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const _FieldLabel(
                          text: 'รายละเอียดเพิ่มเติม (ไม่บังคับ)',
                        ),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _detailController,
                          enabled: !controller.isBusy,
                          maxLength: 255,
                          minLines: 3,
                          maxLines: 5,
                          onChanged: (_) => controller.clearError(),
                          validator:
                              RescueActionValidator.validateOptionalDetail,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const _FieldLabel(
                          text: 'รูปภาพยืนยัน',
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
                          onRemove: controller.removeImage,
                        ),
                        if (controller.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            controller.errorMessage!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: controller.isBusy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.emergency,
                            minimumSize: const Size.fromHeight(50),
                          ),
                          child: controller.isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'ยกเลิกภารกิจ',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
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
