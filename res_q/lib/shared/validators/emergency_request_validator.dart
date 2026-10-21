abstract final class EmergencyRequestValidator {
  static const int maxDetailLength = 255;
  static const int maxAdditionalDetailLength = 100;
  static const int maxAffectedCount = 99;

  static String? validateAffectedCount(int value) {
    if (value <= 0) return 'จำนวนผู้ประสบภัยต้องมากกว่า 0 คน';
    if (value > maxAffectedCount) {
      return 'จำนวนผู้ประสบภัยต้องไม่เกิน $maxAffectedCount คน';
    }
    return null;
  }

  static String? validateDetail(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'กรุณากรอกรายละเอียดเพิ่มเติม';
    }

    if (text.length > maxDetailLength) {
      return 'รายละเอียดต้องไม่เกิน 255 ตัวอักษร';
    }

    return null;
  }

  static bool isDetailValid(String? value) {
    return validateDetail(value) == null;
  }

  static String? validateSituationSelection(Iterable<Object> situations) {
    if (situations.isEmpty) {
      return 'กรุณาเลือกสถานการณ์อย่างน้อย 1 ข้อ';
    }
    return null;
  }

  static String? validateOptionalAdditionalDetail(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > maxAdditionalDetailLength) {
      return 'รายละเอียดเพิ่มเติมต้องไม่เกิน 100 ตัวอักษร';
    }
    return null;
  }

  static String? validateOtherSituationDetail({
    required bool otherSelected,
    required String? value,
  }) {
    if (otherSelected && (value?.trim().isEmpty ?? true)) {
      return 'กรุณาระบุรายละเอียดสำหรับตัวเลือกอื่น ๆ';
    }
    return validateOptionalAdditionalDetail(value);
  }

  EmergencyRequestValidator._();
}
