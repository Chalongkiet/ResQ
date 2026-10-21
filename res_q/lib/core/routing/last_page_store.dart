import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_routes.dart';

/// Stores only restorable pages. Dialogs and in-memory navigation stacks are
/// intentionally not persisted.
class LastPageStore {
  LastPageStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _key = 'last_restorable_page';

  final SharedPreferencesAsync _preferences;
  Future<void> _pendingSave = Future<void>.value();
  String? _lastQueuedLocation;

  Future<String?> load() async {
    try {
      return RestorablePagePolicy.normalize(await _preferences.getString(_key));
    } catch (error) {
      debugPrint('Last page restore failed: $error');
      return null;
    }
  }

  Future<void> save(String location) {
    final normalized = RestorablePagePolicy.normalize(location);
    if (normalized == null || normalized == _lastQueuedLocation) {
      return _pendingSave;
    }

    _lastQueuedLocation = normalized;
    _pendingSave = _pendingSave.then((_) async {
      try {
        await _preferences.setString(_key, normalized);
      } catch (error) {
        if (_lastQueuedLocation == normalized) {
          _lastQueuedLocation = null;
        }
        debugPrint('Last page save failed: $error');
      }
    });
    return _pendingSave;
  }
}

abstract final class RestorablePagePolicy {
  static String? normalize(String? location) {
    if (location == null || location.isEmpty) return null;

    final uri = Uri.tryParse(location);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return null;

    final path = uri.path;
    if (path == AppRoutePaths.home ||
        path == AppRoutePaths.news ||
        path == AppRoutePaths.profile ||
        path == AppRoutePaths.sos ||
        path == AppRoutePaths.rescueLogin ||
        path == AppRoutePaths.rescueHome ||
        path == AppRoutePaths.rescueMissionHistory) {
      return path;
    }

    final segments = uri.pathSegments;
    if (segments.length == 2 &&
        segments[1].isNotEmpty &&
        (segments[0] == 'news' || segments[0] == 'emergency-tracking')) {
      return path;
    }

    return null;
  }

  static String initialLocation({
    required String? savedLocation,
    required bool hasRescueSession,
  }) {
    final location = normalize(savedLocation);

    if (hasRescueSession) {
      return location == AppRoutePaths.rescueMissionHistory
          ? AppRoutePaths.rescueMissionHistory
          : AppRoutePaths.rescueHome;
    }

    if (location == AppRoutePaths.rescueHome ||
        location == AppRoutePaths.rescueMissionHistory) {
      return AppRoutePaths.rescueLogin;
    }

    return location ?? AppRoutePaths.home;
  }

  RestorablePagePolicy._();
}
