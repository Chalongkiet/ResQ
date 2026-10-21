import 'package:flutter_test/flutter_test.dart';
import 'package:res_q/data/models/disaster_event_model.dart';

void main() {
  final now = DateTime.utc(2026, 9, 16);

  Map<String, dynamic> eventData({Object? detail = ''}) => <String, dynamic>{
    'eventName': 'น้ำท่วมชุมชน',
    'disasterType': 'อุทกภัย',
    'areaDescription': 'ชุมชนริมแม่น้ำ',
    'eventDetail': detail,
    'eventStartDate': now,
    'eventEndDate': null,
    'eventStatus': true,
    'disasterBoundary': <Map<String, double>>[
      <String, double>{'latitude': 18.88, 'longitude': 99.03},
      <String, double>{'latitude': 18.89, 'longitude': 99.03},
      <String, double>{'latitude': 18.89, 'longitude': 99.04},
    ],
    'createdAt': now,
    'updatedAt': now,
  };

  test('active event remains visible when eventDetail is empty', () {
    final event = DisasterEvent.fromMap(id: 'event-1', data: eventData());

    expect(event.eventDetail, isEmpty);
    expect(event.isActive, isTrue);
    expect(event.hasValidBoundary, isTrue);
  });

  test('missing eventDetail remains empty through cache round-trip', () {
    final data = eventData()..remove('eventDetail');
    final event = DisasterEvent.fromMap(id: 'event-2', data: data);
    final restored = DisasterEvent.fromCacheMap(event.toCacheMap());

    expect(restored.eventDetail, isEmpty);
    expect(restored.id, 'event-2');
  });

  test('invalid eventDetail type still fails validation', () {
    expect(
      () => DisasterEvent.fromMap(id: 'event-3', data: eventData(detail: 42)),
      throwsFormatException,
    );
  });
}
