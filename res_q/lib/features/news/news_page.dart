import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../data/models/public_alert_model.dart';
import '../../data/services/public_alert_service.dart';
import 'widgets/news_card.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final PublicAlertService _publicAlertService = PublicAlertService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.campaign_outlined,
                color: Color(0xFFFF5A5F),
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ข่าวสารจากส่วนกลาง',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<PublicAlert>>(
          stream: _publicAlertService.watchPublicAlerts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const _NewsLoadingState();
            }

            if (snapshot.hasError) {
              debugPrint('NewsPage Firestore error: ${snapshot.error}');

              return _NewsErrorState(error: snapshot.error);
            }

            final newsList = snapshot.data ?? const <PublicAlert>[];

            if (newsList.isEmpty) {
              return const _EmptyNewsState();
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: newsList.length,
              separatorBuilder: (context, index) {
                return const SizedBox(height: 16);
              },
              itemBuilder: (context, index) {
                final alert = newsList[index];

                return NewsCard(
                  alert: alert,
                  onTap: () {
                    context.pushNamed(
                      AppRouteNames.newsDetail,
                      pathParameters: {'newsId': alert.id},
                      extra: alert,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // void _showNewsDetail(BuildContext context, PublicAlert alert) {
  //   final theme = Theme.of(context);
  //   final colors = theme.colorScheme;

  //   showModalBottomSheet<void>(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: colors.surface,
  //     showDragHandle: true,
  //     builder: (context) {
  //       return SafeArea(
  //         child: DraggableScrollableSheet(
  //           expand: false,
  //           initialChildSize: 0.75,
  //           minChildSize: 0.45,
  //           maxChildSize: 0.95,
  //           builder: (context, scrollController) {
  //             return SingleChildScrollView(
  //               controller: scrollController,
  //               padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   if (alert.newsImage.trim().isNotEmpty)
  //                     ClipRRect(
  //                       borderRadius: BorderRadius.circular(16),
  //                       child: AspectRatio(
  //                         aspectRatio: 3 / 2,
  //                         child: Image.network(
  //                           alert.newsImage.trim(),
  //                           width: double.infinity,
  //                           fit: BoxFit.cover,
  //                           errorBuilder: (context, error, stackTrace) {
  //                             return ColoredBox(
  //                               color: colors.surfaceContainerHighest,
  //                               child: Center(
  //                                 child: Icon(
  //                                   Icons.broken_image_outlined,
  //                                   size: 48,
  //                                   color: colors.onSurfaceVariant,
  //                                 ),
  //                               ),
  //                             );
  //                           },
  //                         ),
  //                       ),
  //                     ),
  //                   if (alert.newsImage.trim().isNotEmpty)
  //                     const SizedBox(height: 20),
  //                   Text(
  //                     alert.title,
  //                     style: theme.textTheme.titleLarge?.copyWith(
  //                       color: colors.onSurface,
  //                       fontWeight: FontWeight.bold,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 10),
  //                   Row(
  //                     children: [
  //                       Icon(
  //                         Icons.schedule_outlined,
  //                         size: 17,
  //                         color: colors.onSurfaceVariant,
  //                       ),
  //                       const SizedBox(width: 6),
  //                       Text(
  //                         _formatDateTime(alert.publishDate),
  //                         style: theme.textTheme.bodySmall?.copyWith(
  //                           color: colors.onSurfaceVariant,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                   const SizedBox(height: 18),
  //                   Text(
  //                     alert.content,
  //                     style: theme.textTheme.bodyLarge?.copyWith(
  //                       color: colors.onSurface,
  //                       height: 1.6,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             );
  //           },
  //         ),
  //       );
  //     },
  //   );
  // }

  // String _formatDateTime(DateTime date) {
  //   final localDate = date.toLocal();

  //   final day = localDate.day.toString().padLeft(2, '0');
  //   final month = localDate.month.toString().padLeft(2, '0');
  //   final hour = localDate.hour.toString().padLeft(2, '0');
  //   final minute = localDate.minute.toString().padLeft(2, '0');

  //   return '$day/$month/${localDate.year} เวลา $hour:$minute น.';
  // }
}

class _NewsLoadingState extends StatelessWidget {
  const _NewsLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: 16),
          Text(
            'กำลังโหลดข่าวสาร...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNewsState extends StatelessWidget {
  const _EmptyNewsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.article_outlined,
              size: 56,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              'ยังไม่มีข่าวสารในขณะนี้',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsErrorState extends StatelessWidget {
  const _NewsErrorState({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    String message = 'ไม่สามารถโหลดข่าวสารได้ กรุณาลองใหม่อีกครั้ง';

    if (error is FirebaseException) {
      final firebaseError = error as FirebaseException;

      switch (firebaseError.code) {
        case 'permission-denied':
          message = 'ไม่มีสิทธิ์อ่านข้อมูลข่าวสารจากระบบ';
          break;

        case 'unavailable':
          message = 'ไม่สามารถเชื่อมต่อ Firestore ได้ในขณะนี้';
          break;

        case 'failed-precondition':
          message = 'ระบบข่าวสารยังตั้งค่าไม่สมบูรณ์';
          break;

        default:
          message = 'ไม่สามารถโหลดข่าวสารได้ กรุณาลองใหม่อีกครั้ง';
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 54, color: colors.error),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
