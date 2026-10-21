import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/disaster_event_model.dart';

class DisasterCacheService {
  DisasterCacheService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static const String _cacheKey = 'cached_disaster_events';

  static const String _cacheUpdatedAtKey = 'cached_disaster_events_updated_at';

  Future<void> saveEvents(List<DisasterEvent> events) async {
    try {
      final data = events.map((event) => event.toCacheMap()).toList();

      final json = jsonEncode(data);

      await _preferences.setString(_cacheKey, json);

      await _preferences.setString(
        _cacheUpdatedAtKey,
        DateTime.now().toIso8601String(),
      );

      debugPrint(
        'Disaster cache saved: '
        '${events.length} events',
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to save disaster cache: $error');

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<List<DisasterEvent>> loadEvents() async {
    try {
      final json = await _preferences.getString(_cacheKey);

      if (json == null || json.trim().isEmpty) {
        return const <DisasterEvent>[];
      }

      final decoded = jsonDecode(json);

      if (decoded is! List) {
        throw const FormatException('Cached disaster events must be a List');
      }

      final events = <DisasterEvent>[];

      for (final item in decoded) {
        try {
          if (item is! Map) {
            continue;
          }

          final event = DisasterEvent.fromCacheMap(
            Map<String, dynamic>.from(item),
          );

          if (!event.isActive) {
            continue;
          }

          if (!event.hasValidBoundary) {
            continue;
          }

          events.add(event);
        } catch (error) {
          debugPrint(
            'Skip invalid cached disaster event: '
            '$error',
          );
        }
      }

      return events;
    } catch (error, stackTrace) {
      debugPrint('Failed to load disaster cache: $error');

      debugPrintStack(stackTrace: stackTrace);

      return const <DisasterEvent>[];
    }
  }

  Future<DateTime?> getLastUpdatedAt() async {
    final value = await _preferences.getString(_cacheUpdatedAtKey);

    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  Future<bool> hasCache() async {
    final json = await _preferences.getString(_cacheKey);

    return json != null && json.trim().isNotEmpty;
  }

  Future<void> clear() async {
    try {
      await Future.wait([
        _preferences.remove(_cacheKey),
        _preferences.remove(_cacheUpdatedAtKey),
      ]);

      debugPrint('Disaster cache cleared');
    } catch (error) {
      debugPrint('Failed to clear disaster cache: $error');
    }
  }
}
