import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'connectivity_status.dart';

class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<AppConnectivityStatus> checkStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();

      return _mapResults(results);
    } catch (error, stackTrace) {
      debugPrint('Connectivity check error: $error');

      debugPrintStack(stackTrace: stackTrace);

      return AppConnectivityStatus.offline;
    }
  }

  Future<bool> isOnline() async {
    final status = await checkStatus();
    return status.isOnline;
  }

  Stream<AppConnectivityStatus> watchStatus() {
    return _connectivity.onConnectivityChanged.map(_mapResults).distinct();
  }

  AppConnectivityStatus _mapResults(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      return AppConnectivityStatus.offline;
    }

    final hasNoConnection = results.contains(ConnectivityResult.none);

    if (hasNoConnection) {
      return AppConnectivityStatus.offline;
    }

    return AppConnectivityStatus.online;
  }
}
