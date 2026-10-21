import 'package:flutter/material.dart';

import '../../data/services/emergency_info_service.dart';
import '../../data/services/exceptions/emergency_info_exception.dart';
import '../../shared/validators/emergency_info_validator.dart';
import 'controllers/emergency_info_form_controller.dart';
import 'widgets/emergency_info_form.dart';

class PrepareEmergencyInfoPage extends StatefulWidget {
  const PrepareEmergencyInfoPage({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<PrepareEmergencyInfoPage> createState() =>
      _PrepareEmergencyInfoPageState();
}

class _PrepareEmergencyInfoPageState extends State<PrepareEmergencyInfoPage> {
  final _formKey = GlobalKey<FormState>();

  final _formController = EmergencyInfoFormController();

  final _service = EmergencyInfoService();

  final _consentFieldKey = GlobalKey();

  final _consentFocusNode = FocusNode(debugLabel: 'emergencyInfoConsent');

  bool _consentAccepted = false;
  bool _isSaving = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _formController.dispose();
    _consentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving || _isSuccess) {
      return;
    }

    final isValid = await _formController.validateAndFocusFirstError(context);

    if (!mounted || !isValid) {
      return;
    }

    final consentError = EmergencyInfoValidator.validateConsent(
      _consentAccepted,
    );

    if (consentError != null) {
      await EmergencyInfoFormController.presentValidationIssue(
        context,
        EmergencyInfoValidationIssue(
          message: consentError,
          fieldKey: _consentFieldKey,
          focusNode: _consentFocusNode,
        ),
      );
      return;
    }

    final bloodGroup = _formController.bloodGroup;

    if (bloodGroup == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _service.create(
        fullName: _formController.fullName.text,
        phoneNumber: _formController.phoneNumber.text,
        bloodGroup: bloodGroup,
        medicalCondition: _formController.medicalCondition.text,
        allergy: _formController.allergy.text,
        regularMedication: _formController.regularMedication.text,
        emergencyContactName: _formController.emergencyContactName.text,
        emergencyContactPhone: _formController.emergencyContactPhone.text,
      );

      if (!mounted) {
        return;
      }

      await _showSuccess();
    } on EmergencyInfoAlreadyExistsException {
      if (!mounted) {
        return;
      }

      await _showSuccess();
    } on EmergencyInfoException catch (error) {
      _showError(error.message);
    } catch (error) {
      debugPrint('Prepare emergency info error: $error');

      _showError('ไม่สามารถบันทึกข้อมูลได้ กรุณาลองใหม่อีกครั้ง');
    }
  }

  Future<void> _showSuccess() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      _isSuccess = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (!mounted) {
      return;
    }

    widget.onCompleted();
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: _isSuccess ? Colors.white : theme.colorScheme.surface,
      elevation: 16,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _isSuccess
            ? const _SuccessContent()
            : EmergencyInfoForm(
                formKey: _formKey,
                controller: _formController,
                isSaving: _isSaving,
                submitLabel: 'บันทึกและเริ่มใช้งาน',
                onBloodGroupChanged: (_) {},
                onSave: _submit,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                footer: _ConsentField(
                  fieldKey: _consentFieldKey,
                  focusNode: _consentFocusNode,
                  accepted: _consentAccepted,
                  enabled: !_isSaving,
                  onChanged: (value) {
                    setState(() {
                      _consentAccepted = value;
                    });
                  },
                ),
              ),
      ),
    );
  }
}

class _ConsentField extends StatelessWidget {
  const _ConsentField({
    required this.fieldKey,
    required this.focusNode,
    required this.accepted,
    required this.enabled,
    required this.onChanged,
  });

  final GlobalKey fieldKey;
  final FocusNode focusNode;
  final bool accepted;
  final bool enabled;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: fieldKey,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            focusNode: focusNode,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: accepted,
            onChanged: !enabled
                ? null
                : (value) {
                    onChanged(value ?? false);
                  },
            title: const Text(
              'ฉันยินยอมให้ ResQ '
              'จัดเก็บและใช้ข้อมูลฉุกเฉินของฉัน '
              'เพื่อสนับสนุนการช่วยเหลือ'
              'เมื่อเกิดเหตุฉุกเฉิน',
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 42,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'บันทึกข้อมูลสำเร็จ',
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ข้อมูลฉุกเฉินของคุณพร้อมใช้งานแล้ว',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
