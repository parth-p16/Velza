import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velza/models/message_model.dart';
import 'package:velza/models/status_model.dart';
import 'package:velza/models/user_model.dart';
import 'package:velza/services/e2ee_service.dart';

void main() {
  group('1. Cryptographic Security & E2EE AEAD Pipeline', () {
    final x25519 = X25519();
    final aesGcm = AesGcm.with256bits();
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

    test('X25519 key exchange + HKDF-SHA256 + AES-GCM-256 matches both sides', () async {
      // User A (Alice)
      final aliceKeyPair = await x25519.newKeyPair();
      final alicePub = await aliceKeyPair.extractPublicKey();

      // User B (Bob)
      final bobKeyPair = await x25519.newKeyPair();
      final bobPub = await bobKeyPair.extractPublicKey();

      const chatId = 'chat_alice_bob_secure';

      // Alice derives session key
      final aliceSecret = await x25519.sharedSecretKey(keyPair: aliceKeyPair, remotePublicKey: bobPub);
      final aliceSessionKey = await hkdf.deriveKey(secretKey: aliceSecret, info: utf8.encode('velza-e2ee-session-$chatId'));

      // Bob derives session key
      final bobSecret = await x25519.sharedSecretKey(keyPair: bobKeyPair, remotePublicKey: alicePub);
      final bobSessionKey = await hkdf.deriveKey(secretKey: bobSecret, info: utf8.encode('velza-e2ee-session-$chatId'));

      // Verify both session keys are identical
      final aliceKeyBytes = await aliceSessionKey.extractBytes();
      final bobKeyBytes = await bobSessionKey.extractBytes();
      expect(aliceKeyBytes, equals(bobKeyBytes));

      // Alice encrypts a message
      const clearMessage = 'Top secret message from Alice to Bob 🔐';
      final secretBox = await aesGcm.encrypt(utf8.encode(clearMessage), secretKey: aliceSessionKey);

      // Envelope format check
      final nonceB64 = base64Encode(secretBox.nonce);
      final cipherB64 = base64Encode(secretBox.cipherText);
      final macB64 = base64Encode(secretBox.mac.bytes);
      final payload = 'v1:$nonceB64:$cipherB64:$macB64';

      expect(E2eeService.isPayloadEncrypted(payload), isTrue);
      expect(payload.startsWith('v1:'), isTrue);
      expect(payload, isNot(contains(clearMessage))); // Ciphertext never contains plaintext

      // Bob decrypts payload
      final parts = payload.split(':');
      final receivedNonce = base64Decode(parts[1]);
      final receivedCipher = base64Decode(parts[2]);
      final receivedMac = Mac(base64Decode(parts[3]));
      final receivedBox = SecretBox(receivedCipher, nonce: receivedNonce, mac: receivedMac);

      final decryptedBytes = await aesGcm.decrypt(receivedBox, secretKey: bobSessionKey);
      final decryptedText = utf8.decode(decryptedBytes);
      expect(decryptedText, equals(clearMessage));

      // Third party (Eve) cannot decrypt
      final eveKeyPair = await x25519.newKeyPair();
      final eveSecret = await x25519.sharedSecretKey(keyPair: eveKeyPair, remotePublicKey: alicePub);
      final eveSessionKey = await hkdf.deriveKey(secretKey: eveSecret, info: utf8.encode('velza-e2ee-session-$chatId'));

      expect(
        () async => await aesGcm.decrypt(receivedBox, secretKey: eveSessionKey),
        throwsA(anything),
      );
    });

    test('MessageModel serialization includes isEncrypted flag and preserves ciphertext', () {
      final now = DateTime.now();
      const payload = 'v1:somenonce:someciphertext:somemactag';

      final msg = MessageModel(
        id: 'msg_sec_1',
        senderId: 'alice_uid',
        senderName: 'Alice',
        chatId: 'chat_sec',
        text: payload,
        type: MessageType.text,
        timestamp: now,
        isEncrypted: true,
      );

      final map = msg.toMap();
      expect(map['isEncrypted'], isTrue);
      expect(map['text'], equals(payload));

      final restored = MessageModel.fromMap(map);
      expect(restored.isEncrypted, isTrue);
      expect(restored.text, equals(payload));
    });

    test('UserModel serialization never exports private keys to Firestore map', () {
      final user = UserModel(
        uid: 'user_test_999',
        email: 'alice@velza.app',
        displayName: 'Alice Security',
        photoUrl: 'https://example.com/avatar.jpg',
        phoneNumber: '+1234567890',
        isOnline: true,
        typingTo: 'none',
        lastSeen: DateTime.now(),
        blockedUsers: [],
      );

      final map = user.toMap();
      expect(map.containsKey('privateKey'), isFalse);
      expect(map.containsKey('e2eePrivateKey'), isFalse);
      expect(map['uid'], equals('user_test_999'));
    });
  });

  group('2. Mutual Nicknames Directional Isolation', () {
    test('Directional nickname keys ensure isolation per conversation member', () {
      const userA = 'uid_alice';
      const userB = 'uid_bob';
      const userC = 'uid_carol';

      final Map<String, dynamic> mutualNicknames = {
        '${userA}_for_$userB': 'My Honey',
        '${userB}_for_$userA': 'My Queen',
      };

      // Alice sees Bob as "My Honey"
      expect(mutualNicknames['${userA}_for_$userB'], equals('My Honey'));
      // Bob sees Alice as "My Queen"
      expect(mutualNicknames['${userB}_for_$userA'], equals('My Queen'));

      // Carol sees no nickname for either Alice or Bob
      expect(mutualNicknames['${userC}_for_$userA'], isNull);
      expect(mutualNicknames['${userC}_for_$userB'], isNull);

      // Alice can independently delete her nickname for Bob without affecting Bob's nickname for Alice
      mutualNicknames.remove('${userA}_for_$userB');
      expect(mutualNicknames['${userA}_for_$userB'], isNull);
      expect(mutualNicknames['${userB}_for_$userA'], equals('My Queen'));
    });
  });

  group('3. Status @Mentions', () {
    test('StatusModel serializes mentionedUserIds and mentions map accurately', () {
      final now = DateTime.now();
      final status = StatusModel(
        statusId: 'status_mention_001',
        userId: 'user_author',
        userName: 'Author',
        userPhotoUrl: 'https://example.com/author.jpg',
        type: StatusType.text,
        text: 'Chilling with @Alice and @Bob today! ✨',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        mentionedUserIds: ['uid_alice', 'uid_bob'],
        mentions: {
          'uid_alice': 'Alice',
          'uid_bob': 'Bob',
        },
      );

      final map = status.toMap();
      expect(map['mentionedUserIds'], equals(['uid_alice', 'uid_bob']));
      expect(map['mentions'], equals({'uid_alice': 'Alice', 'uid_bob': 'Bob'}));

      final restored = StatusModel.fromMap(map);
      expect(restored.mentionedUserIds, contains('uid_alice'));
      expect(restored.mentionedUserIds, contains('uid_bob'));
      expect(restored.mentions?['uid_alice'], equals('Alice'));
      expect(restored.mentions?['uid_bob'], equals('Bob'));
    });
  });

  group('4. Custom Sticker Recipient Pipeline Integrity', () {
    test('Sticker message contains Firebase Storage download URL and never a local device file path', () {
      // Simulating what DatabaseService receives after Cloud Storage upload
      const cloudStorageUrl = 'https://firebasestorage.googleapis.com/v0/b/velza-app.appspot.com/o/chats%2Fchat123%2Fstickers%2Fcustom_01.png?alt=media&token=abcdef12345';
      const forbiddenLocalPath = '/data/user/0/com.velza.app/app_flutter/custom_stickers/temp.png';

      final message = MessageModel(
        id: 'msg_sticker_1',
        senderId: 'user_sender',
        senderName: 'Sender',
        chatId: 'chat123',
        text: 'Sticker',
        type: MessageType.sticker,
        url: cloudStorageUrl,
        timestamp: DateTime.now(),
      );

      // Verify sticker url is remote URL
      expect(message.url.startsWith('http://') || message.url.startsWith('https://'), isTrue);
      expect(message.mediaUrl.startsWith('http://') || message.mediaUrl.startsWith('https://'), isTrue);
      expect(message.url, isNot(contains('/data/user/0/')));
      expect(message.url, isNot(equals(forbiddenLocalPath)));
    });
  });

  group('5. Client-Side Decrypted Search Validation', () {
    test('Search filters against local decrypted cache instead of Firestore ciphertext', () {
      final messages = [
        MessageModel(
          id: 'm1',
          senderId: 'u1',
          senderName: 'Alice',
          chatId: 'c1',
          text: 'v1:nonce:cipher1:mac1',
          type: MessageType.text,
          timestamp: DateTime.now(),
          isEncrypted: true,
        ),
        MessageModel(
          id: 'm2',
          senderId: 'u2',
          senderName: 'Bob',
          chatId: 'c1',
          text: 'v1:nonce:cipher2:mac2',
          type: MessageType.text,
          timestamp: DateTime.now(),
          isEncrypted: true,
        ),
      ];

      // Simulated local decrypted cache
      final decryptedMap = {
        'v1:nonce:cipher1:mac1': 'Meeting at the coffee shop tomorrow ☕',
        'v1:nonce:cipher2:mac2': 'Sounds great, see you there!',
      };

      const query = 'coffee';

      final results = messages.where((msg) {
        final clearText = decryptedMap[msg.text] ?? msg.text;
        return clearText.toLowerCase().contains(query.toLowerCase());
      }).toList();

      expect(results.length, equals(1));
      expect(results.first.id, equals('m1'));
    });
  });
}
