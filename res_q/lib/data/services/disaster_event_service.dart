import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/disaster_event_model.dart';

class DisasterEventService {
  DisasterEventService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _collectionName = 'disasterEvents';

  Stream<List<DisasterEvent>> watchActiveDisasterEvents() {
    return _firestore
        .collection(_collectionName)
        .where('eventStatus', isEqualTo: true)
        .snapshots()
        .map(_mapSnapshot);
  }

  Future<List<DisasterEvent>> fetchActiveDisasterEvents() async {
    final snapshot = await _firestore
        .collection(_collectionName)
        .where('eventStatus', isEqualTo: true)
        .get();

    return _mapSnapshot(snapshot);
  }

  List<DisasterEvent> _mapSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final events = <DisasterEvent>[];

    for (final document in snapshot.docs) {
      try {
        final event = DisasterEvent.fromFirestore(document);

        if (!event.isActive) {
          continue;
        }

        if (!event.hasValidBoundary) {
          debugPrint(
            'Skip disaster event '
            '"${document.id}": '
            'invalid disasterBoundary',
          );

          continue;
        }

        events.add(event);
      } on FormatException catch (error) {
        debugPrint(
          'Skip disaster event '
          '"${document.id}": $error',
        );
      } catch (error, stackTrace) {
        debugPrint(
          'Unexpected error parsing '
          'disaster event '
          '"${document.id}": $error',
        );

        debugPrintStack(stackTrace: stackTrace);
      }
    }

    return events;
  }
}
