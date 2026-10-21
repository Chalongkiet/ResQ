import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LiveLocationBudgetStore {
  Future<int?> getInt(String key);

  Future<void> setInt(String key, int value);
}

class SharedPreferencesLiveLocationBudgetStore
    implements LiveLocationBudgetStore {
  SharedPreferencesLiveLocationBudgetStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<int?> getInt(String key) => _preferences.getInt(key);

  @override
  Future<void> setInt(String key, int value) => _preferences.setInt(key, value);
}

class LiveLocationWriteBudget {
  LiveLocationWriteBudget({
    LiveLocationBudgetStore? store,
    this.maximumWritesPerWindow = 1200,
    this.windowDuration = const Duration(hours: 24),
    DateTime Function()? clock,
  }) : _store = store ?? SharedPreferencesLiveLocationBudgetStore(),
       _clock = clock ?? DateTime.now;

  final LiveLocationBudgetStore _store;
  final int maximumWritesPerWindow;
  final Duration windowDuration;
  final DateTime Function() _clock;

  Future<bool> tryReserve({required String deploymentId}) async {
    final normalizedDeploymentId = deploymentId.trim();

    if (normalizedDeploymentId.isEmpty || maximumWritesPerWindow <= 0) {
      return false;
    }

    final keySuffix = base64Url
        .encode(utf8.encode(normalizedDeploymentId))
        .replaceAll('=', '');
    final windowStartKey = 'live_location_window_start_$keySuffix';
    final writeCountKey = 'live_location_write_count_$keySuffix';
    final now = _clock();
    final nowMilliseconds = now.millisecondsSinceEpoch;
    final storedWindowStart = await _store.getInt(windowStartKey);
    final storedWriteCount = await _store.getInt(writeCountKey) ?? 0;

    final mustStartNewWindow =
        storedWindowStart == null ||
        nowMilliseconds < storedWindowStart ||
        nowMilliseconds - storedWindowStart >= windowDuration.inMilliseconds;

    if (mustStartNewWindow) {
      await _store.setInt(windowStartKey, nowMilliseconds);
      await _store.setInt(writeCountKey, 1);
      return true;
    }

    if (storedWriteCount >= maximumWritesPerWindow) {
      return false;
    }

    await _store.setInt(writeCountKey, storedWriteCount + 1);
    return true;
  }
}
