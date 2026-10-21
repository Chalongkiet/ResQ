class RescueMissionActionException implements Exception {
  const RescueMissionActionException(
    this.message, {
    this.code = 'rescue-mission-action-error',
  });

  final String message;
  final String code;

  @override
  String toString() =>
      'RescueMissionActionException(code: $code, message: $message)';
}

class RescueMissionNotFoundException extends RescueMissionActionException {
  const RescueMissionNotFoundException()
    : super('ไม่พบภารกิจที่ต้องการดำเนินการ', code: 'mission-not-found');
}

class RescueMissionOwnerMismatchException extends RescueMissionActionException {
  const RescueMissionOwnerMismatchException()
    : super('ชุดปฏิบัติการไม่มีสิทธิ์แก้ไขภารกิจนี้', code: 'owner-mismatch');
}

class RescueMissionNotActiveException extends RescueMissionActionException {
  const RescueMissionNotActiveException()
    : super('ภารกิจนี้ไม่ได้อยู่ในสถานะดำเนินการแล้ว', code: 'not-active');
}

class RescueMissionStatusBackwardException
    extends RescueMissionActionException {
  const RescueMissionStatusBackwardException()
    : super('ไม่สามารถเปลี่ยนสถานะภารกิจย้อนกลับได้', code: 'status-backward');
}

class RescueMissionStatusSkipException extends RescueMissionActionException {
  const RescueMissionStatusSkipException()
    : super('กรุณาอัปเดตสถานะภารกิจตามลำดับทีละขั้น', code: 'status-skip');
}

class RescueMissionRequestUnavailableException
    extends RescueMissionActionException {
  const RescueMissionRequestUnavailableException()
    : super(
        'คำร้องนี้ไม่ได้อยู่ในสถานะที่ดำเนินภารกิจได้',
        code: 'request-unavailable',
      );
}

class RescueMissionCancelReasonRequiredException
    extends RescueMissionActionException {
  const RescueMissionCancelReasonRequiredException()
    : super('กรุณาระบุเหตุผลในการยกเลิกภารกิจ', code: 'reason-required');
}

class RescueMissionCancelImageRequiredException
    extends RescueMissionActionException {
  const RescueMissionCancelImageRequiredException()
    : super('กรุณาแนบรูปภาพยืนยันการยกเลิกภารกิจ', code: 'image-required');
}

class RescueMissionCompleteUnavailableException
    extends RescueMissionActionException {
  const RescueMissionCompleteUnavailableException()
    : super(
        'กรุณาอัปเดตสถานะให้ถึงศูนย์อพยพก่อนจบภารกิจ',
        code: 'complete-unavailable',
      );
}

class RescueMissionTotalAffectedRequiredException
    extends RescueMissionActionException {
  const RescueMissionTotalAffectedRequiredException()
    : super(
        'กรุณาระบุจำนวนผู้ประสบภัยที่ช่วยเหลือ',
        code: 'total-affected-required',
      );
}

class RescueMissionProofImageRequiredException
    extends RescueMissionActionException {
  const RescueMissionProofImageRequiredException()
    : super('กรุณาแนบรูปภาพยืนยันการจบภารกิจ', code: 'proof-image-required');
}

class RescueMissionSafeLocationRequiredException
    extends RescueMissionActionException {
  const RescueMissionSafeLocationRequiredException()
    : super('กรุณาระบุสถานที่ปลอดภัย', code: 'safe-location-required');
}
