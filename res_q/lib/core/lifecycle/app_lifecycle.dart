import 'package:flutter/widgets.dart';
import '../cache/cache_manager.dart';
import '../storage/storage_manager.dart';

class AppLifecycle extends WidgetsBindingObserver {
  final CacheManager cacheManager;
  final StorageManager storageManager;

  AppLifecycle({required this.cacheManager, required this.storageManager});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _handleAppClosing();
    }
  }

  Future<void> _handleAppClosing() async {
    await storageManager.saveBeforeAppClosed();
    await cacheManager.clearTemporaryFiles();
  }
}
