import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/auth/auth_session_controller.dart';
import 'core/cache/cache_manager.dart';
import 'core/lifecycle/app_lifecycle.dart';
import 'core/routing/last_page_store.dart';
import 'core/storage/storage_manager.dart';
import 'data/models/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final appLifecycle = AppLifecycle(
    cacheManager: const CacheManager(),
    storageManager: const StorageManager(),
  );

  WidgetsBinding.instance.addObserver(appLifecycle);

  final authController = AuthSessionController();
  await authController.restoreSession();

  final lastPageStore = LastPageStore();
  final savedLocation = await lastPageStore.load();
  final initialLocation = RestorablePagePolicy.initialLocation(
    savedLocation: savedLocation,
    hasRescueSession: authController.isRescueTeam || authController.isAdmin,
  );

  runApp(
    ResQApp(
      authController: authController,
      lastPageStore: lastPageStore,
      initialLocation: initialLocation,
    ),
  );
}
