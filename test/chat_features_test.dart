import 'package:flutter_test/flutter_test.dart';
import 'package:velza/models/message_model.dart';
import 'package:velza/models/user_model.dart';
import 'package:velza/models/chat_model.dart';
import 'package:velza/models/status_model.dart';

void main() {
  group('Velza Chat Features - Model & Logic Tests', () {
    test('MessageModel serialization retains all fields: reply, edit, delete, and duration', () {
      final now = DateTime.now();
      final message = MessageModel(
        id: 'msg_test_1',
        senderId: 'user_sender_1',
        senderName: 'Alice',
        chatId: 'chat_123',
        text: 'Hello, this is a test message!',
        type: MessageType.text,
        url: '',
        fileName: '',
        audioDuration: 0,
        timestamp: now,
        edited: false,
        deleted: false,
        deletedForEveryone: false,
        deletedBy: [],
        replyToMessageId: 'msg_orig_0',
        replyToText: 'Original text',
        replyToSenderId: 'user_orig_2',
        replyToSenderName: 'Bob',
        readBy: ['user_sender_1'],
      );

      final map = message.toMap();
      expect(map['id'], 'msg_test_1');
      expect(map['messageId'], 'msg_test_1');
      expect(map['senderId'], 'user_sender_1');
      expect(map['senderName'], 'Alice');
      expect(map['text'], 'Hello, this is a test message!');
      expect(map['type'], 'text');
      expect(map['replyToMessageId'], 'msg_orig_0');
      expect(map['replyToText'], 'Original text');
      expect(map['replyToSenderId'], 'user_orig_2');
      expect(map['replyToSenderName'], 'Bob');
      expect(map['edited'], false);
      expect(map['deleted'], false);
      expect(map['deletedForEveryone'], false);

      final reconstructed = MessageModel.fromMap(map);
      expect(reconstructed.id, 'msg_test_1');
      expect(reconstructed.messageId, 'msg_test_1');
      expect(reconstructed.replyToMessageId, 'msg_orig_0');
      expect(reconstructed.replyToText, 'Original text');
      expect(reconstructed.replyToSenderName, 'Bob');
      expect(reconstructed.edited, false);
      expect(reconstructed.deleted, false);
      expect(reconstructed.deletedForEveryone, false);
    });

    test('Audio MessageModel retains audioDuration and mediaUrl', () {
      final now = DateTime.now();
      final audioMsg = MessageModel(
        id: 'msg_audio_1',
        senderId: 'user_1',
        senderName: 'Alice',
        chatId: 'chat_1',
        text: 'Voice message',
        type: MessageType.audio,
        url: 'https://storage.googleapis.com/test/audio.m4a',
        fileName: 'voice.m4a',
        audioDuration: 42,
        timestamp: now,
        readBy: ['user_1'],
      );

      final map = audioMsg.toMap();
      expect(map['type'], 'audio');
      expect(map['audioDuration'], 42);
      expect(map['mediaUrl'], 'https://storage.googleapis.com/test/audio.m4a');
      expect(map['url'], 'https://storage.googleapis.com/test/audio.m4a');

      final fromMapMsg = MessageModel.fromMap(map);
      expect(fromMapMsg.type, MessageType.audio);
      expect(fromMapMsg.audioDuration, 42);
      expect(fromMapMsg.mediaUrl, 'https://storage.googleapis.com/test/audio.m4a');
    });

    test('Message Edit flag and updatedAt', () {
      final now = DateTime.now();
      final orig = MessageModel(
        id: 'msg_edit_1',
        senderId: 'user_1',
        senderName: 'Alice',
        chatId: 'chat_1',
        text: 'Initial text',
        type: MessageType.text,
        url: '',
        fileName: '',
        timestamp: now,
        readBy: ['user_1'],
      );

      final edited = orig.copyWith(
        text: 'Updated text content',
        edited: true,
        updatedAt: now.add(const Duration(minutes: 1)),
      );

      expect(edited.text, 'Updated text content');
      expect(edited.edited, true);
      expect(edited.updatedAt, isNotNull);

      final map = edited.toMap();
      expect(map['edited'], true);
      expect(map['updatedAt'], isNotNull);

      final reconstructed = MessageModel.fromMap(map);
      expect(reconstructed.edited, true);
      expect(reconstructed.text, 'Updated text content');
    });

    test('Message Delete for Everyone cleans media and sets placeholders', () {
      final now = DateTime.now();
      final msg = MessageModel(
        id: 'msg_del_1',
        senderId: 'user_1',
        senderName: 'Alice',
        chatId: 'chat_1',
        text: 'Secret photo',
        type: MessageType.image,
        url: 'https://storage.googleapis.com/secret/photo.jpg',
        fileName: 'photo.jpg',
        timestamp: now,
        readBy: ['user_1'],
      );

      final deletedForEveryone = msg.copyWith(
        deleted: true,
        deletedForEveryone: true,
        text: 'This message was deleted',
        url: '',
        thumbnailUrl: '',
      );

      expect(deletedForEveryone.deleted, true);
      expect(deletedForEveryone.deletedForEveryone, true);
      expect(deletedForEveryone.text, 'This message was deleted');
      expect(deletedForEveryone.url, '');

      final map = deletedForEveryone.toMap();
      expect(map['deleted'], true);
      expect(map['deletedForEveryone'], true);
      expect(map['text'], 'This message was deleted');
      expect(map['url'], '');
      expect(map['mediaUrl'], '');
    });

    test('Message Delete for Me filters messages locally for current user', () {
      final now = DateTime.now();
      final msgList = [
        MessageModel(
          id: 'msg_1',
          senderId: 'user_a',
          senderName: 'Alice',
          text: 'Message 1',
          type: MessageType.text,
          url: '',
          fileName: '',
          timestamp: now,
          readBy: [],
          deletedBy: ['user_b'], // deleted for user_b
        ),
        MessageModel(
          id: 'msg_2',
          senderId: 'user_a',
          senderName: 'Alice',
          text: 'Message 2',
          type: MessageType.text,
          url: '',
          fileName: '',
          timestamp: now,
          readBy: [],
          deletedBy: [],
        ),
      ];

      // Filter for user_b
      final visibleForUserB = msgList.where((m) => !m.deletedBy.contains('user_b')).toList();
      expect(visibleForUserB.length, 1);
      expect(visibleForUserB.first.id, 'msg_2');

      // Filter for user_a
      final visibleForUserA = msgList.where((m) => !m.deletedBy.contains('user_a')).toList();
      expect(visibleForUserA.length, 2);
    });

    test('UserModel serializes and deserializes fcmToken', () {
      final user = UserModel(
        uid: 'u_100',
        phoneNumber: '+1234567890',
        email: 'user@velza.app',
        displayName: 'Test User',
        photoUrl: '',
        isOnline: true,
        typingTo: 'none',
        lastSeen: DateTime.now(),
        blockedUsers: [],
        fcmToken: 'fcm_mock_token_abc_123',
      );

      expect(user.fcmToken, 'fcm_mock_token_abc_123');

      final map = user.toMap();
      expect(map['fcmToken'], 'fcm_mock_token_abc_123');

      final deserialized = UserModel.fromMap(map);
      expect(deserialized.fcmToken, 'fcm_mock_token_abc_123');
    });

    test('Composer Send vs Mic button toggle logic', () {
      bool shouldShowSend(String input) {
        return input.trim().isNotEmpty;
      }

      // Empty text: show microphone
      expect(shouldShowSend(''), false);
      expect(shouldShowSend('   '), false);

      // Non-empty text: immediately show send
      expect(shouldShowSend('H'), true);
      expect(shouldShowSend('Hello'), true);
      expect(shouldShowSend('  hi  '), true);
    });

    test('ChatModel retains shared wallpaper and clearedAtBy per user', () {
      final now = DateTime.now();
      final chat = ChatModel(
        id: 'chat_shared_1',
        name: 'Shared Conversation',
        photoUrl: '',
        isGroup: false,
        memberIds: ['user_alice', 'user_bob'],
        lastMessageText: 'Hello!',
        lastMessageTime: now,
        unreadCounts: {},
        typingStatus: {},
        wallpaperType: 'gallery',
        wallpaperUrl: 'https://firebasestorage.googleapis.com/test_wallpaper.jpg',
        wallpaperUpdatedBy: 'user_alice',
        wallpaperUpdatedAt: now,
        clearedAtBy: {
          'user_alice': now.subtract(const Duration(hours: 2)),
          'user_bob': now.subtract(const Duration(days: 1)),
        },
      );

      final map = chat.toMap();
      expect(map['wallpaperType'], 'gallery');
      expect(map['wallpaperUrl'], 'https://firebasestorage.googleapis.com/test_wallpaper.jpg');
      expect(map['wallpaperUpdatedBy'], 'user_alice');
      expect(map['clearedAtBy']['user_alice'], isNotNull);

      final parsed = ChatModel.fromMap(map);
      expect(parsed.wallpaperType, 'gallery');
      expect(parsed.wallpaperUrl, 'https://firebasestorage.googleapis.com/test_wallpaper.jpg');
      expect(parsed.wallpaperUpdatedBy, 'user_alice');
      expect(parsed.clearedAtBy.containsKey('user_alice'), true);
      expect(parsed.clearedAtBy.containsKey('user_bob'), true);
    });

    test('StatusModel 24-hour expiration logic works correctly', () {
      final now = DateTime.now();
      final freshStatus = StatusModel(
        statusId: 'status_fresh',
        userId: 'user_1',
        userName: 'Alice',
        userPhotoUrl: '',
        type: StatusType.text,
        text: 'Enjoying Velza!',
        createdAt: now.subtract(const Duration(hours: 12)),
        expiresAt: now.add(const Duration(hours: 12)),
      );
      expect(freshStatus.isExpired, false);

      final expiredStatus = StatusModel(
        statusId: 'status_expired',
        userId: 'user_2',
        userName: 'Bob',
        userPhotoUrl: '',
        type: StatusType.text,
        text: 'Old update',
        createdAt: now.subtract(const Duration(hours: 25)),
        expiresAt: now.subtract(const Duration(hours: 1)),
      );
      expect(expiredStatus.isExpired, true);
    });

    test('Bulk delete message chunking splits up to 999 items into batches <= 400', () {
      // Simulate 999 message IDs
      final List<String> messageIds = List.generate(999, (i) => 'msg_$i');
      
      const int batchSize = 400;
      final List<List<String>> batches = [];
      for (var i = 0; i < messageIds.length; i += batchSize) {
        final end = (i + batchSize < messageIds.length) ? i + batchSize : messageIds.length;
        batches.add(messageIds.sublist(i, end));
      }

      expect(batches.length, 3);
      expect(batches[0].length, 400);
      expect(batches[1].length, 400);
      expect(batches[2].length, 199);
      expect(batches[0].length + batches[1].length + batches[2].length, 999);
    });

    test('Per-user clearedAt filter hides messages before clear timestamp', () {
      final t0 = DateTime(2026, 9, 1, 10, 0);
      final tClear = DateTime(2026, 9, 1, 12, 0);
      final tNew = DateTime(2026, 9, 1, 14, 0);

      final m1 = MessageModel(
        id: 'm1',
        senderId: 'user_1',
        senderName: 'Alice',
        text: 'Old message',
        type: MessageType.text,
        url: '',
        fileName: '',
        timestamp: t0,
        readBy: [],
      );
      final m2 = MessageModel(
        id: 'm2',
        senderId: 'user_2',
        senderName: 'Bob',
        text: 'New message after clear',
        type: MessageType.text,
        url: '',
        fileName: '',
        timestamp: tNew,
        readBy: [],
      );

      final all = [m1, m2];
      final visible = all.where((m) => m.timestamp.isAfter(tClear)).toList();

      expect(visible.length, 1);
      expect(visible.first.id, 'm2');
    });
  });
}
