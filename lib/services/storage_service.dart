import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadFile({
    required File file,
    required String path,
    SettableMetadata? metadata,
  }) async {
    final ref = _storage.ref().child(path);
    final task = ref.putFile(file, metadata);
    final snapshot = await task;
    return snapshot.ref.getDownloadURL();
  }
}
