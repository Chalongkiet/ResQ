abstract final class MissionStatus {
  // ==================================================
  // Waiting Assignment Status
  // ==================================================

  /// ทีมรับคำร้องไว้แล้ว แต่กำลังปฏิบัติภารกิจก่อนหน้า
  static const String queued = 'QUEUED';

  // ==================================================
  // Active Mission Status
  // ==================================================

  /// Stage 2
  /// ทีมรับงานแล้ว และกำลังเดินทางไปยังผู้ประสบภัย
  static const String onTheWay = 'ON_THE_WAY';

  /// Stage 3
  /// ทีมกู้ภัยเดินทางถึงพื้นที่ผู้ประสบภัยแล้ว
  static const String arrived = 'ARRIVED';

  /// Stage 4
  /// กำลังดำเนินการช่วยเหลือผู้ประสบภัย
  static const String rescuing = 'RESCUING';

  /// Stage 5
  /// กำลังนำส่งผู้ประสบภัยไปยังศูนย์อพยพ
  static const String transporting = 'TRANSPORTING';

  /// Stage 6
  /// เดินทางถึงศูนย์อพยพแล้ว
  static const String evacuationCenterReached = 'EVACUATION_CENTER_REACHED';

  // ==================================================
  // Terminal Status
  // ==================================================

  /// ปิดภารกิจสำเร็จแล้ว
  static const String completed = 'COMPLETED';

  /// ภารกิจถูกยกเลิก
  static const String cancelled = 'CANCELLED';

  static const List<String> activeFlow = <String>[
    onTheWay,
    arrived,
    rescuing,
    transporting,
    evacuationCenterReached,
  ];

  static bool isActive(String status) => activeFlow.contains(status);

  static bool isQueued(String status) => status == queued;

  static bool isAssigned(String status) => isActive(status) || isQueued(status);

  static String? nextActiveStatus(String currentStatus) {
    final currentIndex = activeFlow.indexOf(currentStatus);
    if (currentIndex < 0 || currentIndex >= activeFlow.length - 1) {
      return null;
    }
    return activeFlow[currentIndex + 1];
  }

  static String nextActionLabel(String currentStatus) {
    switch (nextActiveStatus(currentStatus)) {
      case arrived:
        return 'ถึงจุดเกิดเหตุแล้ว';
      case rescuing:
        return 'เริ่มช่วยเหลือผู้ประสบภัย';
      case transporting:
        return 'เริ่มเคลื่อนย้ายผู้ประสบภัย';
      case evacuationCenterReached:
        return 'ถึงศูนย์อพยพแล้ว';
      default:
        return 'อัปเดตสถานะ';
    }
  }

  static int stageOf(String status) {
    if (status == queued) return 2;

    final index = activeFlow.indexOf(status);
    return index < 0 ? 2 : index + 2;
  }

  static String labelOf(String status) {
    switch (status) {
      case queued:
        return 'ทีมกู้ภัยรับคำร้องแล้ว และกำลังปฏิบัติภารกิจก่อนหน้า';
      case onTheWay:
        return 'เจ้าหน้าที่กู้ภัยรับเรื่องแล้ว กำลังเดินทางมาช่วยเหลือ';
      case arrived:
        return 'เจ้าหน้าที่กู้ภัยเดินทางถึงพื้นที่แล้ว';
      case rescuing:
        return 'เจ้าหน้าที่กำลังดำเนินการช่วยเหลือ';
      case transporting:
        return 'กำลังนำส่งผู้ประสบภัยไปยังศูนย์อพยพ';
      case evacuationCenterReached:
        return 'เดินทางถึงศูนย์อพยพแล้ว';
      case completed:
        return 'ภารกิจเสร็จสิ้น';
      case cancelled:
        return 'ภารกิจถูกยกเลิก';
      default:
        return 'กำลังดำเนินภารกิจ';
    }
  }

  MissionStatus._();
}
