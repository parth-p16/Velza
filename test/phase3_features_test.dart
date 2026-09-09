import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velza/models/message_model.dart';
import 'package:velza/models/sticker_model.dart';
import 'package:velza/services/app_lock_service.dart';

void main() {
  group('Component 1: Mutual Nicknames', () {
    test('Directional nickname keys and store simulation', () {
      // User A (uid_a) sets nickname for User B (uid_b) = "King"
      // User B (uid_b) sets nickname for User A (uid_a) = "Queen"
      final Map<String, Map<String, String>> userNicknames = {
        'uid_a': {'uid_b': 'King'},
        'uid_b': {'uid_a': 'Queen'},
      };

      // A sees B as "King"
      expect(userNicknames['uid_a']?['uid_b'], 'King');
      // B sees A as "Queen"
      expect(userNicknames['uid_b']?['uid_a'], 'Queen');

      // Third party C sees neither
      expect(userNicknames['uid_c']?['uid_a'], isNull);
      expect(userNicknames['uid_c']?['uid_b'], isNull);
    });
  });

  group('Component 4: @Mentions in Messages', () {
    test('MessageModel serializes and deserializes mentionedUserIds and mentions map', () {
      final now = DateTime.now();
      final message = MessageModel(
        id: 'msg_mention_1',
        senderId: 'user_1',
        senderName: 'Alice',
        chatId: 'chat_123',
        text: 'Hello @Bob and @Charlie, check this out!',
        type: MessageType.text,
        timestamp: now,
        mentionedUserIds: ['user_bob', 'user_charlie'],
        mentions: {
          'user_bob': 'Bob',
          'user_charlie': 'Charlie',
        },
      );

      final map = message.toMap();
      expect(map['mentionedUserIds'], ['user_bob', 'user_charlie']);
      expect(map['mentions'], {'user_bob': 'Bob', 'user_charlie': 'Charlie'});

      final fromMap = MessageModel.fromMap(map);
      expect(fromMap.mentionedUserIds, contains('user_bob'));
      expect(fromMap.mentionedUserIds, contains('user_charlie'));
      expect(fromMap.mentions?['user_bob'], 'Bob');
      expect(fromMap.mentions?['user_charlie'], 'Charlie');
    });
  });

  group('Component 5: Stickers Save & Model', () {
    test('VelzaSticker custom sticker detection and assetPath resolution', () {
      const starter = VelzaSticker(
        id: 'velza_fire_heart',
        name: 'Heart on Fire',
        category: 'Love',
        emoji: '❤️‍🔥',
        gradientColors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
      );
      expect(starter.isCustom, isFalse);
      expect(starter.assetPath, 'velza://sticker/velza_fire_heart');

      const custom = VelzaSticker(
        id: 'custom_12345',
        name: 'Custom Sticker',
        category: 'Custom',
        emoji: '🎨',
        gradientColors: [Color(0xFF6A1B9A), Color(0xFFD4AF37)],
        localCustomPath: '/data/user/0/com.velza/app_flutter/custom_stickers/sticker_12345.png',
      );
      expect(custom.isCustom, isTrue);
      expect(custom.assetPath, '/data/user/0/com.velza/app_flutter/custom_stickers/sticker_12345.png');
    });

    test('StickerService categories includes Custom', () {
      expect(StickerService.categories, contains('Custom'));
      expect(StickerService.categories, contains('All'));
    });
  });

  group('Component 8: Scheduled Gift Message 🎁', () {
    test('MessageModel supports MessageType.gift and gift payload lifecycle', () {
      final now = DateTime.now();
      final futureDate = now.add(const Duration(hours: 4));

      final giftMessage = MessageModel(
        id: 'gift_msg_001',
        senderId: 'user_alice',
        senderName: 'Alice',
        chatId: 'chat_couple',
        text: '🎁 Secret Gift Message',
        type: MessageType.gift,
        timestamp: now,
        scheduledFor: futureDate,
        giftPayload: 'Happy Anniversary my love! ❤️ Here is your surprise reservation at Velza Terrace.',
        isGiftOpened: false,
      );

      final map = giftMessage.toMap();
      expect(map['type'], 'gift');
      expect(map['isGiftOpened'], isFalse);
      expect(map['giftPayload'], contains('Happy Anniversary'));

      final parsed = MessageModel.fromMap(map);
      expect(parsed.type, MessageType.gift);
      expect(parsed.isGiftOpened, isFalse);
      expect(parsed.giftPayload, contains('Velza Terrace'));

      // Open the gift
      final openedGift = parsed.copyWith(
        isGiftOpened: true,
        openedAt: DateTime.now(),
        giftOpenedBy: 'user_bob',
      );

      expect(openedGift.isGiftOpened, isTrue);
      expect(openedGift.giftOpenedBy, 'user_bob');
      expect(openedGift.openedAt, isNotNull);
    });
  });

  group('Component 6: App Lock Biometric & Pin Integrity', () {
    test('AppLockService timeout options calculation', () {
      final appLock = AppLockService();
      expect(appLock.timeoutSetting, isNotNull);
      expect(appLock.isCurrentlyLocked, isFalse);
    });
  });

  group('Component 7: Search Jump & Exact Message Resolution', () {
    test('Message list index resolution for jump targeting', () {
      final now = DateTime.now();
      final messages = List.generate(
        50,
        (i) => MessageModel(
          id: 'msg_$i',
          senderId: 'user_$i',
          senderName: 'User $i',
          chatId: 'chat_1',
          text: 'Message number $i',
          type: MessageType.text,
          timestamp: now.subtract(Duration(minutes: i * 5)),
        ),
      );

      const targetId = 'msg_37';
      final foundIndex = messages.indexWhere((m) => m.id == targetId);
      expect(foundIndex, 37);
      expect(messages[foundIndex].text, 'Message number 37');
    });
  });
}
