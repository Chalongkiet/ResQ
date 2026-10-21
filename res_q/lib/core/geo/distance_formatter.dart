abstract final class DistanceFormatter {
  static String format(double distanceMeters, {bool isInside = false}) {
    if (isInside) {
      return 'คุณอยู่ในพื้นที่ภัยพิบัติ';
    }

    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} ม.';
    }

    final kilometers = distanceMeters / 1000;

    return '${kilometers.toStringAsFixed(1)} กม.';
  }

  DistanceFormatter._();
}
