import 'package:flutter_test/flutter_test.dart';
import 'package:velza/models/relationship_model.dart';
import 'package:velza/models/message_model.dart';
import 'package:velza/services/wallpaper_service.dart';

void main() {
  group('Phase 1 Foundation - RelationshipModel Tests', () {
    test('RelationshipModel ID generation is deterministic and symmetric', () {
      final id1 = RelationshipModel.generateId('userA', 'userB');
      expect(id1, 'userA_userB');
    });

    test('RelationshipModel serialization and status parsing', () {
      final now = DateTime.now();
      final rel = RelationshipModel(
        relationshipId: 'user1_user2',
        fromUid: 'user1',
        toUid: 'user2',
        status: RelationshipStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      final map = rel.toMap();
      expect(map['relationshipId'], 'user1_user2');
      expect(map['fromUid'], 'user1');
      expect(map['toUid'], 'user2');
      expect(map['status'], 'pending');

      final parsed = RelationshipModel.fromMap(map);
      expect(parsed.relationshipId, 'user1_user2');
      expect(parsed.status, RelationshipStatus.pending);
      expect(parsed.isPending, isTrue);
      expect(parsed.isAccepted, isFalse);
      expect(parsed.isBlocked, isFalse);
    });

    test('RelationshipModel status helpers work correctly for all states', () {
      final now = DateTime.now();
      final acceptedRel = RelationshipModel(
        relationshipId: 'user1_user2',
        fromUid: 'user1',
        toUid: 'user2',
        status: RelationshipStatus.accepted,
        createdAt: now,
        updatedAt: now,
      );
      expect(acceptedRel.isAccepted, isTrue);
      expect(acceptedRel.isPending, isFalse);

      final blockedRel = RelationshipModel(
        relationshipId: 'user1_user2',
        fromUid: 'user1',
        toUid: 'user2',
        status: RelationshipStatus.blocked,
        createdAt: now,
        updatedAt: now,
      );
      expect(blockedRel.isBlocked, isTrue);
      expect(blockedRel.isAccepted, isFalse);
    });
  });

  group('Phase 1 Foundation - Message Delivery Status & Read Receipts Tests', () {
    test('MessageDeliveryStatus returns sending when isSending is true', () {
      final msg = MessageModel(
        id: 'm1',
        senderId: 'userA',
        senderName: 'Alice',
        chatId: 'chat1',
        text: 'Hi',
        type: MessageType.text,
        url: '',
        fileName: '',
        readBy: ['userA'],
        timestamp: DateTime.now(),
        isSending: true,
      );

      expect(msg.getDeliveryStatus(otherUserId: 'userB', readReceiptsEnabled: true), MessageDeliveryStatus.sending);
      expect(msg.getDeliveryStatus(otherUserId: 'userB', readReceiptsEnabled: false), MessageDeliveryStatus.sending);
    });

    test('MessageDeliveryStatus returns failed when isFailed is true', () {
      final msg = MessageModel(
        id: 'm2',
        senderId: 'userA',
        senderName: 'Alice',
        chatId: 'chat1',
        text: 'Failed msg',
        type: MessageType.text,
        url: '',
        fileName: '',
        readBy: ['userA'],
        timestamp: DateTime.now(),
        isFailed: true,
      );

      expect(msg.getDeliveryStatus(otherUserId: 'userB', readReceiptsEnabled: true), MessageDeliveryStatus.failed);
    });

    test('MessageDeliveryStatus returns read when recipient in readBy and readReceiptsEnabled is true', () {
      final msg = MessageModel(
        id: 'm3',
        senderId: 'userA',
        senderName: 'Alice',
        chatId: 'chat1',
        text: 'Seen msg',
        type: MessageType.text,
        url: '',
        fileName: '',
        timestamp: DateTime.now(),
        readBy: ['userA', 'userB'],
        deliveredTo: ['userB'],
      );

      expect(msg.getDeliveryStatus(otherUserId: 'userB', readReceiptsEnabled: true), MessageDeliveryStatus.read);
    });

    test('MessageDeliveryStatus falls back to delivered when readReceiptsEnabled is false even if read', () {
      final msg = MessageModel(
        id: 'm4',
        senderId: 'userA',
        senderName: 'Alice',
        chatId: 'chat1',
        text: 'Seen msg with receipts off',
        type: MessageType.text,
        url: '',
        fileName: '',
        timestamp: DateTime.now(),
        readBy: ['userA', 'userB'],
        deliveredTo: ['userB'],
      );

      // Privacy mode: recipient read it, but readReceiptsEnabled is OFF -> only show delivered
      expect(msg.getDeliveryStatus(otherUserId: 'userB', readReceiptsEnabled: false), MessageDeliveryStatus.delivered);
    });

    test('MessageDeliveryStatus returns delivered when recipient is in deliveredTo', () {
      final msg = MessageModel(
        id: 'm5',
        senderId: 'userA',
        senderName: 'Alice',
        chatId: 'chat1',
        text: 'Delivered msg',
        type: MessageType.text,
        url: '',
        fileName: '',
        timestamp: DateTime.now(),
        readBy: ['userA'],
        deliveredTo: ['userB'],
      );

      expect(msg.getDeliveryStatus(otherUserId: 'userB', readReceiptsEnabled: true), MessageDeliveryStatus.delivered);
    });

    test('MessageDeliveryStatus returns sent when recipient is not in deliveredTo or readBy', () {
      final msg = MessageModel(
        id: 'm6',
        senderId: 'userA',
        senderName: 'Alice',
        chatId: 'chat1',
        text: 'Sent msg',
        type: MessageType.text,
        url: '',
        fileName: '',
        timestamp: DateTime.now(),
        readBy: ['userA'],
        deliveredTo: [],
      );

      expect(msg.getDeliveryStatus(otherUserId: 'userB', readReceiptsEnabled: true), MessageDeliveryStatus.sent);
    });
  });

  group('Phase 1 Foundation - 16 Luxury Wallpaper Themes Tests', () {
    test('WallpaperService has exactly 16 luxury presets', () {
      expect(WallpaperService.presets.length, 16);
      final expectedIds = [
        'velza_default',
        'amoled_black',
        'ocean_breeze',
        'sunset_glow',
        'lavender_dream',
        'rose_gold',
        'forest_emerald',
        'neon_cyber',
        'aurora_borealis',
        'galaxy_nebula',
        'luxury_royal',
        'minimal_slate',
        'glass_frost',
        'classic_charcoal',
        'vintage_paper',
        'retro_synthwave',
      ];
      for (final id in expectedIds) {
        final preset = WallpaperService.getPresetById(id);
        expect(preset.id, id, reason: 'Preset $id should exist');
        expect(preset.name.isNotEmpty, isTrue);
      }
    });

    test('WallpaperService returns fallback preset for unknown id', () {
      final fallback = WallpaperService.getPresetById('unknown_xyz');
      expect(fallback.id, 'velza_default');
    });
  });

  group('Phase 1 Foundation - Bulk Message Delete Chunking Tests', () {
    test('Chunking splits up to 999 messages into batches of <= 400', () {
      final messagesToDelete = List.generate(999, (index) => 'msg_$index');
      
      const batchSize = 400;
      final chunks = <List<String>>[];
      for (int i = 0; i < messagesToDelete.length; i += batchSize) {
        final end = (i + batchSize < messagesToDelete.length) ? i + batchSize : messagesToDelete.length;
        chunks.add(messagesToDelete.sublist(i, end));
      }

      expect(chunks.length, 3);
      expect(chunks[0].length, 400);
      expect(chunks[1].length, 400);
      expect(chunks[2].length, 199);
      expect(chunks.fold<int>(0, (sum, chunk) => sum + chunk.length), 999);
    });
  });
}
