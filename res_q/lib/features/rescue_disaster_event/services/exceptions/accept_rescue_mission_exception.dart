class AcceptRescueMissionException implements Exception {
  const AcceptRescueMissionException(
    this.message, {
    this.code = 'accept-rescue-mission-error',
  });

  final String message;

  final String code;

  @override
  String toString() {
    return 'AcceptRescueMissionException('
        'code: $code, '
        'message: $message'
        ')';
  }
}

// ==================================================
// Request
// ==================================================

class AcceptMissionRequestNotFoundException
    extends AcceptRescueMissionException {
  const AcceptMissionRequestNotFoundException()
    : super('ไม่พบคำร้องขอความช่วยเหลือ', code: 'request-not-found');
}

// ==================================================
// Already Accepted
// ==================================================

class AcceptMissionRequestUnavailableException
    extends AcceptRescueMissionException {
  const AcceptMissionRequestUnavailableException()
    : super('คำร้องนี้ถูกรับไปแล้ว', code: 'request-unavailable');
}

// ==================================================
// Deployment
// ==================================================

class AcceptMissionDeploymentNotFoundException
    extends AcceptRescueMissionException {
  const AcceptMissionDeploymentNotFoundException()
    : super('ไม่พบข้อมูลชุดปฏิบัติการ', code: 'deployment-not-found');
}

class AcceptMissionDeploymentNotActiveException
    extends AcceptRescueMissionException {
  const AcceptMissionDeploymentNotActiveException()
    : super(
        'ชุดปฏิบัติการไม่ได้อยู่ในสถานะพร้อมรับภารกิจ',
        code: 'deployment-not-active',
      );
}

class AcceptMissionQueueFullException extends AcceptRescueMissionException {
  const AcceptMissionQueueFullException()
    : super(
        'คิวภารกิจเต็มแล้ว กรุณาจบหรือยกเลิกภารกิจในคิวก่อน',
        code: 'mission-queue-full',
      );
}

// ==================================================
// Mission
// ==================================================

class AcceptMissionNameRequiredException extends AcceptRescueMissionException {
  const AcceptMissionNameRequiredException()
    : super('ไม่สามารถสร้างชื่อภารกิจได้', code: 'mission-name-required');
}
