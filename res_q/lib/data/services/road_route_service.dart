import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/config/road_routing_config.dart';
import '../models/road_route_model.dart';

class RoadRouteException implements Exception {
  const RoadRouteException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RoadRouteService {
  RoadRouteService({
    http.Client? client,
    String baseUrl = RoadRoutingConfig.baseUrl,
    Duration timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _timeout = timeout;

  final http.Client _client;
  final bool _ownsClient;
  final String _baseUrl;
  final Duration _timeout;

  Future<RoadRoute> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    _validateCoordinate(origin);
    _validateCoordinate(destination);

    final coordinates =
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}';
    final uri = Uri.parse('$_baseUrl/route/v1/driving/$coordinates').replace(
      queryParameters: const <String, String>{
        'alternatives': 'false',
        'steps': 'false',
        'overview': 'full',
        'geometries': 'geojson',
      },
    );

    late final http.Response response;

    try {
      response = await _client
          .get(
            uri,
            headers: const <String, String>{
              'Accept': 'application/json',
              'User-Agent': RoadRoutingConfig.userAgent,
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const RoadRouteException('หมดเวลารอเส้นทาง กรุณาลองใหม่');
    } on http.ClientException {
      throw const RoadRouteException('ไม่สามารถเชื่อมต่อบริการเส้นทางได้');
    }

    if (response.statusCode != 200) {
      throw RoadRouteException(
        'บริการเส้นทางตอบกลับผิดพลาด (${response.statusCode})',
      );
    }

    final Map<String, dynamic> payload;

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }

      payload = decoded;
    } on FormatException {
      throw const RoadRouteException('ข้อมูลเส้นทางไม่ถูกต้อง');
    }

    if (payload['code'] != 'Ok') {
      final code = payload['code'];

      if (code == 'NoRoute') {
        throw const RoadRouteException('ไม่พบเส้นทางถนนระหว่างสองตำแหน่ง');
      }

      throw const RoadRouteException('ไม่สามารถคำนวณเส้นทางได้');
    }

    final routes = payload['routes'];

    if (routes is! List || routes.isEmpty || routes.first is! Map) {
      throw const RoadRouteException('ไม่พบข้อมูลเส้นทาง');
    }

    final route = Map<String, dynamic>.from(routes.first as Map);
    final geometry = route['geometry'];

    if (geometry is! Map || geometry['coordinates'] is! List) {
      throw const RoadRouteException('รูปแบบเส้นทางไม่ถูกต้อง');
    }

    final rawCoordinates = geometry['coordinates'] as List;
    final points = <LatLng>[];

    for (final rawCoordinate in rawCoordinates) {
      if (rawCoordinate is! List || rawCoordinate.length < 2) {
        continue;
      }

      final longitude = rawCoordinate[0];
      final latitude = rawCoordinate[1];

      if (latitude is! num || longitude is! num) {
        continue;
      }

      final point = LatLng(latitude.toDouble(), longitude.toDouble());

      if (_isValidCoordinate(point)) {
        points.add(point);
      }
    }

    if (points.length < 2) {
      throw const RoadRouteException('เส้นทางมีข้อมูลไม่เพียงพอ');
    }

    final distance = route['distance'];
    final duration = route['duration'];

    if (distance is! num || duration is! num) {
      throw const RoadRouteException('ข้อมูลระยะทางไม่ถูกต้อง');
    }

    return RoadRoute(
      points: List<LatLng>.unmodifiable(points),
      distanceMeters: distance.toDouble(),
      durationSeconds: duration.toDouble(),
    );
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  static void _validateCoordinate(LatLng coordinate) {
    if (!_isValidCoordinate(coordinate)) {
      throw const RoadRouteException('พิกัดสำหรับคำนวณเส้นทางไม่ถูกต้อง');
    }
  }

  static bool _isValidCoordinate(LatLng coordinate) {
    return coordinate.latitude.isFinite &&
        coordinate.longitude.isFinite &&
        coordinate.latitude >= -90 &&
        coordinate.latitude <= 90 &&
        coordinate.longitude >= -180 &&
        coordinate.longitude <= 180;
  }
}
