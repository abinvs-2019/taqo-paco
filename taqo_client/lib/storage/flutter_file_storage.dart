import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'local_file_storage.dart';

class FlutterFileStorage implements ILocalFileStorage {
  final _localFileName;

  Future<Directory> get localStorageDir async {
    try {
      return await getApplicationSupportDirectory();
    } catch (e) {
      // Workaround to support file storage during tests
      return Directory.systemTemp;
    }
  }

  Future<String> get localPath async => (await localStorageDir).path;

  Future<File> get localFile async => File(path.join(await localPath, _localFileName));

  FlutterFileStorage(this._localFileName);

  Future clear() async {
    final file = await localFile;
    if (await file.exists()) {
      await file.delete();
    }
  }
}
