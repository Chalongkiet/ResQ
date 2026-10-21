abstract final class EmergencyInfoValidator {
  static const List<String> allowedBloodGroups = <String>[
    'A+',
    'A',
    'A-',
    'B+',
    'B',
    'B-',
    'O+',
    'O',
    'O-',
    'AB+',
    'AB',
    'AB-',
  ];

  // --------------------------------------------------
  // Full Name
  // SRS 3.1.30
  // --------------------------------------------------

  static String? validateFullName(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'กรุณากรอกชื่อ-นามสกุล';
    }

    if (text.length < 4 || text.length > 50) {
      return 'ชื่อ-นามสกุลต้องมีความยาว 4–50 ตัวอักษร';
    }

    // อนุญาตเฉพาะ ไทย / อังกฤษ / ช่องว่าง
    if (!RegExp(r'^[a-zA-Zก-๙\s]+$').hasMatch(text)) {
      return 'ชื่อ-นามสกุลต้องเป็นภาษาไทยหรือภาษาอังกฤษเท่านั้น';
    }

    return null;
  }

  // --------------------------------------------------
  // Phone Number
  // SRS 3.1.30
  // --------------------------------------------------

  static String? validatePhoneNumber(
    String? value, {
    String emptyMessage = 'กรุณากรอกเบอร์โทรศัพท์',
  }) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return emptyMessage;
    }

    if (!RegExp(r'^\d+$').hasMatch(text)) {
      return 'เบอร์โทรศัพท์ต้องเป็นตัวเลขเท่านั้น';
    }

    if (text.length != 10) {
      return 'เบอร์โทรศัพท์ต้องมี 10 หลัก';
    }

    if (!RegExp(r'^(06|08|09)').hasMatch(text)) {
      return 'เบอร์โทรศัพท์ต้องขึ้นต้นด้วย 06, 08 หรือ 09';
    }

    return null;
  }

  // --------------------------------------------------
  // Blood Group
  // SRS 3.1.30
  // --------------------------------------------------

  static String? validateBloodGroup(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'กรุณาเลือกกรุ๊ปเลือด';
    }

    if (!allowedBloodGroups.contains(text)) {
      return 'กรุ๊ปเลือดไม่ถูกต้อง';
    }

    return null;
  }

  // --------------------------------------------------
  // Medical Condition
  // Optional
  // --------------------------------------------------

  static String? validateMedicalCondition(String? value) {
    return _validateOptionalMedicalField(value, fieldName: 'โรคประจำตัว');
  }

  // --------------------------------------------------
  // Allergy
  // Optional
  // --------------------------------------------------

  static String? validateAllergy(String? value) {
    return _validateOptionalMedicalField(value, fieldName: 'ประวัติการแพ้');
  }

  // --------------------------------------------------
  // Regular Medication
  // Optional
  // --------------------------------------------------

  static String? validateRegularMedication(String? value) {
    return _validateOptionalMedicalField(value, fieldName: 'ยาที่ใช้ประจำ');
  }

  static String? _validateOptionalMedicalField(
    String? value, {
    required String fieldName,
  }) {
    final text = value?.trim() ?? '';

    // SRS ระบุว่าสามารถเป็นค่าว่างได้
    if (text.isEmpty) {
      return null;
    }

    if (text.length > 255) {
      return '$fieldName ต้องไม่เกิน 255 ตัวอักษร';
    }

    return null;
  }

  // --------------------------------------------------
  // Emergency Contact Name
  // SRS 3.1.30
  // --------------------------------------------------

  static String? validateEmergencyContactName(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'กรุณากรอกชื่อผู้ติดต่อฉุกเฉิน';
    }

    if (text.length < 4 || text.length > 50) {
      return 'ชื่อผู้ติดต่อฉุกเฉินต้องมีความยาว 4–50 ตัวอักษร';
    }

    if (!RegExp(r'^[a-zA-Zก-๙\s]+$').hasMatch(text)) {
      return 'ชื่อผู้ติดต่อฉุกเฉินต้องเป็นภาษาไทยหรือภาษาอังกฤษเท่านั้น';
    }

    return null;
  }

  // --------------------------------------------------
  // Emergency Contact Phone
  // --------------------------------------------------

  static String? validateEmergencyContactPhone(
    String? value, {
    String? victimPhoneNumber,
  }) {
    final phoneError = validatePhoneNumber(
      value,
      emptyMessage: 'กรุณากรอกเบอร์โทรศัพท์ผู้ติดต่อฉุกเฉิน',
    );

    if (phoneError != null) {
      return phoneError;
    }

    final emergencyPhone = value!.trim();
    final victimPhone = victimPhoneNumber?.trim() ?? '';

    if (victimPhone.isNotEmpty && emergencyPhone == victimPhone) {
      return 'เบอร์ผู้ติดต่อฉุกเฉินต้องไม่ซ้ำกับเบอร์ของผู้ประสบภัย';
    }

    return null;
  }

  // --------------------------------------------------
  // Consent
  //
  // เพิ่มจาก Requirement ที่เราตกลงกัน
  // ไม่ใช่ field เดิมใน SRS 3.1.30
  // --------------------------------------------------

  static String? validateConsent(bool accepted) {
    if (!accepted) {
      return 'กรุณายอมรับการจัดเก็บและใช้ข้อมูลฉุกเฉิน';
    }

    return null;
  }

  EmergencyInfoValidator._();
}
