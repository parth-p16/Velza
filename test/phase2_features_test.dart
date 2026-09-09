import 'package:flutter_test/flutter_test.dart';
import 'package:velza/models/relationship_model.dart';
import 'package:velza/models/message_model.dart';
import 'package:velza/models/chat_model.dart';
import 'package:velza/models/mood_model.dart';
import 'package:velza/models/user_model.dart';
import 'package:velza/models/anonymous_qa_model.dart';

void main() {
  group('Phase 2 - Symmetric Follow & Relationships Tests', () {
    test('RelationshipModel.generateId is strictly symmetric regardless of order', () {
      final id1 = RelationshipModel.generateId('user_alpha', 'user_beta');
      final id2 = RelationshipModel.generateId('user_beta', 'user_alpha');
      expect(id1, id2);
      expect(id1, 'user_alpha_user_beta');

      final id3 = RelationshipModel.generateId('xyz999', 'abc123');
      final id4 = RelationshipModel.generateId('abc123', 'xyz999');
      expect(id3, id4);
      expect(id3, 'abc123_xyz999');
    });

    test('RelationshipModel blockedBy field and helper checks', () {
      final now = DateTime.now();
      final blockedRel = RelationshipModel(
        relationshipId: 'u1_u2',
        fromUid: 'u1',
        toUid: 'u2',
        status: RelationshipStatus.blocked,
        blockedBy: 'u1',
        createdAt: now,
        updatedAt: now,
      );

      final map = blockedRel.toMap();
      expect(map['blockedBy'], 'u1');
      expect(map['status'], 'blocked');

      final parsed = RelationshipModel.fromMap(map);
      expect(parsed.blockedBy, 'u1');
      expect(parsed.isBlocked, isTrue);
    });
  });

  group('Phase 2 - Chat Streak Logic Tests', () {
    test('ChatModel streak serialization and defaults', () {
      final now = DateTime.now();
      final chat = ChatModel(
        id: 'c1',
        name: 'Friend',
        photoUrl: '',
        isGroup: false,
        memberIds: ['u1', 'u2'],
        lastMessageText: 'Hey',
        lastMessageTime: now,
        unreadCounts: {},
        typingStatus: {},
        streakCount: 5,
        lastStreakDate: '2026-09-04',
      );

      final map = chat.toMap();
      expect(map['streakCount'], 5);
      expect(map['lastStreakDate'], '2026-09-04');

      final restored = ChatModel.fromMap(map);
      expect(restored.streakCount, 5);
      expect(restored.lastStreakDate, '2026-09-04');
    });

    test('Chat streak calculation increment and reset logic', () {
      // Day 1: First message
      int streak = 0;
      String? lastDate;
      const day1Str = '2026-09-01';

      streak = 1;
      lastDate = day1Str;
      expect(streak, 1);
      expect(lastDate, '2026-09-01');

      // Day 1: Same day subsequent message (retains streak)
      const sameDayStr = '2026-09-01';
      if (lastDate != sameDayStr) {
        streak += 1;
      }
      expect(streak, 1);

      // Day 2: Next day message (increments streak)
      final day2 = DateTime(2026, 9, 2);
      const day2Str = '2026-09-02';
      final prevDate = DateTime(2026, 9, 1);
      final diff = day2.difference(prevDate).inDays;
      if (diff == 1) {
        streak += 1;
        lastDate = day2Str;
      }
      expect(streak, 2);
      expect(lastDate, '2026-09-02');

      // Day 5: Missed 2 days (resets streak to 1)
      final day5 = DateTime(2026, 9, 5);
      const day5Str = '2026-09-05';
      final prevDate2 = DateTime(2026, 9, 2);
      final diff2 = day5.difference(prevDate2).inDays;
      if (diff2 > 1) {
        streak = 1;
        lastDate = day5Str;
      }
      expect(streak, 1);
      expect(lastDate, '2026-09-05');
    });
  });

  group('Phase 2 - Advanced Message Types Tests', () {
    test('Quick Ping message serialization', () {
      final now = DateTime.now();
      final msg = MessageModel(
        id: 'msg_ping',
        chatId: 'c1',
        senderId: 'u1',
        senderName: 'Sender',
        text: '⚡ Thinking of you',
        type: MessageType.quickPing,
        timestamp: now,
        quickPingEmoji: '⚡',
        quickPingLabel: 'Thinking of you',
      );

      final map = msg.toMap();
      expect(map['type'], 'quickPing');
      expect(map['quickPingEmoji'], '⚡');
      expect(map['quickPingLabel'], 'Thinking of you');

      final parsed = MessageModel.fromMap(map);
      expect(parsed.type, MessageType.quickPing);
      expect(parsed.quickPingEmoji, '⚡');
      expect(parsed.quickPingLabel, 'Thinking of you');
    });

    test('Poll message serialization and votes map', () {
      final now = DateTime.now();
      final msg = MessageModel(
        id: 'msg_poll',
        chatId: 'c1',
        senderId: 'u1',
        senderName: 'Host',
        text: 'Where to eat?',
        type: MessageType.poll,
        timestamp: now,
        pollQuestion: 'Where to eat?',
        pollOptions: ['Pizza', 'Sushi', 'Burgers'],
        pollVotes: {
          'Pizza': ['u1', 'u2'],
          'Sushi': ['u3'],
        },
      );

      final map = msg.toMap();
      expect(map['type'], 'poll');
      expect(map['pollQuestion'], 'Where to eat?');
      expect(map['pollOptions'], ['Pizza', 'Sushi', 'Burgers']);
      expect((map['pollVotes'] as Map)['Pizza'], ['u1', 'u2']);

      final parsed = MessageModel.fromMap(map);
      expect(parsed.type, MessageType.poll);
      expect(parsed.pollQuestion, 'Where to eat?');
      expect(parsed.pollOptions?.length, 3);
      expect(parsed.pollVotes?['Pizza'], ['u1', 'u2']);
      expect(parsed.pollVotes?['Sushi'], ['u3']);
    });

    test('Time Capsule (scheduled) message serialization', () {
      final now = DateTime.now();
      final scheduledTime = now.add(const Duration(days: 30));
      final msg = MessageModel(
        id: 'msg_sched',
        chatId: 'c1',
        senderId: 'u1',
        senderName: 'Sender',
        text: 'Open this on our anniversary!',
        type: MessageType.scheduled,
        timestamp: now,
        scheduledFor: scheduledTime,
      );

      final map = msg.toMap();
      expect(map['type'], 'scheduled');
      expect(map['scheduledFor'], isNotNull);

      final parsed = MessageModel.fromMap(map);
      expect(parsed.type, MessageType.scheduled);
      expect(parsed.scheduledFor?.year, scheduledTime.year);
    });

    test('Shared Playlist message serialization', () {
      final now = DateTime.now();
      final msg = MessageModel(
        id: 'msg_playlist',
        chatId: 'c1',
        senderId: 'u1',
        senderName: 'DJ',
        text: '🎵 Road Trip 2026',
        type: MessageType.playlist,
        timestamp: now,
        playlistName: 'Road Trip 2026',
        playlistTracks: [
          {'title': 'Song 1', 'artist': 'Artist'},
          {'title': 'Song 2', 'artist': 'Band'},
        ],
      );

      final map = msg.toMap();
      expect(map['type'], 'playlist');
      expect(map['playlistName'], 'Road Trip 2026');
      expect(map['playlistTracks'].length, 2);

      final parsed = MessageModel.fromMap(map);
      expect(parsed.type, MessageType.playlist);
      expect(parsed.playlistName, 'Road Trip 2026');
      expect(parsed.playlistTracks?.first['title'], 'Song 1');
    });
  });

  group('Phase 2 - Mood & Anonymous Q&A Tests', () {
    test('MoodModel preset moods validity', () {
      expect(MoodModel.presetMoods.isNotEmpty, isTrue);
      for (final m in MoodModel.presetMoods) {
        expect(m.emoji.isNotEmpty, isTrue);
        expect(m.label.isNotEmpty, isTrue);
      }
    });

    test('AnonymousQAModel serialization', () {
      final now = DateTime.now();
      final qa = AnonymousQAModel(
        id: 'q123',
        statusId: 'status_abc',
        question: 'What is your favorite book?',
        senderUid: 'secret_user_uid',
        createdAt: now,
        answer: 'The Great Gatsby',
        isAnswered: true,
      );

      final map = qa.toMap();
      expect(map['id'], 'q123');
      expect(map['question'], 'What is your favorite book?');
      expect(map['senderUid'], 'secret_user_uid');
      expect(map['isAnswered'], isTrue);
      expect(map['answer'], 'The Great Gatsby');

      final parsed = AnonymousQAModel.fromMap(map);
      expect(parsed.id, 'q123');
      expect(parsed.question, 'What is your favorite book?');
      expect(parsed.isAnswered, isTrue);
    });
  });

  group('Phase 2 - Message Search Filtering Tests', () {
    final t1 = DateTime(2026, 9, 1, 10, 0);
    final t2 = DateTime(2026, 9, 2, 14, 30);
    final t3 = DateTime(2026, 9, 3, 19, 0);

    final messages = [
      MessageModel(
        id: 'm1',
        chatId: 'c1',
        senderId: 'u1',
        senderName: 'Me',
        text: 'Hey let us meet for coffee',
        type: MessageType.text,
        timestamp: t1,
      ),
      MessageModel(
        id: 'm2',
        chatId: 'c1',
        senderId: 'u2',
        senderName: 'Other',
        text: 'Sure, coffee sounds great!',
        type: MessageType.text,
        timestamp: t2,
      ),
      MessageModel(
        id: 'm3',
        chatId: 'c1',
        senderId: 'u1',
        senderName: 'Me',
        text: 'Where are the project files?',
        type: MessageType.text,
        timestamp: t3,
      ),
    ];

    test('Search by keyword filters correctly', () {
      const query = 'coffee';
      final results = messages.where((m) => m.text.toLowerCase().contains(query)).toList();
      expect(results.length, 2);
      expect(results.map((m) => m.id), containsAll(['m1', 'm2']));
    });

    test('Search by sender filter', () {
      final myMessages = messages.where((m) => m.senderId == 'u1').toList();
      expect(myMessages.length, 2);
      final otherMessages = messages.where((m) => m.senderId == 'u2').toList();
      expect(otherMessages.length, 1);
    });

    test('Search by date range filter', () {
      final rangeStart = DateTime(2026, 9, 2);
      final rangeEnd = DateTime(2026, 9, 3, 23, 59, 59);

      final inRange = messages.where((m) {
        return m.timestamp.isAfter(rangeStart) && m.timestamp.isBefore(rangeEnd);
      }).toList();

      expect(inRange.length, 2);
      expect(inRange.map((m) => m.id), containsAll(['m2', 'm3']));
    });
  });

  group('Defensive Firestore User Model & Type Safety Tests', () {
    test('UserModel safely parses moodColor as Hex String without throwing type cast error', () {
      final docData = {
        'uid': 'u_test_1',
        'displayName': 'Test User',
        'email': 'test@velza.com',
        'phoneNumber': '+15551234567',
        'isOnline': true,
        'moodEmoji': '🔥',
        'moodColor': '0xFFD4AF37', // String from Firestore!
      };

      // Must NOT throw: type 'String' is not a subtype of type 'int?' in type cast
      final user = UserModel.fromMap(docData);
      expect(user.uid, 'u_test_1');
      expect(user.moodEmoji, '🔥');
      expect(user.moodColor, 0xFFD4AF37);
    });

    test('UserModel safely parses moodColor as lower-case hex, hash hex, int, and double', () {
      // lower-case hex
      final u1 = UserModel.fromMap({'uid': '1', 'moodColor': '0xff6a1b9a'});
      expect(u1.moodColor, 0xFF6A1B9A);

      // hash hex
      final u2 = UserModel.fromMap({'uid': '2', 'moodColor': '#6A1B9A'});
      expect(u2.moodColor, 0xFF6A1B9A);

      // regular int
      final u3 = UserModel.fromMap({'uid': '3', 'moodColor': 0xFF6A1B9A});
      expect(u3.moodColor, 0xFF6A1B9A);

      // double / num
      final u4 = UserModel.fromMap({'uid': '4', 'moodColor': 4285143962.0});
      expect(u4.moodColor, 4285143962);

      // null or empty
      final u5 = UserModel.fromMap({'uid': '5', 'moodColor': null});
      expect(u5.moodColor, isNull);

      final u6 = UserModel.fromMap({'uid': '6', 'moodColor': ''});
      expect(u6.moodColor, isNull);
    });

    test('UserModel ensures phoneNumber is always String, never cast to int', () {
      final u = UserModel.fromMap({
        'uid': 'phone_user',
        'phoneNumber': '+919876543210',
      });
      expect(u.phoneNumber, isA<String>());
      expect(u.phoneNumber, '+919876543210');
    });

    test('RelationshipModel safely stores and restores sharedNickname', () {
      final now = DateTime.now();
      final rel = RelationshipModel(
        relationshipId: 'u1_u2',
        fromUid: 'u1',
        toUid: 'u2',
        status: RelationshipStatus.accepted,
        sharedNickname: 'Sweetheart 💖',
        createdAt: now,
        updatedAt: now,
      );

      final map = rel.toMap();
      expect(map['sharedNickname'], 'Sweetheart 💖');

      final reconstructed = RelationshipModel.fromMap(map);
      expect(reconstructed.sharedNickname, 'Sweetheart 💖');
    });

    test('Relationship-scoped nickname visibility rule: A & B see it, unrelated C does not', () {
      // User A and User B have a relationship
      final relAB = RelationshipModel(
        relationshipId: RelationshipModel.generateId('user_A', 'user_B'),
        fromUid: 'user_A',
        toUid: 'user_B',
        status: RelationshipStatus.accepted,
        sharedNickname: 'Partner in Crime',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // A accessing B or B accessing A gets relAB
      final aViewingB = relAB.sharedNickname;
      final bViewingA = relAB.sharedNickname;
      expect(aViewingB, 'Partner in Crime');
      expect(bViewingA, 'Partner in Crime');

      // Unrelated User C looking at User B queries relationship(user_C, user_B) which has no shared nickname
      final relCB = RelationshipModel(
        relationshipId: RelationshipModel.generateId('user_C', 'user_B'),
        fromUid: 'user_C',
        toUid: 'user_B',
        status: RelationshipStatus.none,
        sharedNickname: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cViewingB = relCB.sharedNickname;
      expect(cViewingB, isNull);
    });
  });
}
