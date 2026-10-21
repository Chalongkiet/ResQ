abstract final class EmergencyRequestStatus {
  /// คำร้องถูกส่งแล้ว และกำลังรอทีมกู้ภัยรับเรื่อง
  static const String waiting = 'WAITING';
  static const String accepted = 'ACCEPTED';

  /// ทีมกู้ภัยช่วยเหลือและปิดภารกิจเรียบร้อยแล้ว
  static const String completed = 'COMPLETED';

  /// ผู้ประสบภัยยกเลิกคำร้อง
  static const String cancelled = 'CANCELLED';

  EmergencyRequestStatus._();
}
