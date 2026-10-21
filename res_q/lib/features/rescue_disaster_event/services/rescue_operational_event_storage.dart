import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RescueOperationalEventStorage {
  RescueOperationalEventStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;
  Future<void> _pendingWrite = Future<void>.value();

  String _keyFor(String rescueTeamId) =>
      'rescue_operational_event_${Uri.encodeComponent(rescueTeamId)}';

  Future<String?> load(String rescueTeamId) async {
    if (rescueTeamId.trim().isEmpty) return null;
    try {
      final value = await _preferences.getString(_keyFor(rescueTeamId));
      return value == null || value.trim().isEmpty ? null : value.trim();
    } catch (error) {
      debugPrint('Restore operational event failed: $error');
      return null;
    }
  }

  Future<void> save(String rescueTeamId, String eventId) {
    if (rescueTeamId.trim().isEmpty || eventId.trim().isEmpty) {
      return _pendingWrite;
    }
    return _enqueue(
      () => _preferences.setString(_keyFor(rescueTeamId), eventId.trim()),
    );
  }

  Future<void> clear(String rescueTeamId) {
    if (rescueTeamId.trim().isEmpty) return _pendingWrite;
    return _enqueue(() => _preferences.remove(_keyFor(rescueTeamId)));
  }

  Future<void> _enqueue(Future<void> Function() action) {
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await action();
      } catch (error) {
        debugPrint('Save operational event failed: $error');
      }
    });
    return _pendingWrite;
  }
}
