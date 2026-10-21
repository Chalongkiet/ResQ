abstract final class SosConstants {
  /// ระยะเผื่อจากขอบเขตภัยพิบัติสำหรับ SOS
  ///
  /// ผู้ใช้อยู่ภายนอก Polygon แต่ห่างจากขอบไม่เกิน
  /// 500 เมตร ยังถือว่าอยู่ใกล้พื้นที่ภัยพิบัติ
  static const double disasterBoundaryBufferMeters = 500;

  /// จำนวนจุดขั้นต่ำของ Polygon
  static const int minimumBoundaryPoints = 3;

  SosConstants._();
}
