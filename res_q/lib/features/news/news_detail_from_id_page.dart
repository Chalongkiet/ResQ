import 'package:flutter/material.dart';

import '../../data/models/public_alert_model.dart';
import '../../data/services/public_alert_service.dart';
import 'news_detail_page.dart';

/// Reloads a news detail after process death, when GoRouter's `extra` is gone.
class NewsDetailFromIdPage extends StatefulWidget {
  const NewsDetailFromIdPage({super.key, required this.newsId});

  final String newsId;

  @override
  State<NewsDetailFromIdPage> createState() => _NewsDetailFromIdPageState();
}

class _NewsDetailFromIdPageState extends State<NewsDetailFromIdPage> {
  final PublicAlertService _service = PublicAlertService();
  late Future<PublicAlert?> _alertFuture;

  @override
  void initState() {
    super.initState();
    _alertFuture = _service.fetchActiveAlertById(widget.newsId);
  }

  void _retry() {
    setState(() {
      _alertFuture = _service.fetchActiveAlertById(widget.newsId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PublicAlert?>(
      future: _alertFuture,
      builder: (context, snapshot) {
        final alert = snapshot.data;
        if (alert != null) return NewsDetailPage(alert: alert);

        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('รายละเอียดข่าว')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  snapshot.hasError
                      ? 'โหลดข่าวไม่สำเร็จ กรุณาลองใหม่'
                      : 'ไม่พบข่าวที่ต้องการ',
                ),
                if (snapshot.hasError) ...[
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _retry, child: const Text('ลองใหม่')),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
