import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/core/geo/geo_utils.dart';
import 'package:res_q/data/models/disaster_boundary_point.dart';

void main() {
  const closedBoundary = <DisasterBoundaryPoint>[
    DisasterBoundaryPoint(latitude: 19.0, longitude: 100.9),
    DisasterBoundaryPoint(latitude: 19.0, longitude: 101.0),
    DisasterBoundaryPoint(latitude: 19.2, longitude: 101.0),
    DisasterBoundaryPoint(latitude: 19.2, longitude: 100.9),
    DisasterBoundaryPoint(latitude: 19.0, longitude: 100.9),
  ];

  test(
    'repeated closing vertex does not put an interior point on the edge',
    () {
      expect(
        GeoUtils.isPointOnPolygonBoundary(
          latitude: 19.1,
          longitude: 100.95,
          polygon: closedBoundary,
        ),
        isFalse,
      );
      expect(
        GeoUtils.isPointStrictlyInsidePolygon(
          latitude: 19.1,
          longitude: 100.95,
          polygon: closedBoundary,
        ),
        isTrue,
      );
    },
  );

  test('a point on the real edge is still excluded', () {
    expect(
      GeoUtils.isPointOnPolygonBoundary(
        latitude: 19.0,
        longitude: 100.95,
        polygon: closedBoundary,
      ),
      isTrue,
    );
    expect(
      GeoUtils.isPointStrictlyInsidePolygon(
        latitude: 19.0,
        longitude: 100.95,
        polygon: closedBoundary,
      ),
      isFalse,
    );
  });

  test('a point outside a closed boundary remains outside', () {
    expect(
      GeoUtils.isPointStrictlyInsidePolygon(
        latitude: 19.3,
        longitude: 100.95,
        polygon: closedBoundary,
      ),
      isFalse,
    );
  });
}
