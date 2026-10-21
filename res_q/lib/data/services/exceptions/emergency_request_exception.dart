class EmergencyRequestException implements Exception {
  const EmergencyRequestException(
    this.message, {
    this.code = 'emergency-request-error',
  });

  final String message;
  final String code;

  @override
  String toString() {
    return 'EmergencyRequestException('
        'code: $code, '
        'message: $message'
        ')';
  }
}

class EmergencyRequestNotFoundException extends EmergencyRequestException {
  const EmergencyRequestNotFoundException()
    : super('ไม่พบคำร้องขอความช่วยเหลือ', code: 'request-not-found');
}

class EmergencyRequestCannotCancelException extends EmergencyRequestException {
  const EmergencyRequestCannotCancelException()
    : super(
        'ไม่สามารถยกเลิกคำร้องในสถานะปัจจุบันได้',
        code: 'request-cannot-cancel',
      );
}

class EmergencyRequestOwnerMismatchException extends EmergencyRequestException {
  const EmergencyRequestOwnerMismatchException()
    : super('ไม่มีสิทธิ์จัดการคำร้องนี้', code: 'request-owner-mismatch');
}

class EmergencyRequestCannotUpdateSafetyException
    extends EmergencyRequestException {
  const EmergencyRequestCannotUpdateSafetyException()
    : super(
        'ยืนยันความปลอดภัยได้หลังจากทีมกู้ภัยจบภารกิจเท่านั้น',
        code: 'request-cannot-update-safety',
      );
}

class EmergencyRequestAlreadySafeException extends EmergencyRequestException {
  const EmergencyRequestAlreadySafeException()
    : super('คำร้องนี้ได้รับการยืนยันความปลอดภัยแล้ว', code: 'already-safe');
}
