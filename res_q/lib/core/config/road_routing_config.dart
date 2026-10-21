abstract final class RoadRoutingConfig {
  /// OSRM-compatible routing endpoint.
  ///
  /// Override this value for production or a self-hosted server with:
  /// --dart-define=ROAD_ROUTING_BASE_URL=https://your-routing-server.example
  static const String baseUrl = String.fromEnvironment(
    'ROAD_ROUTING_BASE_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  static const String userAgent = String.fromEnvironment(
    'ROAD_ROUTING_USER_AGENT',
    defaultValue: 'ResQ/1.0 (Flutter emergency rescue routing)',
  );

  RoadRoutingConfig._();
}
