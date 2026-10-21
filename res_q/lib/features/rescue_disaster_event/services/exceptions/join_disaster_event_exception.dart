class JoinDisasterEventException implements Exception {
  const JoinDisasterEventException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ==================================================
// Rescue Team
// ==================================================

class RescueTeamNotFoundException extends JoinDisasterEventException {
  const RescueTeamNotFoundException() : super('ไม่พบข้อมูลหน่วยกู้ภัย');
}

// ==================================================
// Disaster Event
// ==================================================

class DisasterEventNotFoundException extends JoinDisasterEventException {
  const DisasterEventNotFoundException() : super('ไม่พบเหตุการณ์ภัยพิบัติ');
}

class DisasterEventInactiveException extends JoinDisasterEventException {
  const DisasterEventInactiveException()
    : super('เหตุการณ์ภัยพิบัตินี้ไม่ได้อยู่ในสถานะดำเนินการ');
}

// ==================================================
// Resource
// ==================================================

class RescueResourceRequiredException extends JoinDisasterEventException {
  const RescueResourceRequiredException(super.message);
}

// ==================================================
// Duplicate Join
// ==================================================

class AlreadyJoinedDisasterEventException extends JoinDisasterEventException {
  const AlreadyJoinedDisasterEventException()
    : super('หน่วยกู้ภัยของคุณได้เข้าร่วมเหตุการณ์นี้อยู่แล้ว');
}
