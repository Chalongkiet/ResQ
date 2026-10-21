import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/models/emergency_request_model.dart';
import '../../../data/services/emergency_request_service.dart';
import '../../../core/constants/emergency_request_status.dart';

class RescueEmergencyRequestController extends ChangeNotifier {
  RescueEmergencyRequestController({EmergencyRequestService? service})
    : _service = service ?? EmergencyRequestService();

  final EmergencyRequestService _service;

  // ==================================================
  // Stream
  // ==================================================

  StreamSubscription<List<EmergencyRequest>>? _subscription;

  String? _watchedEventId;

  // ==================================================
  // State
  // ==================================================

  List<EmergencyRequest> _requests = const <EmergencyRequest>[];

  bool _isLoading = false;

  String? _errorMessage;

  bool _disposed = false;

  // ==================================================
  // Getters
  // ==================================================

  List<EmergencyRequest> get requests {
    return List<EmergencyRequest>.unmodifiable(_requests);
  }

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  String? get watchedEventId => _watchedEventId;

  bool get hasRequests => _requests.isNotEmpty;

  bool get isEmpty => _requests.isEmpty;

  int get requestCount => _requests.length;

  // ==================================================
  // Valid Map Requests
  // ==================================================

  List<EmergencyRequest> get requestsWithValidLocation {
    return _requests
        .where((request) => request.hasValidLocation)
        .toList(growable: false);
  }

  // ==================================================
  // Find Request
  // ==================================================

  EmergencyRequest? findById(String requestId) {
    final normalizedId = requestId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    for (final request in _requests) {
      if (request.requestId == normalizedId) {
        return request;
      }
    }

    return null;
  }

  bool containsRequest(String requestId) {
    return findById(requestId) != null;
  }

  // ==================================================
  // Watch Disaster Event
  // ==================================================

  void watchEvent({required String disasterEventId}) {
    if (_disposed) {
      return;
    }

    final eventId = disasterEventId.trim();

    if (eventId.isEmpty) {
      stopWatching();

      return;
    }

    // ==================================================
    // Already Watching
    // ==================================================

    if (_watchedEventId == eventId && _subscription != null) {
      return;
    }

    _startWatch(eventId);
  }

  // ==================================================
  // Start Watch
  // ==================================================

  void _startWatch(String eventId) {
    debugPrint(
      '[EMERGENCY LIST] '
      'start watch event=$eventId',
    );

    _subscription?.cancel();

    _subscription = null;

    _watchedEventId = eventId;

    _requests = const <EmergencyRequest>[];

    _isLoading = true;

    _errorMessage = null;

    _safeNotifyListeners();

    _subscription = _service
        .watchWaitingByDisasterEvent(disasterEventId: eventId)
        .listen(
          (requests) {
            if (_disposed) {
              return;
            }

            debugPrint(
              '[EMERGENCY LIST] '
              'event=$eventId '
              'waiting=${requests.length} '
              'validLocation='
              '${requests.where((e) => e.hasValidLocation).length}',
            );

            _requests = requests;

            _isLoading = false;

            _errorMessage = null;

            _safeNotifyListeners();
          },
          onError: (Object error) {
            if (_disposed) {
              return;
            }

            debugPrint(
              '[EMERGENCY LIST] '
              'ERROR event=$eventId '
              '$error',
            );

            _isLoading = false;

            _errorMessage = 'ไม่สามารถโหลดรายการขอความช่วยเหลือได้';

            // ปิด subscription ที่ error
            // เพื่อให้ retry สามารถสร้าง stream ใหม่ได้
            _subscription?.cancel();

            _subscription = null;

            _safeNotifyListeners();
          },
        );
  }

  // ==================================================
  // Retry
  // ==================================================

  void retry() {
    if (_disposed) {
      return;
    }

    final eventId = _watchedEventId?.trim();

    if (eventId == null || eventId.isEmpty) {
      return;
    }

    debugPrint(
      '[EMERGENCY LIST] '
      'retry event=$eventId',
    );

    _startWatch(eventId);
  }

  void restoreWaitingRequestLocally(EmergencyRequest request) {
    if (_disposed) return;

    final waitingRequest = request.copyWith(
      requestStatus: EmergencyRequestStatus.waiting,
      updatedAt: DateTime.now(),
    );

    final requests = <EmergencyRequest>[
      waitingRequest,
      ..._requests.where((item) => item.requestId != request.requestId),
    ];

    requests.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    _requests = requests;
    _isLoading = false;
    _errorMessage = null;
    _safeNotifyListeners();
  }

  void removeAcceptedRequestLocally(String requestId) {
    if (_disposed) return;

    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) return;

    final remaining = _requests
        .where((request) => request.requestId != normalizedRequestId)
        .toList(growable: false);

    if (remaining.length == _requests.length) return;

    _requests = remaining;
    _isLoading = false;
    _errorMessage = null;
    _safeNotifyListeners();
  }

  // ==================================================
  // Stop Watching
  // ==================================================

  void stopWatching() {
    if (_disposed) {
      return;
    }

    final hasState =
        _watchedEventId != null ||
        _subscription != null ||
        _requests.isNotEmpty ||
        _isLoading ||
        _errorMessage != null;

    if (!hasState) {
      return;
    }

    debugPrint('[EMERGENCY LIST] stop watch');

    _subscription?.cancel();

    _subscription = null;

    _watchedEventId = null;

    _requests = const <EmergencyRequest>[];

    _isLoading = false;

    _errorMessage = null;

    _safeNotifyListeners();
  }

  // ==================================================
  // Notify
  // ==================================================

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // ==================================================
  // Dispose
  // ==================================================

  @override
  void dispose() {
    _disposed = true;

    _subscription?.cancel();

    _subscription = null;

    super.dispose();
  }
}
