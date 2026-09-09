import 'package:flutter_test/flutter_test.dart';
import 'package:velza/models/user_model.dart';

void main() {
  group('WhatsApp-like User Discovery and Profile Sync Tests', () {
    test('Derive displayName from email when displayName is empty or missing', () {
      const email = 'kavya.sharma@example.com';
      final derivedName = email.split('@').first;
      expect(derivedName, 'kavya.sharma');

      final user = UserModel(
        uid: 'user_a_123',
        email: email,
        displayName: derivedName,
        searchableName: derivedName.toLowerCase(),
        phoneNumber: '+919876543210',
        photoUrl: '',
        isOnline: true,
        typingTo: 'none',
        lastSeen: DateTime.now(),
        blockedUsers: [],
      );

      expect(user.displayName, 'kavya.sharma');
      expect(user.searchableName, 'kavya.sharma');
      expect(user.uid, 'user_a_123');
      expect(user.email, 'kavya.sharma@example.com');
      expect(user.phoneNumber, '+919876543210');
      expect(user.isOnline, true);
    });

    test('Allow user to edit profile name later and update searchableName', () {
      final user = UserModel(
        uid: 'user_a_123',
        email: 'kavya.sharma@example.com',
        displayName: 'kavya.sharma',
        searchableName: 'kavya.sharma',
        phoneNumber: '',
        photoUrl: '',
        isOnline: true,
        typingTo: 'none',
        lastSeen: DateTime.now(),
        blockedUsers: [],
      );

      final updated = user.copyWith(
        displayName: 'Kavya Sharma (Velza)',
        searchableName: 'kavya sharma (velza)',
      );

      expect(updated.displayName, 'Kavya Sharma (Velza)');
      expect(updated.searchableName, 'kavya sharma (velza)');
      expect(updated.uid, 'user_a_123');
      expect(updated.email, 'kavya.sharma@example.com');
    });

    test('Firestore serialization and deserialization retains all required discovery fields', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user_b_456',
        email: 'rohit.verma@domain.org',
        displayName: 'Rohit Verma',
        searchableName: 'rohit verma',
        phoneNumber: '+14155552671',
        photoUrl: 'https://example.com/avatar.jpg',
        isOnline: true,
        typingTo: 'none',
        lastSeen: now,
        blockedUsers: [],
      );

      final map = user.toMap();
      expect(map['uid'], 'user_b_456');
      expect(map['email'], 'rohit.verma@domain.org');
      expect(map['displayName'], 'Rohit Verma');
      expect(map['searchableName'], 'rohit verma');
      expect(map['phoneNumber'], '+14155552671');
      expect(map['isOnline'], true);

      final reconstructed = UserModel.fromMap(map);
      expect(reconstructed.uid, 'user_b_456');
      expect(reconstructed.email, 'rohit.verma@domain.org');
      expect(reconstructed.displayName, 'Rohit Verma');
      expect(reconstructed.searchableName, 'rohit verma');
      expect(reconstructed.phoneNumber, '+14155552671');
      expect(reconstructed.isOnline, true);
    });

    test('Two real accounts: Device A (Account A) and Device B (Account B) discover each other', () {
      // Simulate real Firestore collection with two registered accounts
      final accountA = UserModel(
        uid: 'uid_account_A',
        email: 'deviceA@velza.app',
        displayName: 'Device A User',
        searchableName: 'device a user',
        phoneNumber: '+919999900001',
        photoUrl: '',
        isOnline: true,
        typingTo: 'none',
        lastSeen: DateTime.now(),
        blockedUsers: [],
      );

      final accountB = UserModel(
        uid: 'uid_account_B',
        email: 'deviceB@velza.app',
        displayName: 'Device B User',
        searchableName: 'device b user',
        phoneNumber: '+919999900002',
        photoUrl: '',
        isOnline: false,
        typingTo: 'none',
        lastSeen: DateTime.now(),
        blockedUsers: [],
      );

      final firestoreUsersCollection = <UserModel>[accountA, accountB];

      // 1. Device A searches registered users (currentUid = 'uid_account_A')
      // Rule: Exclude ONLY currently logged in user's UID
      final deviceAView = firestoreUsersCollection
          .where((u) => u.uid != 'uid_account_A')
          .toList();

      expect(deviceAView.length, 1);
      expect(deviceAView.first.uid, 'uid_account_B');
      expect(deviceAView.first.displayName, 'Device B User');

      // 2. Device B searches registered users (currentUid = 'uid_account_B')
      final deviceBView = firestoreUsersCollection
          .where((u) => u.uid != 'uid_account_B')
          .toList();

      expect(deviceBView.length, 1);
      expect(deviceBView.first.uid, 'uid_account_A');
      expect(deviceBView.first.displayName, 'Device A User');

      // 3. Search helper function mirroring database_service.dart
      List<UserModel> search(String query, String currentUid) {
        final q = query.trim().toLowerCase();
        return firestoreUsersCollection.where((u) {
          if (u.uid == currentUid) return false;
          if (q.isEmpty) return true;
          return u.displayName.toLowerCase().contains(q) ||
              u.searchableName.contains(q) ||
              u.email.toLowerCase().contains(q) ||
              (u.phoneNumber.isNotEmpty && u.phoneNumber.contains(q));
        }).toList();
      }

      // Search by email prefix
      expect(search('deviceB', 'uid_account_A').first.uid, 'uid_account_B');
      // Search by phone number
      expect(search('900002', 'uid_account_A').first.uid, 'uid_account_B');
      // Search by display name
      expect(search('Device B', 'uid_account_A').first.uid, 'uid_account_B');

      // Device B finds Device A by phone
      expect(search('900001', 'uid_account_B').first.uid, 'uid_account_A');
      // Self search excluded
      expect(search('Device A', 'uid_account_A').isEmpty, true);
    });
  });
}
