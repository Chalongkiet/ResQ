import 'package:flutter/material.dart';

import '../../../data/models/public_alert_model.dart';

class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.alert, required this.onTap});

  final PublicAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.red.withValues(alpha: 0.08),
        highlightColor: Colors.red.withValues(alpha: 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'EMERGENCY ALERT',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(alert.publishDate),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(
                    alert.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),

                  if (alert.content.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      alert.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 15,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatTime(alert.publishDate),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'อ่านเพิ่มเติม',
                        style: TextStyle(
                          color: Color(0xFFFF5A5F),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Color(0xFFFF5A5F),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    final imageUrl = alert.newsImage.trim();

    if (imageUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: 180,
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 50,
          color: Colors.grey.shade400,
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Image.network(
        imageUrl,
        key: ValueKey(imageUrl),
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
        loadingBuilder:
            (
              BuildContext context,
              Widget child,
              ImageChunkEvent? loadingProgress,
            ) {
              if (loadingProgress == null) {
                return child;
              }

              final expectedBytes = loadingProgress.expectedTotalBytes;

              return Container(
                width: double.infinity,
                height: 180,
                color: Colors.grey.shade100,
                alignment: Alignment.center,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: expectedBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / expectedBytes
                      : null,
                ),
              );
            },
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
              debugPrint('News image loading error: $error');

              return Container(
                width: double.infinity,
                height: 180,
                color: Colors.grey.shade100,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 48,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ไม่สามารถโหลดรูปข่าวได้',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');

    return '$day/$month/${localDate.year}';
  }

  String _formatTime(DateTime date) {
    final localDate = date.toLocal();
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$hour:$minute น.';
  }
}
