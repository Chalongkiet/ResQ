class DisasterBoundaryPoint {
  const DisasterBoundaryPoint({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  bool get isValidCoordinate {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  factory DisasterBoundaryPoint.fromMap(Map<String, dynamic> map) {
    final latitude = map['latitude'];
    final longitude = map['longitude'];

    if (latitude is! num || longitude is! num) {
      throw const FormatException('Invalid disaster boundary point');
    }

    return DisasterBoundaryPoint(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'latitude': latitude, 'longitude': longitude};
  }

  @override
  bool operator ==(Object other) {
    return other is DisasterBoundaryPoint &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
