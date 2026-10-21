import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/road_route_model.dart';
import '../../data/services/road_route_service.dart';

enum RoadRouteLoadState { idle, loading, ready, failure }

class RoadRouteController extends ChangeNotifier {
  RoadRouteController({
    RoadRouteService? service,
    this.minimumRerouteDistanceMeters = 50,
    this.maximumRouteDeviationMeters = 60,
    this.minimumRerouteInterval = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _service = service ?? RoadRouteService(),
       _ownsService = service == null,
       _clock = clock ?? DateTime.now;

  final RoadRouteService _service;
  final bool _ownsService;
  final double minimumRerouteDistanceMeters;
  final double maximumRouteDeviationMeters;
  final Duration minimumRerouteInterval;
  final DateTime Function() _clock;

  static const Distance _distance = Distance();

  RoadRouteLoadState _state = RoadRouteLoadState.idle;
  RoadRouteLoadState get state => _state;

  RoadRoute? _route;
  RoadRoute? get route => _route;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  LatLng? _lastAttemptOrigin;
  LatLng? _lastAttemptDestination;
  LatLng? _pendingOrigin;
  LatLng? _pendingDestination;
  LatLng? _queuedOrigin;
  LatLng? _queuedDestination;
  bool _queuedForce = false;
  DateTime? _lastRequestStartedAt;
  Timer? _rerouteTimer;

  int _requestVersion = 0;
  int _revision = 0;
  int get revision => _revision;

  bool _disposed = false;

  bool get hasRoute => _route != null && _route!.points.length >= 2;
  bool get isLoading => _state == RoadRouteLoadState.loading;
  bool get hasFailed => _state == RoadRouteLoadState.failure;

  List<LatLng> remainingRoutePoints(LatLng currentPosition) {
    final currentRoute = _route;

    if (currentRoute == null || currentRoute.points.length < 2) {
      return const <LatLng>[];
    }

    final nearest = _nearestRoutePosition(currentPosition, currentRoute.points);
    final remaining = <LatLng>[
      nearest.projectedPoint,
      ...currentRoute.points.skip(nearest.segmentIndex + 1),
    ];

    return List<LatLng>.unmodifiable(remaining);
  }

  Future<void> updateRoute({
    required LatLng origin,
    required LatLng destination,
    bool force = false,
  }) async {
    if (_disposed) {
      return;
    }

    final destinationChanged = !_isNear(
      _lastAttemptDestination,
      destination,
      5,
    );
    final originRequiresRouteUpdate = _originRequiresRouteUpdate(origin);
    final matchesPending =
        _isNear(_pendingOrigin, origin, 5) &&
        _isNear(_pendingDestination, destination, 5);

    if (!force && matchesPending) {
      return;
    }

    if (!force && !destinationChanged && !originRequiresRouteUpdate) {
      return;
    }

    if (_pendingOrigin != null) {
      _queueRoute(
        origin: origin,
        destination: destination,
        force: force || destinationChanged,
      );
      return;
    }

    if (!force && !destinationChanged && !_rerouteIntervalHasElapsed()) {
      _queueRoute(origin: origin, destination: destination);
      _scheduleQueuedRoute();
      return;
    }

    await _startRouteRequest(origin: origin, destination: destination);
  }

  Future<void> _startRouteRequest({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (_disposed) {
      return;
    }

    _rerouteTimer?.cancel();
    _rerouteTimer = null;

    final requestVersion = ++_requestVersion;

    final destinationChanged = !_isNear(
      _lastAttemptDestination,
      destination,
      5,
    );

    if (destinationChanged) {
      _route = null;
    }

    _lastAttemptOrigin = origin;
    _lastAttemptDestination = destination;
    _pendingOrigin = origin;
    _pendingDestination = destination;
    _lastRequestStartedAt = _clock();
    _state = RoadRouteLoadState.loading;
    _errorMessage = null;
    _safeNotify();

    try {
      final route = await _service.getDrivingRoute(
        origin: origin,
        destination: destination,
      );

      if (_disposed || requestVersion != _requestVersion) {
        return;
      }

      _route = route;
      _state = RoadRouteLoadState.ready;
      _errorMessage = null;
      _revision++;
    } on RoadRouteException catch (error) {
      if (_disposed || requestVersion != _requestVersion) {
        return;
      }

      _state = RoadRouteLoadState.failure;
      _errorMessage = error.message;
    } catch (_) {
      if (_disposed || requestVersion != _requestVersion) {
        return;
      }

      _state = RoadRouteLoadState.failure;
      _errorMessage = 'ไม่สามารถโหลดเส้นทางตามถนนได้';
    } finally {
      if (!_disposed && requestVersion == _requestVersion) {
        _pendingOrigin = null;
        _pendingDestination = null;
        _safeNotify();
        _runQueuedRouteIfNeeded();
      }
    }
  }

  void _queueRoute({
    required LatLng origin,
    required LatLng destination,
    bool force = false,
  }) {
    _queuedOrigin = origin;
    _queuedDestination = destination;
    _queuedForce = _queuedForce || force;
  }

  void _runQueuedRouteIfNeeded() {
    if (_disposed || _pendingOrigin != null) {
      return;
    }

    final origin = _queuedOrigin;
    final destination = _queuedDestination;

    if (origin == null || destination == null) {
      return;
    }

    final force = _queuedForce;
    final destinationChanged = !_isNear(
      _lastAttemptDestination,
      destination,
      5,
    );
    final originRequiresRouteUpdate = _originRequiresRouteUpdate(origin);

    if (!force && !destinationChanged && !originRequiresRouteUpdate) {
      _clearQueuedRoute();
      return;
    }

    if (!force && !destinationChanged && !_rerouteIntervalHasElapsed()) {
      _scheduleQueuedRoute();
      return;
    }

    _clearQueuedRoute();
    unawaited(_startRouteRequest(origin: origin, destination: destination));
  }

  void _scheduleQueuedRoute() {
    if (_disposed || _rerouteTimer?.isActive == true) {
      return;
    }

    final lastStartedAt = _lastRequestStartedAt;
    final elapsed = lastStartedAt == null
        ? minimumRerouteInterval
        : _clock().difference(lastStartedAt);
    final remaining = minimumRerouteInterval - elapsed;
    final delay = remaining.isNegative ? Duration.zero : remaining;

    _rerouteTimer = Timer(delay, () {
      _rerouteTimer = null;
      _runQueuedRouteIfNeeded();
    });
  }

  bool _rerouteIntervalHasElapsed() {
    final lastStartedAt = _lastRequestStartedAt;

    if (lastStartedAt == null) {
      return true;
    }

    return _clock().difference(lastStartedAt) >= minimumRerouteInterval;
  }

  void _clearQueuedRoute() {
    _queuedOrigin = null;
    _queuedDestination = null;
    _queuedForce = false;
  }

  void clear() {
    if (_disposed || (_state == RoadRouteLoadState.idle && _route == null)) {
      return;
    }

    _requestVersion++;
    _rerouteTimer?.cancel();
    _rerouteTimer = null;
    _state = RoadRouteLoadState.idle;
    _route = null;
    _errorMessage = null;
    _lastAttemptOrigin = null;
    _lastAttemptDestination = null;
    _pendingOrigin = null;
    _pendingDestination = null;
    _clearQueuedRoute();
    _lastRequestStartedAt = null;
    _revision++;
    _safeNotify();
  }

  bool _isNear(LatLng? first, LatLng second, double toleranceMeters) {
    if (first == null) {
      return false;
    }

    return _distance.as(LengthUnit.Meter, first, second) <= toleranceMeters;
  }

  bool _originRequiresRouteUpdate(LatLng origin) {
    final currentRoute = _route;

    if (currentRoute != null && currentRoute.points.length >= 2) {
      final hasMovedEnough = !_isNear(
        _lastAttemptOrigin,
        origin,
        minimumRerouteDistanceMeters,
      );
      final isOutsideCurrentRoute =
          _distanceToRouteMeters(origin, currentRoute.points) >
          maximumRouteDeviationMeters;

      // OSRM may snap the requested origin to the nearest drivable road.
      // A stationary device can therefore be outside the returned polyline
      // even though the rescue team has not started moving. Re-route only
      // after both meaningful movement and a real route deviation occur.
      return hasMovedEnough && isOutsideCurrentRoute;
    }

    return !_isNear(_lastAttemptOrigin, origin, minimumRerouteDistanceMeters);
  }

  double _distanceToRouteMeters(LatLng point, List<LatLng> routePoints) {
    return _nearestRoutePosition(point, routePoints).distanceMeters;
  }

  _NearestRoutePosition _nearestRoutePosition(
    LatLng point,
    List<LatLng> routePoints,
  ) {
    if (routePoints.length < 2) {
      return _NearestRoutePosition(
        distanceMeters: double.infinity,
        segmentIndex: 0,
        projectedPoint: point,
      );
    }

    const metersPerDegreeLatitude = 111320.0;
    final metersPerDegreeLongitude =
        metersPerDegreeLatitude * math.cos(point.latitude * math.pi / 180);
    var minimumSquaredDistance = double.infinity;
    var nearestSegmentIndex = 0;
    var nearestProjectedPoint = routePoints.first;

    for (var index = 0; index < routePoints.length - 1; index++) {
      final start = routePoints[index];
      final end = routePoints[index + 1];
      final startX =
          (start.longitude - point.longitude) * metersPerDegreeLongitude;
      final startY =
          (start.latitude - point.latitude) * metersPerDegreeLatitude;
      final endX = (end.longitude - point.longitude) * metersPerDegreeLongitude;
      final endY = (end.latitude - point.latitude) * metersPerDegreeLatitude;
      final segmentX = endX - startX;
      final segmentY = endY - startY;
      final segmentLengthSquared = segmentX * segmentX + segmentY * segmentY;

      final projection = segmentLengthSquared == 0
          ? 0.0
          : (-(startX * segmentX + startY * segmentY) / segmentLengthSquared)
                .clamp(0.0, 1.0);
      final nearestX = startX + segmentX * projection;
      final nearestY = startY + segmentY * projection;
      final squaredDistance = nearestX * nearestX + nearestY * nearestY;

      if (squaredDistance < minimumSquaredDistance) {
        minimumSquaredDistance = squaredDistance;
        nearestSegmentIndex = index;
        nearestProjectedPoint = LatLng(
          start.latitude + (end.latitude - start.latitude) * projection,
          start.longitude + (end.longitude - start.longitude) * projection,
        );
      }
    }

    return _NearestRoutePosition(
      distanceMeters: math.sqrt(minimumSquaredDistance),
      segmentIndex: nearestSegmentIndex,
      projectedPoint: nearestProjectedPoint,
    );
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    _rerouteTimer?.cancel();
    _rerouteTimer = null;
    _clearQueuedRoute();

    if (_ownsService) {
      _service.dispose();
    }

    super.dispose();
  }
}

class _NearestRoutePosition {
  const _NearestRoutePosition({
    required this.distanceMeters,
    required this.segmentIndex,
    required this.projectedPoint,
  });

  final double distanceMeters;
  final int segmentIndex;
  final LatLng projectedPoint;
}
