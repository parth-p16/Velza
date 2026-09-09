import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velza/models/chat_model.dart';
import 'package:velza/models/message_model.dart';
import 'package:velza/models/sticker_model.dart';
import 'package:velza/services/wallpaper_service.dart';
import 'package:velza/services/database_service.dart';
import 'package:velza/viewmodels/chat_viewmodel.dart';
import 'package:velza/viewmodels/settings_viewmodel.dart';
import 'package:velza/views/widgets/wallpaper_background.dart';
import 'package:velza/views/widgets/swipe_to_reply.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 1: WhatsApp-Style Swipe-to-Reply', () {
    testWidgets('SwipeToReply invokes onReply when dragged beyond threshold', (tester) async {
      bool replied = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SwipeToReply(
                onReply: () {
                  replied = true;
                },
                child: Container(
                  width: 250,
                  height: 60,
                  color: Colors.purple,
                  child: const Text('Swipe this message'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(replied, isFalse);

      // Perform horizontal drag to the right (> 50px threshold)
      await tester.drag(find.text('Swipe this message'), const Offset(80, 0));
      await tester.pumpAndSettle();

      expect(replied, isTrue);
    });

    testWidgets('SwipeToReply does NOT invoke onReply on small drag', (tester) async {
      bool replied = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SwipeToReply(
                onReply: () {
                  replied = true;
                },
                child: Container(
                  width: 250,
                  height: 60,
                  color: Colors.purple,
                  child: const Text('Subtle drag'),
                ),
              ),
            ),
          ),
        ),
      );

      // Drag below 50px threshold
      await tester.drag(find.text('Subtle drag'), const Offset(20, 0));
      await tester.pumpAndSettle();

      expect(replied, isFalse);
    });
  });

  group('Feature 2: Font Size and Font Style Settings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('SettingsViewModel updates and persists font sizes', () async {
      final settingsVM = SettingsViewModel();

      expect(settingsVM.chatFontSize, ChatFontSize.medium);
      expect(settingsVM.chatFontSizeValue, 15.0);

      await settingsVM.updateChatFontSize(ChatFontSize.large);
      expect(settingsVM.chatFontSize, ChatFontSize.large);
      expect(settingsVM.chatFontSizeValue, 17.0);

      await settingsVM.updateChatFontSize(ChatFontSize.extraLarge);
      expect(settingsVM.chatFontSize, ChatFontSize.extraLarge);
      expect(settingsVM.chatFontSizeValue, 19.0);

      await settingsVM.updateChatFontSize(ChatFontSize.small);
      expect(settingsVM.chatFontSize, ChatFontSize.small);
      expect(settingsVM.chatFontSizeValue, 13.0);

      // Verify persistence in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('chat_font_size'), 'small');
    });

    test('SettingsViewModel updates and persists font styles', () async {
      final settingsVM = SettingsViewModel();

      expect(settingsVM.chatFontStyle, ChatFontStyle.defaultFont);
      expect(settingsVM.chatFontFamily, isNull);

      await settingsVM.updateChatFontStyle(ChatFontStyle.modernSans);
      expect(settingsVM.chatFontStyle, ChatFontStyle.modernSans);
      expect(settingsVM.chatFontFamily, 'sans-serif');

      await settingsVM.updateChatFontStyle(ChatFontStyle.luxuryOutfit);
      expect(settingsVM.chatFontStyle, ChatFontStyle.luxuryOutfit);
      expect(settingsVM.chatFontFamily, 'Outfit');

      await settingsVM.updateChatFontStyle(ChatFontStyle.monospace);
      expect(settingsVM.chatFontStyle, ChatFontStyle.monospace);
      expect(settingsVM.chatFontFamily, 'monospace');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('chat_font_style'), 'monospace');
    });
  });

  group('Feature 3: Shared Conversation Wallpaper / Theme', () {
    test('ChatModel handles wallpaperId with fallback default', () {
      final chatDefault = ChatModel.fromMap({
        'id': 'chat_123',
        'name': 'VIP Club',
        'isGroup': false,
        'memberIds': ['u1', 'u2'],
      });

      expect(chatDefault.wallpaperId, 'velza_default');

      final chatCustom = ChatModel.fromMap({
        'id': 'chat_456',
        'name': 'VIP Club',
        'isGroup': false,
        'memberIds': ['u1', 'u2'],
        'wallpaperId': 'royal_velvet',
      });

      expect(chatCustom.wallpaperId, 'royal_velvet');

      final serialized = chatCustom.toMap();
      expect(serialized['wallpaperId'], 'royal_velvet');

      final copied = chatCustom.copyWith(wallpaperId: 'golden_mesh');
      expect(copied.wallpaperId, 'golden_mesh');
      expect(copied.id, 'chat_456');
    });

    testWidgets('WallpaperBackgroundWidget displays wallpaper cleanly', (tester) async {
      final wallpaper = WallpaperService.getPresetById('velza_default');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WallpaperBackgroundWidget(
              wallpaper: wallpaper,
              child: const Text('Shared Theme Test'),
            ),
          ),
        ),
      );

      expect(find.text('Shared Theme Test'), findsOneWidget);
    });
  });

  group('Feature 4: Mutual Nickname Visibility', () {
    test('Mutual nicknames model maintains separate owner & target nicknames', () {
      const mutual = MutualNicknameInfo(
        nicknameGivenByMe: 'Bestie',
        nicknameGivenToMe: 'Bhai',
      );

      expect(mutual.nicknameGivenByMe, 'Bestie');
      expect(mutual.nicknameGivenToMe, 'Bhai');
    });

    test('ChatViewModel private nickname isolation & fallback to original name', () {
      final chatVMA = ChatViewModel();
      final chatVMB = ChatViewModel();

      const userAUid = 'user_a';
      const userBUid = 'user_b';

      chatVMA.updateNicknamesCacheForTest({userBUid: 'Bestie'});
      chatVMB.updateNicknamesCacheForTest({userAUid: 'Bhai'});

      // User A sees User B as "Bestie", falls back to "Bob" if cleared
      expect(chatVMA.getEffectiveName(userBUid, 'Bob'), 'Bestie');
      expect(chatVMA.getEffectiveName('unknown_user', 'Charlie'), 'Charlie');

      // User B sees User A as "Bhai"
      expect(chatVMB.getEffectiveName(userAUid, 'Alice'), 'Bhai');
    });
  });

  group('Feature 5: Stickers Pack and Message Serialization', () {
    test('StickerService provides 12 luxury starter stickers across categories', () {
      const stickers = StickerService.starterStickers;
      expect(stickers.length, 12);

      final categories = stickers.map((s) => s.category).toSet();
      expect(categories.contains('Love'), isTrue);
      expect(categories.contains('Vibes'), isTrue);
      expect(categories.contains('Mood'), isTrue);
      expect(categories.contains('Gestures'), isTrue);
    });

    test('MessageModel supports MessageType.sticker and stickerId serialization', () {
      final now = DateTime.now();
      final stickerMsg = MessageModel(
        id: 'msg_sticker_1',
        senderId: 'u1',
        senderName: 'Alice',
        chatId: 'chat_1',
        text: '🏷️ Sticker',
        type: MessageType.sticker,
        url: '',
        fileName: '',
        audioDuration: 0,
        timestamp: now,
        readBy: ['u1'],
        stickerId: 'velza_crown_gold',
      );

      final map = stickerMsg.toMap();
      expect(map['type'], 'sticker');
      expect(map['stickerId'], 'velza_crown_gold');

      final deserialized = MessageModel.fromMap(map);
      expect(deserialized.type, MessageType.sticker);
      expect(deserialized.stickerId, 'velza_crown_gold');
    });
  });

  group('Feature 6: Emoji Reactions Logic', () {
    test('MessageModel serializes and deserializes reactions map', () {
      final now = DateTime.now();
      final msg = MessageModel(
        id: 'msg_react_1',
        senderId: 'u1',
        senderName: 'Alice',
        chatId: 'chat_1',
        text: 'Look at this!',
        type: MessageType.text,
        url: '',
        fileName: '',
        audioDuration: 0,
        timestamp: now,
        readBy: ['u1'],
        reactions: const {
          'user_a': '❤️',
          'user_b': '👍',
        },
      );

      final map = msg.toMap();
      expect(map['reactions'], isA<Map>());
      expect(map['reactions']['user_a'], '❤️');
      expect(map['reactions']['user_b'], '👍');

      final deserialized = MessageModel.fromMap(map);
      expect(deserialized.reactions.length, 2);
      expect(deserialized.reactions['user_a'], '❤️');
      expect(deserialized.reactions['user_b'], '👍');
    });

    test('Emoji reaction toggling logic: add, replace, and remove', () {
      Map<String, String> reactions = {};

      // 1. User A reacts with ❤️
      const userA = 'user_a';
      if (reactions[userA] == '❤️') {
        reactions.remove(userA);
      } else {
        reactions[userA] = '❤️';
      }
      expect(reactions[userA], '❤️');

      // 2. User A changes reaction from ❤️ to 😂 (replace)
      if (reactions[userA] == '😂') {
        reactions.remove(userA);
      } else {
        reactions[userA] = '😂';
      }
      expect(reactions[userA], '😂');

      // 3. User A taps 😂 again (toggle off / remove)
      if (reactions[userA] == '😂') {
        reactions.remove(userA);
      } else {
        reactions[userA] = '😂';
      }
      expect(reactions.containsKey(userA), isFalse);
    });
  });
}
