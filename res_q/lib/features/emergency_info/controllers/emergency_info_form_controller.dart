import 'package:flutter/material.dart';

import '../../../data/models/emergency_info_model.dart';
import '../../../shared/validators/emergency_info_validator.dart';
import '../widgets/emergency_info_validation_popup.dart';

class EmergencyInfoValidationIssue {
  const EmergencyInfoValidationIssue({
    required this.message,
    required this.fieldKey,
    required this.focusNode,
  });

  final String message;
  final GlobalKey fieldKey;
  final FocusNode focusNode;
}

class EmergencyInfoFormController {
  final fullName = TextEditingController();
  final phoneNumber = TextEditingController();

  final medicalCondition = TextEditingController();
  final allergy = TextEditingController();
  final regularMedication = TextEditingController();

  final emergencyContactName = TextEditingController();
  final emergencyContactPhone = TextEditingController();

  final fullNameFieldKey = GlobalKey();
  final bloodGroupFieldKey = GlobalKey();
  final phoneNumberFieldKey = GlobalKey();
  final medicalConditionFieldKey = GlobalKey();
  final allergyFieldKey = GlobalKey();
  final regularMedicationFieldKey = GlobalKey();
  final emergencyContactNameFieldKey = GlobalKey();
  final emergencyContactPhoneFieldKey = GlobalKey();

  final fullNameFocusNode = FocusNode(debugLabel: 'fullName');
  final bloodGroupFocusNode = FocusNode(debugLabel: 'bloodGroup');
  final phoneNumberFocusNode = FocusNode(debugLabel: 'phoneNumber');
  final medicalConditionFocusNode = FocusNode(debugLabel: 'medicalCondition');
  final allergyFocusNode = FocusNode(debugLabel: 'allergy');
  final regularMedicationFocusNode = FocusNode(debugLabel: 'regularMedication');
  final emergencyContactNameFocusNode = FocusNode(
    debugLabel: 'emergencyContactName',
  );
  final emergencyContactPhoneFocusNode = FocusNode(
    debugLabel: 'emergencyContactPhone',
  );

  String? bloodGroup;

  bool _isPresentingValidation = false;

  // โหลด EmergencyInfo เดิมเข้ามาใน Form
  void load(EmergencyInfo info) {
    fullName.text = info.fullName;
    phoneNumber.text = info.phoneNumber;

    bloodGroup = info.bloodGroup;

    medicalCondition.text = info.medicalCondition ?? '';

    allergy.text = info.allergy ?? '';

    regularMedication.text = info.regularMedication ?? '';

    emergencyContactName.text = info.emergencyContactName;

    emergencyContactPhone.text = info.emergencyContactPhone;
  }

  EmergencyInfoValidationIssue? firstValidationIssue() {
    final validations =
        <({String? error, GlobalKey fieldKey, FocusNode focusNode})>[
          (
            error: EmergencyInfoValidator.validateFullName(fullName.text),
            fieldKey: fullNameFieldKey,
            focusNode: fullNameFocusNode,
          ),
          (
            error: EmergencyInfoValidator.validateBloodGroup(bloodGroup),
            fieldKey: bloodGroupFieldKey,
            focusNode: bloodGroupFocusNode,
          ),
          (
            error: EmergencyInfoValidator.validatePhoneNumber(phoneNumber.text),
            fieldKey: phoneNumberFieldKey,
            focusNode: phoneNumberFocusNode,
          ),
          (
            error: EmergencyInfoValidator.validateMedicalCondition(
              medicalCondition.text,
            ),
            fieldKey: medicalConditionFieldKey,
            focusNode: medicalConditionFocusNode,
          ),
          (
            error: EmergencyInfoValidator.validateAllergy(allergy.text),
            fieldKey: allergyFieldKey,
            focusNode: allergyFocusNode,
          ),
          (
            error: EmergencyInfoValidator.validateRegularMedication(
              regularMedication.text,
            ),
            fieldKey: regularMedicationFieldKey,
            focusNode: regularMedicationFocusNode,
          ),
          (
            error: EmergencyInfoValidator.validateEmergencyContactName(
              emergencyContactName.text,
            ),
            fieldKey: emergencyContactNameFieldKey,
            focusNode: emergencyContactNameFocusNode,
          ),
          (
            error: EmergencyInfoValidator.validateEmergencyContactPhone(
              emergencyContactPhone.text,
              victimPhoneNumber: phoneNumber.text,
            ),
            fieldKey: emergencyContactPhoneFieldKey,
            focusNode: emergencyContactPhoneFocusNode,
          ),
        ];

    for (final validation in validations) {
      final error = validation.error;

      if (error != null) {
        return EmergencyInfoValidationIssue(
          message: error,
          fieldKey: validation.fieldKey,
          focusNode: validation.focusNode,
        );
      }
    }

    return null;
  }

  Future<bool> validateAndFocusFirstError(BuildContext context) async {
    final issue = firstValidationIssue();

    if (issue == null) {
      return true;
    }

    if (_isPresentingValidation) {
      return false;
    }

    _isPresentingValidation = true;

    try {
      await presentValidationIssue(context, issue);
    } finally {
      _isPresentingValidation = false;
    }

    return false;
  }

  static Future<void> presentValidationIssue(
    BuildContext context,
    EmergencyInfoValidationIssue issue,
  ) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);

    if (overlay == null) {
      return;
    }

    final entry = OverlayEntry(
      builder: (_) => EmergencyInfoValidationPopup(message: issue.message),
    );

    overlay.insert(entry);

    await Future<void>.delayed(const Duration(milliseconds: 1400));

    entry.remove();

    if (!context.mounted) {
      return;
    }

    final fieldContext = issue.fieldKey.currentContext;

    if (fieldContext != null) {
      await Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.25,
      );
    }

    if (context.mounted) {
      issue.focusNode.requestFocus();
    }
  }

  void dispose() {
    fullName.dispose();
    phoneNumber.dispose();

    medicalCondition.dispose();
    allergy.dispose();
    regularMedication.dispose();

    emergencyContactName.dispose();
    emergencyContactPhone.dispose();

    fullNameFocusNode.dispose();
    bloodGroupFocusNode.dispose();
    phoneNumberFocusNode.dispose();
    medicalConditionFocusNode.dispose();
    allergyFocusNode.dispose();
    regularMedicationFocusNode.dispose();
    emergencyContactNameFocusNode.dispose();
    emergencyContactPhoneFocusNode.dispose();
  }
}
