import 'package:cloud_firestore/cloud_firestore.dart';

class PublicAlert {
  const PublicAlert({
    required this.id,
    required this.title,
    required this.content,
    required this.publishDate,
    required this.newsImage,
    required this.newsStatus,
  });

  final String id;
  final String title;
  final String content;
  final DateTime publishDate;
  final String newsImage;
  final bool newsStatus;

  factory PublicAlert.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final publishDateValue = data['publishDate'];

    return PublicAlert(
      id: document.id,
      title: data['title'] as String? ?? 'ไม่มีหัวข้อข่าว',
      content: data['content'] as String? ?? '',
      publishDate: publishDateValue is Timestamp
          ? publishDateValue.toDate()
          : DateTime.now(),
      newsImage: (data['newsImage'] as String? ?? '').trim(),
      newsStatus: data['newsStatus'] as bool? ?? false,
    );
  }
}
