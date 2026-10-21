import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:res_q/data/services/road_route_service.dart';
import 'package:res_q/shared/controllers/road_route_controller.dart';

void main() {
  group('RoadRouteController', () {
    test('waits for the minimum interval before rerouting', () async {
      var requestCount = 0;
      final service = RoadRouteService(
        client: MockClient((_) async {
          requestCount++;
          return _routeResponse();
        }),
        baseUrl: 'https://routing.example',
      );
      final controller = RoadRouteController(
        service: service,
        minimumRerouteDistanceMeters: 20,
        minimumRerouteInterval: const Duration(milliseconds: 80),
      );

      await controller.updateRoute(
        origin: const LatLng(18.0000, 99.0000),
        destination: const LatLng(18.0100, 99.0100),
      );
      await controller.updateRoute(
        origin: const LatLng(18.0010, 99.0000),
        destination: const LatLng(18.0100, 99.0100),
      );

      expect(requestCount, 1);

      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(requestCount, 2);
      controller.dispose();
    });

    test('does not reroute while moving along the existing route', () async {
      var requestCount = 0;
      final service = RoadRouteService(
        client: MockClient((_) async {
          requestCount++;
          return _routeResponse();
        }),
        baseUrl: 'https://routing.example',
      );
      final controller = RoadRouteController(
        service: service,
        minimumRerouteInterval: Duration.zero,
      );

      await controller.updateRoute(
        origin: const LatLng(18.0000, 99.0000),
        destination: const LatLng(18.0100, 99.0100),
      );

      // เคลื่อนจากจุดเริ่มมากกว่า 700 เมตร แต่ยังอยู่บน polyline เดิม
      await controller.updateRoute(
        origin: const LatLng(18.0050, 99.0050),
        destination: const LatLng(18.0100, 99.0100),
      );

      expect(requestCount, 1);
      controller.dispose();
    });

    test('returns only the untraveled part of the route', () async {
      final service = RoadRouteService(
        client: MockClient((_) async => _routeResponse()),
        baseUrl: 'https://routing.example',
      );
      final controller = RoadRouteController(service: service);

      await controller.updateRoute(
        origin: const LatLng(18.0000, 99.0000),
        destination: const LatLng(18.0100, 99.0100),
      );

      final remaining = controller.remainingRoutePoints(
        const LatLng(18.0050, 99.0050),
      );

      expect(remaining, hasLength(2));
      expect(remaining.first.latitude, closeTo(18.0050, 0.000001));
      expect(remaining.first.longitude, closeTo(99.0050, 0.000001));
      expect(remaining.last, const LatLng(18.0100, 99.0100));
      controller.dispose();
    });

    test(
      'does not reroute a stationary origin snapped away from the road',
      () async {
        var requestCount = 0;
        final service = RoadRouteService(
          client: MockClient((_) async {
            requestCount++;
            return _snappedRouteResponse();
          }),
          baseUrl: 'https://routing.example',
        );
        final controller = RoadRouteController(
          service: service,
          minimumRerouteDistanceMeters: 50,
          maximumRouteDeviationMeters: 60,
          minimumRerouteInterval: Duration.zero,
        );
        const origin = LatLng(18.0000, 99.0000);
        const destination = LatLng(18.0100, 99.0100);

        await controller.updateRoute(origin: origin, destination: destination);

        // OSRM snapped the route roughly 100 metres east of the GPS origin,
        // but another identical GPS sample must not trigger a new request.
        await controller.updateRoute(origin: origin, destination: destination);

        expect(requestCount, 1);
        controller.dispose();
      },
    );

    test(
      'keeps only one request in flight and queues the latest origin',
      () async {
        var requestCount = 0;
        final firstResponse = Completer<http.Response>();
        final firstRequestStarted = Completer<void>();
        final requestedOrigins = <String>[];
        final service = RoadRouteService(
          client: MockClient((request) async {
            requestCount++;
            requestedOrigins.add(
              request.url.pathSegments.last.split(';').first,
            );

            if (requestCount == 1) {
              firstRequestStarted.complete();
              return firstResponse.future;
            }

            return _routeResponse();
          }),
          baseUrl: 'https://routing.example',
        );
        final controller = RoadRouteController(
          service: service,
          minimumRerouteDistanceMeters: 20,
          minimumRerouteInterval: Duration.zero,
        );

        final firstRequest = controller.updateRoute(
          origin: const LatLng(18.0000, 99.0000),
          destination: const LatLng(18.0100, 99.0100),
        );
        await firstRequestStarted.future;
        await controller.updateRoute(
          origin: const LatLng(18.0010, 99.0000),
          destination: const LatLng(18.0100, 99.0100),
        );
        await controller.updateRoute(
          origin: const LatLng(18.0020, 99.0000),
          destination: const LatLng(18.0100, 99.0100),
        );

        expect(requestCount, 1);

        firstResponse.complete(_routeResponse());
        await firstRequest;
        await Future<void>.delayed(Duration.zero);

        expect(requestCount, 2);
        expect(requestedOrigins.last, startsWith('99.0,18.002'));
        controller.dispose();
      },
    );

    test('ignores GPS movement below the reroute distance', () async {
      var requestCount = 0;
      final service = RoadRouteService(
        client: MockClient((_) async {
          requestCount++;
          return _routeResponse();
        }),
        baseUrl: 'https://routing.example',
      );
      final controller = RoadRouteController(
        service: service,
        minimumRerouteDistanceMeters: 50,
        minimumRerouteInterval: Duration.zero,
      );

      await controller.updateRoute(
        origin: const LatLng(18.0000, 99.0000),
        destination: const LatLng(18.0100, 99.0100),
      );
      await controller.updateRoute(
        origin: const LatLng(18.0001, 99.0000),
        destination: const LatLng(18.0100, 99.0100),
      );

      expect(requestCount, 1);
      controller.dispose();
    });
  });
}

http.Response _routeResponse() {
  return http.Response('''
    {
      "code": "Ok",
      "routes": [
        {
          "distance": 1000,
          "duration": 300,
          "geometry": {
            "type": "LineString",
            "coordinates": [[99.0, 18.0], [99.01, 18.01]]
          }
        }
      ]
    }
    ''', 200);
}

http.Response _snappedRouteResponse() {
  return http.Response('''
    {
      "code": "Ok",
      "routes": [
        {
          "distance": 1000,
          "duration": 300,
          "geometry": {
            "type": "LineString",
            "coordinates": [[99.001, 18.0], [99.01, 18.01]]
          }
        }
      ]
    }
    ''', 200);
}
