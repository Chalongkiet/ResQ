import 'package:flutter/material.dart';

import '../../data/models/public_alert_model.dart';

class NewsDetailPage extends StatelessWidget {
  const NewsDetailPage({super.key, required this.alert});

  final PublicAlert alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final imageUrl = alert.newsImage.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดข่าว')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 3 / 2,
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (imageUrl.isNotEmpty) const SizedBox(height: 20),
          Text(
            alert.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 17,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDateTime(alert.publishDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            alert.content,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final localDate = date.toLocal();

    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$day/$month/${localDate.year} เวลา $hour:$minute น.';
  }
}
