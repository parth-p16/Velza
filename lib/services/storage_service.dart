import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  FirebaseStorage get _storage => FirebaseStorage.instance;

  // Upload user profile photo
  Future<String> uploadProfilePhoto(String userId, File file) async {
    try {
      final Reference ref = _storage.ref().child('profiles').child('$userId.jpg');
      final UploadTask task = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final TaskSnapshot snap = await task;
      return await snap.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  // Upload chat media attachment (image, video, document, voice note) with progress callback
  Future<String> uploadChatMedia({
    required String chatId,
    required String messageId,
    required File file,
    required String fileExtension,
    required String type, // 'images', 'videos', 'documents', 'voice'
    void Function(double progress)? onProgress,
  }) async {
    try {
      final Reference ref = _storage
          .ref()
          .child('chats')
          .child(chatId)
          .child(type)
          .child('$messageId.$fileExtension');

      String? contentType;
      final ext = fileExtension.toLowerCase();
      if (ext == 'jpg' || ext == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (ext == 'png') {
        contentType = 'image/png';
      } else if (ext == 'mp4') {
        contentType = 'video/mp4';
      } else if (ext == 'm4a' || ext == 'aac') {
        contentType = 'audio/mp4';
      } else if (ext == 'pdf') {
        contentType = 'application/pdf';
      }

      final UploadTask task = ref.putFile(
        file,
        SettableMetadata(contentType: contentType),
      );

      if (onProgress != null) {
        task.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
          }
        });
      }

      final TaskSnapshot snap = await task;
      return await snap.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  // Upload shared chat wallpaper photo to Firebase Storage
  Future<String> uploadChatWallpaper({
    required String chatId,
    required File file,
  }) async {
    try {
      final fileName = 'wallpaper_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage
          .ref()
          .child('chats')
          .child(chatId)
          .child('wallpaper')
          .child(fileName);

      final UploadTask task = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final TaskSnapshot snap = await task;
      return await snap.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }
}
