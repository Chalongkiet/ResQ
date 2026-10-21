// import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CacheManager {
  const CacheManager();

  Future<void> clearTemporaryFiles() async {
    final tempDir = await getTemporaryDirectory();

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
      await tempDir.create();
    }
  }
}
