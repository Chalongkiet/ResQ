import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:res_q/data/services/road_route_service.dart';

void main() {
  group('RoadRouteService', () {
    test(
      'requests an OSRM GeoJSON route and maps longitude/latitude',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, contains('/route/v1/driving/'));
          expect(request.url.path, contains('99.1,18.2;99.3,18.4'));
          expect(request.url.queryParameters['geometries'], 'geojson');
          expect(request.url.queryParameters['overview'], 'full');
          expect(request.headers['User-Agent'], isNotEmpty);

          return http.Response(
            '''
          {
            "code": "Ok",
            "routes": [
              {
                "distance": 2450.5,
                "duration": 420.0,
                "geometry": {
                  "type": "LineString",
                  "coordinates": [
                    [99.1, 18.2],
                    [99.2, 18.3],
                    [99.3, 18.4]
                  ]
                }
              }
            ]
          }
          ''',
            200,
            headers: const {'content-type': 'application/json'},
          );
        });
        final service = RoadRouteService(
          client: client,
          baseUrl: 'https://routing.example/',
        );

        final route = await service.getDrivingRoute(
          origin: const LatLng(18.2, 99.1),
          destination: const LatLng(18.4, 99.3),
        );

        expect(route.points, hasLength(3));
        expect(route.points.first.latitude, 18.2);
        expect(route.points.first.longitude, 99.1);
        expect(route.points.last.latitude, 18.4);
        expect(route.points.last.longitude, 99.3);
        expect(route.distanceMeters, 2450.5);
        expect(route.durationSeconds, 420);
      },
    );

    test('reports when OSRM cannot find a road route', () async {
      final client = MockClient(
        (_) async => http.Response('{"code":"NoRoute","routes":[]}', 200),
      );
      final service = RoadRouteService(
        client: client,
        baseUrl: 'https://routing.example',
      );

      expect(
        () => service.getDrivingRoute(
          origin: const LatLng(18.2, 99.1),
          destination: const LatLng(18.4, 99.3),
        ),
        throwsA(
          isA<RoadRouteException>().having(
            (error) => error.message,
            'message',
            contains('ไม่พบเส้นทาง'),
          ),
        ),
      );
    });

    test('rejects invalid coordinates before making a request', () async {
      var requestCount = 0;
      final client = MockClient((_) async {
        requestCount++;
        return http.Response('{}', 200);
      });
      final service = RoadRouteService(
        client: client,
        baseUrl: 'https://routing.example',
      );

      expect(
        () => service.getDrivingRoute(
          origin: const LatLng(95, 99.1),
          destination: const LatLng(18.4, 99.3),
        ),
        throwsA(isA<RoadRouteException>()),
      );
      expect(requestCount, 0);
    });
  });
}
