import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:res_q/core/routing/app_routes.dart';
import 'package:res_q/core/routing/last_page_store.dart';

void main() {
  group('RestorablePagePolicy', () {
    test('keeps known pages and strips transient query parameters', () {
      expect(
        RestorablePagePolicy.normalize('/emergency-tracking/request-1?tab=map'),
        '/emergency-tracking/request-1',
      );
      expect(RestorablePagePolicy.normalize('/news/news-1'), '/news/news-1');
      expect(RestorablePagePolicy.normalize('/profile'), AppRoutePaths.profile);
      expect(RestorablePagePolicy.normalize('/unknown'), isNull);
      expect(
        RestorablePagePolicy.normalize('https://example.com/news/news-1'),
        isNull,
      );
    });

    test('restores rescue pages only with a rescue session', () {
      expect(
        RestorablePagePolicy.initialLocation(
          savedLocation: AppRoutePaths.rescueMissionHistory,
          hasRescueSession: true,
        ),
        AppRoutePaths.rescueMissionHistory,
      );
      expect(
        RestorablePagePolicy.initialLocation(
          savedLocation: AppRoutePaths.rescueHome,
          hasRescueSession: false,
        ),
        AppRoutePaths.rescueLogin,
      );
      expect(
        RestorablePagePolicy.initialLocation(
          savedLocation: AppRoutePaths.news,
          hasRescueSession: true,
        ),
        AppRoutePaths.rescueHome,
      );
    });

    test('restores a citizen page without a rescue session', () {
      expect(
        RestorablePagePolicy.initialLocation(
          savedLocation: AppRoutePaths.sos,
          hasRescueSession: false,
        ),
        AppRoutePaths.sos,
      );
      expect(
        RestorablePagePolicy.initialLocation(
          savedLocation: null,
          hasRescueSession: false,
        ),
        AppRoutePaths.home,
      );
    });
  });

  testWidgets('route provider publishes navigation to a new page', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutePaths.home,
      routes: [
        GoRoute(
          path: AppRoutePaths.home,
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: AppRoutePaths.news,
          builder: (_, _) => const Scaffold(body: Text('News')),
        ),
      ],
    );
    addTearDown(router.dispose);

    final observedLocations = <String>[];
    router.routeInformationProvider.addListener(() {
      observedLocations.add(router.routeInformationProvider.value.uri.path);
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go(AppRoutePaths.news);
    await tester.pumpAndSettle();

    expect(observedLocations, contains(AppRoutePaths.news));
    expect(find.text('News'), findsOneWidget);
  });
}
