class EmergencyInfoException implements Exception {
  const EmergencyInfoException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class EmergencyInfoAlreadyExistsException extends EmergencyInfoException {
  const EmergencyInfoAlreadyExistsException()
    : super('มีข้อมูลฉุกเฉินของอุปกรณ์นี้อยู่แล้ว', code: 'already-exists');
}

class EmergencyInfoNotFoundException extends EmergencyInfoException {
  const EmergencyInfoNotFoundException()
    : super('ไม่พบข้อมูลฉุกเฉิน', code: 'not-found');
}
