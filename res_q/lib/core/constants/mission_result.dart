abstract final class MissionResult {
  /// ภารกิจยังไม่เสร็จสิ้น
  static const String pending = 'PENDING';

  /// ภารกิจช่วยเหลือสำเร็จแล้ว
  static const String success = 'SUCCESS';

  static const List<String> values = <String>[pending, success];

  static bool isValid(String result) => values.contains(result);

  MissionResult._();
}
