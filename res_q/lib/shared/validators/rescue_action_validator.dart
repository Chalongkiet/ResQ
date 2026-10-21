abstract final class RescueActionValidator {
  static const int maxTextLength = 255;

  static String? validateLeaveReason(String? value) {
    return _validateRequiredReason(
      value,
      emptyMessage: 'กรุณาระบุเหตุผลในการถอนกำลัง',
      tooLongMessage: 'เหตุผลในการถอนกำลังต้องไม่เกิน 255 ตัวอักษร',
    );
  }

  static String? validateCancelMissionReason(String? value) {
    return _validateRequiredReason(
      value,
      emptyMessage: 'กรุณาระบุเหตุผลในการยกเลิกภารกิจ',
      tooLongMessage: 'เหตุผลในการยกเลิกภารกิจต้องไม่เกิน 255 ตัวอักษร',
    );
  }

  static String? validateOptionalDetail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > maxTextLength) {
      return 'รายละเอียดเพิ่มเติมต้องไม่เกิน 255 ตัวอักษร';
    }
    return null;
  }

  static String? validateSafeLocationName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'กรุณาระบุสถานที่ปลอดภัย';
    if (text.length > maxTextLength) {
      return 'ชื่อสถานที่ปลอดภัยต้องไม่เกิน 255 ตัวอักษร';
    }
    return null;
  }

  static String? validateTotalAffected(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'กรุณาระบุจำนวนผู้ประสบภัยที่ช่วยเหลือ';

    final total = int.tryParse(text);
    if (total == null || total <= 0) {
      return 'กรุณาระบุจำนวนเต็มที่มากกว่า 0';
    }
    return null;
  }

  static String? _validateRequiredReason(
    String? value, {
    required String emptyMessage,
    required String tooLongMessage,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return emptyMessage;
    if (text.length > maxTextLength) return tooLongMessage;
    return null;
  }

  RescueActionValidator._();
}
