class LeaveDisasterEventException implements Exception {
  const LeaveDisasterEventException(
    this.message, {
    this.code = 'leave-disaster-event-error',
  });

  final String message;

  final String code;

  @override
  String toString() {
    return 'LeaveDisasterEventException('
        'code: $code, '
        'message: $message'
        ')';
  }
}

// ==================================================
// Deployment Not Found
// ==================================================

class LeaveDeploymentNotFoundException extends LeaveDisasterEventException {
  const LeaveDeploymentNotFoundException()
    : super('ไม่พบข้อมูลการเข้าร่วมเหตุการณ์', code: 'deployment-not-found');
}

// ==================================================
// Organization Not Found
// ==================================================

class LeaveOrganizationNotFoundException extends LeaveDisasterEventException {
  const LeaveOrganizationNotFoundException()
    : super('ไม่พบข้อมูลหน่วยกู้ภัย', code: 'organization-not-found');
}

// ==================================================
// Owner Mismatch
// ==================================================

class LeaveDeploymentOwnerMismatchException
    extends LeaveDisasterEventException {
  const LeaveDeploymentOwnerMismatchException()
    : super(
        'หน่วยกู้ภัยไม่มีสิทธิ์ถอนกำลังจากชุดปฏิบัติการนี้',
        code: 'deployment-owner-mismatch',
      );
}

// ==================================================
// Not Active
// ==================================================

class LeaveDeploymentNotActiveException extends LeaveDisasterEventException {
  const LeaveDeploymentNotActiveException()
    : super(
        'ชุดปฏิบัติการนี้ไม่ได้อยู่ในสถานะปฏิบัติงาน',
        code: 'deployment-not-active',
      );
}

class LeaveDeploymentHasMissionsException extends LeaveDisasterEventException {
  const LeaveDeploymentHasMissionsException()
    : super(
        'ยังมีภารกิจที่กำลังดำเนินการหรือรออยู่ในคิว กรุณาจัดการภารกิจให้เรียบร้อยก่อนถอนกำลัง',
        code: 'deployment-has-missions',
      );
}

// ==================================================
// Validation
// ==================================================

class LeaveReasonRequiredException extends LeaveDisasterEventException {
  const LeaveReasonRequiredException()
    : super('กรุณาระบุเหตุผลในการถอนกำลัง', code: 'leave-reason-required');
}

class LeaveReasonTooLongException extends LeaveDisasterEventException {
  const LeaveReasonTooLongException()
    : super(
        'เหตุผลในการถอนกำลังต้องไม่เกิน 255 ตัวอักษร',
        code: 'leave-reason-too-long',
      );
}

class LeaveDetailTooLongException extends LeaveDisasterEventException {
  const LeaveDetailTooLongException()
    : super(
        'รายละเอียดเพิ่มเติมต้องไม่เกิน 255 ตัวอักษร',
        code: 'leave-detail-too-long',
      );
}

class LeaveImageRequiredException extends LeaveDisasterEventException {
  const LeaveImageRequiredException()
    : super('กรุณาแนบรูปภาพยืนยันการถอนกำลัง', code: 'leave-image-required');
}
