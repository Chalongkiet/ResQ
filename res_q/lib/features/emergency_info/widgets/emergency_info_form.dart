import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/validators/emergency_info_validator.dart';
import '../controllers/emergency_info_form_controller.dart';
import 'emergency_info_section_title.dart';

class EmergencyInfoForm extends StatelessWidget {
  const EmergencyInfoForm({
    super.key,
    required this.formKey,
    required this.controller,
    required this.isSaving,
    required this.onSave,
    required this.onBloodGroupChanged,
    required this.submitLabel,
    this.bloodGroupEditable = true,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 32),
  });

  final GlobalKey<FormState> formKey;
  final EmergencyInfoFormController controller;

  final bool isSaving;

  final VoidCallback onSave;
  final ValueChanged<String?> onBloodGroupChanged;

  final String submitLabel;

  final bool bloodGroupEditable;

  final Widget? footer;

  final EdgeInsetsGeometry padding;

  // ==================================================
  // Input Decoration
  // ==================================================

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? icon,
    bool hideCounter = false,
  }) {
    const borderColor = Color(0xFFD1D5DB);
    const focusedBorderColor = Color(0xFF6B7280);
    const labelColor = Color(0xFF4B5563);
    const hintColor = Color(0xFF9CA3AF);
    const iconColor = Color(0xFF6B7280);

    return InputDecoration(
      labelText: label,
      hintText: hint,

      // ==============================================
      // White Input Background
      // ==============================================
      filled: true,
      fillColor: Colors.white,

      // ==============================================
      // Text
      // ==============================================
      labelStyle: const TextStyle(color: labelColor),

      floatingLabelStyle: const TextStyle(
        color: focusedBorderColor,
        fontWeight: FontWeight.w600,
      ),

      hintStyle: const TextStyle(color: hintColor),

      // ==============================================
      // Icon
      // ==============================================
      prefixIcon: icon == null ? null : Icon(icon, color: iconColor),

      // ==============================================
      // Padding
      // ==============================================
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),

      // ==============================================
      // Counter
      // ==============================================
      counterText: hideCounter ? '' : null,

      // ==============================================
      // Border
      // ==============================================
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor, width: 1),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: focusedBorderColor, width: 1.5),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),

      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
    );
  }

  // ==================================================
  // Text Style
  // ==================================================

  TextStyle get _inputTextStyle {
    return const TextStyle(color: Color(0xFF111827), fontSize: 16);
  }

  // ==================================================
  // Build
  // ==================================================

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: isSaving,
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: ListView(
          padding: padding,
          children: [
            // ==================================================
            // Personal Information
            // ==================================================
            const EmergencyInfoSectionTitle(
              title: 'ข้อมูลส่วนตัว',
              subtitle: 'กรอกข้อมูลที่ใช้ระบุตัวตนและติดต่อคุณ',
              icon: Icons.person_outline,
            ),

            // --------------------------------------------------
            // Full Name
            // --------------------------------------------------
            TextFormField(
              key: controller.fullNameFieldKey,
              controller: controller.fullName,
              focusNode: controller.fullNameFocusNode,
              style: _inputTextStyle,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              maxLength: 50,
              decoration: _inputDecoration(
                label: 'ชื่อ-นามสกุล *',
                hint: 'กรอกชื่อและนามสกุล',
                icon: Icons.badge_outlined,
              ),
            ),

            const SizedBox(height: 12),

            // --------------------------------------------------
            // Blood Group + Phone
            // --------------------------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    key: controller.bloodGroupFieldKey,
                    initialValue: controller.bloodGroup,

                    focusNode: controller.bloodGroupFocusNode,

                    style: _inputTextStyle,

                    dropdownColor: Colors.white,

                    iconEnabledColor: const Color(0xFF4B5563),

                    iconDisabledColor: const Color(0xFF6B7280),

                    icon: Icon(
                      bloodGroupEditable
                          ? Icons.arrow_drop_down
                          : Icons.lock_outline,
                    ),

                    decoration: _inputDecoration(label: 'กรุ๊ปเลือด *'),

                    items: EmergencyInfoValidator.allowedBloodGroups.map((
                      bloodGroup,
                    ) {
                      return DropdownMenuItem<String>(
                        value: bloodGroup,
                        child: Text(bloodGroup, style: _inputTextStyle),
                      );
                    }).toList(),

                    onChanged: isSaving || !bloodGroupEditable
                        ? null
                        : (value) {
                            controller.bloodGroup = value;

                            onBloodGroupChanged(value);
                          },
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  flex: 4,
                  child: TextFormField(
                    key: controller.phoneNumberFieldKey,
                    controller: controller.phoneNumber,
                    focusNode: controller.phoneNumberFocusNode,
                    style: _inputTextStyle,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    maxLength: 10,

                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],

                    decoration: _inputDecoration(
                      label: 'เบอร์โทรศัพท์ *',
                      hint: '0812345678',
                      icon: Icons.phone_outlined,
                      hideCounter: true,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ==================================================
            // Medical Information
            // ==================================================
            const EmergencyInfoSectionTitle(
              title: 'ข้อมูลสุขภาพ',
              subtitle: 'ไม่บังคับกรอก หากไม่มีข้อมูลสามารถเว้นว่างได้',
              icon: Icons.medical_information_outlined,
            ),

            // --------------------------------------------------
            // Medical Condition
            // --------------------------------------------------
            TextFormField(
              key: controller.medicalConditionFieldKey,
              controller: controller.medicalCondition,
              focusNode: controller.medicalConditionFocusNode,
              style: _inputTextStyle,
              textInputAction: TextInputAction.next,
              maxLength: 255,
              minLines: 1,
              maxLines: 3,

              decoration: _inputDecoration(
                label: 'โรคประจำตัว',
                hint: 'เช่น โรคเบาหวาน',
              ),
            ),

            const SizedBox(height: 12),

            // --------------------------------------------------
            // Allergy
            // --------------------------------------------------
            TextFormField(
              key: controller.allergyFieldKey,
              controller: controller.allergy,
              focusNode: controller.allergyFocusNode,
              style: _inputTextStyle,
              textInputAction: TextInputAction.next,
              maxLength: 255,
              minLines: 1,
              maxLines: 3,

              decoration: _inputDecoration(
                label: 'ประวัติการแพ้',
                hint: 'เช่น แพ้ยา หรือสารที่ทำให้เกิดอาการแพ้',
              ),
            ),

            const SizedBox(height: 12),

            // --------------------------------------------------
            // Regular Medication
            // --------------------------------------------------
            TextFormField(
              key: controller.regularMedicationFieldKey,
              controller: controller.regularMedication,
              focusNode: controller.regularMedicationFocusNode,
              style: _inputTextStyle,
              textInputAction: TextInputAction.next,
              maxLength: 255,
              minLines: 1,
              maxLines: 3,

              decoration: _inputDecoration(
                label: 'ยาที่ใช้ประจำ',
                hint: 'ระบุยาที่ใช้อยู่เป็นประจำ',
              ),
            ),

            const SizedBox(height: 28),

            // ==================================================
            // Emergency Contact
            // ==================================================
            const EmergencyInfoSectionTitle(
              title: 'ผู้ติดต่อฉุกเฉิน',
              subtitle: 'บุคคลที่สามารถติดต่อได้เมื่อเกิดเหตุฉุกเฉิน',
              icon: Icons.contact_emergency_outlined,
            ),

            // --------------------------------------------------
            // Emergency Contact Name
            // --------------------------------------------------
            TextFormField(
              key: controller.emergencyContactNameFieldKey,
              controller: controller.emergencyContactName,
              focusNode: controller.emergencyContactNameFocusNode,
              style: _inputTextStyle,
              textInputAction: TextInputAction.next,
              maxLength: 50,

              decoration: _inputDecoration(
                label: 'ชื่อผู้ติดต่อฉุกเฉิน *',
                hint: 'กรอกชื่อและนามสกุล',
                icon: Icons.person_outline,
              ),
            ),

            const SizedBox(height: 12),

            // --------------------------------------------------
            // Emergency Contact Phone
            // --------------------------------------------------
            TextFormField(
              key: controller.emergencyContactPhoneFieldKey,
              controller: controller.emergencyContactPhone,
              focusNode: controller.emergencyContactPhoneFocusNode,
              style: _inputTextStyle,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              maxLength: 10,

              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],

              decoration: _inputDecoration(
                label: 'เบอร์โทรผู้ติดต่อฉุกเฉิน *',
                hint: '0891234567',
                icon: Icons.phone_in_talk_outlined,
                hideCounter: true,
              ),
            ),

            // ==================================================
            // Footer
            //
            // Prepare = Consent
            // Edit = Consent Status
            // ==================================================
            if (footer != null) ...[const SizedBox(height: 28), footer!],

            const SizedBox(height: 28),

            // ==================================================
            // Submit Button
            // ==================================================
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: isSaving ? null : onSave,
                child: isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(submitLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
