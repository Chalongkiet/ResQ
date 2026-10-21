import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/public_alert_model.dart';

class PublicAlertService {
  PublicAlertService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<PublicAlert>> watchPublicAlerts() {
    return _firestore
        .collection('news')
        .where('newsStatus', isEqualTo: true)
        .orderBy('publishDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(PublicAlert.fromFirestore).toList(),
        );
  }

  Future<PublicAlert?> fetchActiveAlertById(String newsId) async {
    final normalizedId = newsId.trim();
    if (normalizedId.isEmpty) return null;

    final document = await _firestore
        .collection('news')
        .doc(normalizedId)
        .get();
    if (!document.exists || document.data()?['newsStatus'] != true) {
      return null;
    }

    return PublicAlert.fromFirestore(document);
  }
}
