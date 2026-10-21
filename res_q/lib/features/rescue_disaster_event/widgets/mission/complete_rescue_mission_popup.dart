import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/rescue_mission_monitor_model.dart';
import '../../../../shared/validators/rescue_action_validator.dart';
import '../../../../shared/widgets/image_source_picker.dart';
import '../../controllers/complete_rescue_mission_controller.dart';
import '../leave/leave_image_picker.dart';

Future<bool> showCompleteRescueMissionPopup({
  required BuildContext context,
  required RescueMissionAssignment assignment,
  required CompleteRescueMissionController controller,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CompleteRescueMissionPopup(
          assignment: assignment,
          controller: controller,
        ),
      ) ??
      false;
}

class _CompleteRescueMissionPopup extends StatefulWidget {
  const _CompleteRescueMissionPopup({
    required this.assignment,
    required this.controller,
  });

  final RescueMissionAssignment assignment;
  final CompleteRescueMissionController controller;

  @override
  State<_CompleteRescueMissionPopup> createState() =>
      _CompleteRescueMissionPopupState();
}

class _CompleteRescueMissionPopupState
    extends State<_CompleteRescueMissionPopup> {
  final _formKey = GlobalKey<FormState>();
  final _safeLocationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _safeLocationController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await widget.controller.submit(
      requestId: widget.assignment.request.requestId,
      missionId: widget.assignment.mission.missionId,
      deploymentId: widget.assignment.mission.deploymentId,
      safeLocationName: _safeLocationController.text,
    );
    if (mounted && success) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final assignment = widget.assignment;
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: AppColors.success,
                child: Text(
                  'เสร็จสิ้นภารกิจ',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MissionInfoRow(
                          label: 'ภารกิจ',
                          value: assignment.mission.missionName,
                        ),
                        _MissionInfoRow(
                          label: 'คำร้องขอ',
                          value: assignment.request.requestType,
                        ),
                        if (assignment.request.requestDetail.trim().isNotEmpty)
                          _MissionInfoRow(
                            label: 'รายละเอียด',
                            value: assignment.request.requestDetail,
                          ),
                        _MissionInfoRow(
                          label: 'จำนวนผู้ประสบภัย',
                          value: '${assignment.request.affectedCount} คน',
                        ),
                        const SizedBox(height: 12),
                        const _FieldLabel(
                          text: 'สถานที่ปลอดภัย',
                          requiredField: true,
                        ),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _safeLocationController,
                          enabled: !controller.isBusy,
                          maxLength: 255,
                          onChanged: (_) => controller.clearError(),
                          validator:
                              RescueActionValidator.validateSafeLocationName,
                          decoration: const InputDecoration(
                            hintText: 'เช่น อยู่กับญาติ / ศูนย์อพยพ',
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
                            backgroundColor: AppColors.success,
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
                                  'จบภารกิจ',
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

class _MissionInfoRow extends StatelessWidget {
  const _MissionInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text.rich(
        TextSpan(
          text: '$label: ',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.black87),
            ),
          ],
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
