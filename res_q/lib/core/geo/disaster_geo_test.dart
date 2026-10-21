// import 'package:flutter_test/flutter_test.dart';
// import 'package:res_q/core/geo/geo_utils.dart';
// import 'package:res_q/data/models/disaster_boundary_point.dart';

// void main() {
//   const polygon = [
//     DisasterBoundaryPoint(latitude: 18.0, longitude: 98.0),
//     DisasterBoundaryPoint(latitude: 18.0, longitude: 99.0),
//     DisasterBoundaryPoint(latitude: 19.0, longitude: 99.0),
//     DisasterBoundaryPoint(latitude: 19.0, longitude: 98.0),
//     DisasterBoundaryPoint(latitude: 18.0, longitude: 98.0),
//   ];

//   test('point inside polygon returns true', () {
//     final result = GeoUtils.isPointStrictlyInsidePolygon(
//       latitude: 18.5,
//       longitude: 98.5,
//       polygon: polygon,
//     );

//     expect(result, isTrue);
//   });

//   test('point outside polygon returns false', () {
//     final result = GeoUtils.isPointStrictlyInsidePolygon(
//       latitude: 20.0,
//       longitude: 100.0,
//       polygon: polygon,
//     );

//     expect(result, isFalse);
//   });

//   test('point on polygon boundary returns false', () {
//     final result = GeoUtils.isPointStrictlyInsidePolygon(
//       latitude: 18.0,
//       longitude: 98.5,
//       polygon: polygon,
//     );

//     expect(result, isFalse);
//   });
// }
