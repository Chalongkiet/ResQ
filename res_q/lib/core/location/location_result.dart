import 'package:geolocator/geolocator.dart';

enum LocationResultStatus {
  success,

  /// GPS / Location Service ถูกปิด
  serviceDisabled,

  /// ผู้ใช้ยังไม่อนุญาต
  permissionDenied,

  /// ผู้ใช้ปฏิเสธแบบถาวร
  permissionDeniedForever,

  /// หา Location ไม่ทันภายในเวลาที่กำหนด
  timeout,

  /// Error อื่น ๆ
  error,
}

class LocationResult {
  const LocationResult._({required this.status, this.position, this.message});

  final LocationResultStatus status;
  final Position? position;
  final String? message;

  bool get isSuccess =>
      status == LocationResultStatus.success && position != null;

  factory LocationResult.success(Position position) {
    return LocationResult._(
      status: LocationResultStatus.success,
      position: position,
    );
  }

  factory LocationResult.serviceDisabled() {
    return const LocationResult._(
      status: LocationResultStatus.serviceDisabled,
      message: 'กรุณาเปิดบริการตำแหน่งของอุปกรณ์',
    );
  }

  factory LocationResult.permissionDenied() {
    return const LocationResult._(
      status: LocationResultStatus.permissionDenied,
      message: 'กรุณาอนุญาตให้แอปเข้าถึงตำแหน่ง',
    );
  }

  factory LocationResult.permissionDeniedForever() {
    return const LocationResult._(
      status: LocationResultStatus.permissionDeniedForever,
      message: 'สิทธิ์ตำแหน่งถูกปิด กรุณาเปิดสิทธิ์จากการตั้งค่า',
    );
  }

  factory LocationResult.timeout() {
    return const LocationResult._(
      status: LocationResultStatus.timeout,
      message: 'ไม่สามารถหาตำแหน่งปัจจุบันได้ กรุณาลองใหม่อีกครั้ง',
    );
  }

  factory LocationResult.error([String? message]) {
    return LocationResult._(
      status: LocationResultStatus.error,
      message: message ?? 'ไม่สามารถอ่านตำแหน่งปัจจุบันได้',
    );
  }
}
