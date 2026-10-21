class RescueLocationException implements Exception {
  const RescueLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RescueLocationServiceDisabledException extends RescueLocationException {
  const RescueLocationServiceDisabledException()
    : super('กรุณาเปิดบริการตำแหน่ง (GPS) ก่อนเข้าร่วมภารกิจ');
}

class RescueLocationPermissionDeniedException extends RescueLocationException {
  const RescueLocationPermissionDeniedException()
    : super('ไม่สามารถเข้าถึงตำแหน่งได้ กรุณาอนุญาตการเข้าถึงตำแหน่ง');
}

class RescueLocationPermissionDeniedForeverException
    extends RescueLocationException {
  const RescueLocationPermissionDeniedForeverException()
    : super(
        'สิทธิ์เข้าถึงตำแหน่งถูกปิดถาวร '
        'กรุณาเปิดสิทธิ์ Location จากการตั้งค่าแอป',
      );
}
