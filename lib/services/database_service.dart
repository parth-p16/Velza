import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:velza/models/user_model.dart';
import 'package:velza/models/chat_model.dart';
import 'package:velza/models/message_model.dart';
import 'package:velza/models/status_model.dart';
import 'package:velza/models/relationship_model.dart';
import 'package:velza/models/anonymous_qa_model.dart';

class MutualNicknameInfo {
  final String? nicknameGivenByMe;
  final String? nicknameGivenToMe;

  const MutualNicknameInfo({
    this.nicknameGivenByMe,
    this.nicknameGivenToMe,
  });
}

class DatabaseService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  static const String projectId = 'velza-5ab77';

  // In-memory cache to eliminate duplicate network lookups across list views
  final Map<String, UserModel> _userCache = {};

  DatabaseService() {
    // Safely enable Firestore offline persistence
    try {
      _db.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      // Settings already initialized or immutable in this process
    }
  }

  UserModel? getCachedUser(String uid) => _userCache[uid];

  Future<UserModel?> fetchUserCached(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];
    try {
      final snap = await _db.collection('users').doc(uid).get();
      if (snap.exists && snap.data() != null) {
        final u = UserModel.fromMap(snap.data()!);
        _userCache[uid] = u;
        return u;
      }
    } catch (e) {
      debugPrint('[DatabaseService] Error fetching user cached: $e');
    }
    return null;
  }

  Future<UserModel?> getUserProfile(String uid) => fetchUserCached(uid);

  // --- User Profiles & Presence ---
  
  // Upsert user profile
  Future<void> saveUserProfile(UserModel user) async {
    _userCache[user.uid] = user;
    debugPrint("[Velza Profile] Upserting user profile to users/${user.uid}: displayName='${user.displayName}', email='${user.email}', searchableName='${user.searchableName}', phone='${user.phoneNumber}', isOnline=${user.isOnline}");
    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .set(user.toMap(), SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () {
              debugPrint("[Velza Profile TIMEOUT] Write to users/${user.uid} committed to local cache; server sync pending.");
            },
          );
      debugPrint("[Velza Profile SUCCESS] Document users/${user.uid} confirmed saved to Firestore.");
    } on FirebaseException catch (fe, stack) {
      debugPrint("[Velza Profile FAILURE] Error writing users/${user.uid}: [${fe.code}] ${fe.message}\n$stack");
      rethrow;
    } catch (e, stack) {
      debugPrint("[Velza Profile FAILURE] Error writing users/${user.uid}: $e\n$stack");
      rethrow;
    }
  }

  // Stream of a user's data with cache updating
  Stream<UserModel> streamUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      final data = Map<String, dynamic>.from(snapshot.data() ?? {});
      if (data['uid'] == null || (data['uid'] as String).isEmpty) {
        data['uid'] = snapshot.id;
      }
      final user = UserModel.fromMap(data);
      if (user.uid.isNotEmpty) {
        _userCache[user.uid] = user;
      }
      return user;
    });
  }

  // Real-time stream of all registered users (excluding ONLY current user's UID)
  Stream<List<UserModel>> streamRegisteredUsers(String currentUid) {
    debugPrint("[Velza Stream] Listening to 'users' collection. Current Firebase UID: $currentUid");
    return _db.collection('users').snapshots().map((snapshot) {
      debugPrint("[Velza Stream] Firestore returned ${snapshot.docs.length} total document(s) from 'users' collection (isFromCache: ${snapshot.metadata.isFromCache})");
      final otherUsers = snapshot.docs
          .map((doc) {
            try {
              final data = Map<String, dynamic>.from(doc.data());
              if (data['uid'] == null || (data['uid'] as String).isEmpty) {
                data['uid'] = doc.id;
              }
              return UserModel.fromMap(data);
            } catch (e) {
              debugPrint("[Velza Stream] Defensive catch parsing user doc ${doc.id}: $e");
              return null;
            }
          })
          .whereType<UserModel>()
          .where((user) {
            // Exclude ONLY currently logged in user's UID
            return currentUid.isEmpty || user.uid != currentUid;
          })
          .toList();
      debugPrint("[Velza Stream] Filtered result: ${otherUsers.length} other registered user(s) (excluding $currentUid)");
      return otherUsers;
    });
  }

  // Update presence status
  Future<void> updateUserPresence(String uid, bool isOnline) async {
    try {
      final now = DateTime.now();
      if (_userCache.containsKey(uid)) {
        _userCache[uid] = _userCache[uid]!.copyWith(
          isOnline: isOnline,
          lastSeen: now,
        );
      }
      await _db.collection('users').doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': Timestamp.fromDate(now),
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint("Error updating presence: $e");
    }
  }

  // Update typing indicator status
  Future<void> updateTypingStatus(String uid, String typingTo) async {
    try {
      await _db.collection('users').doc(uid).update({
        'typingTo': typingTo,
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint("Error updating typing status: $e");
    }
  }

  // Get user by phone number
  Future<UserModel?> getUserByPhoneNumber(String phoneNumber) async {
    try {
      final snapshot = await _db
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 15));
      if (snapshot.docs.isNotEmpty) {
        return UserModel.fromMap(snapshot.docs.first.data());
      }
    } catch (e) {
      debugPrint("Error looking up user by phone number: $e");
    }
    return null;
  }

  // Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final snapshot = await _db
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 15));
      if (snapshot.docs.isNotEmpty) {
        return UserModel.fromMap(snapshot.docs.first.data());
      }
    } catch (e) {
      debugPrint("Error looking up user by email: $e");
    }
    return null;
  }

  // Search users by display name, email, or phone number from backend Firestore
  Future<List<UserModel>> searchUsers(String query, String currentUid) async {
    debugPrint("[Velza FindUsers] Current Firebase UID: $currentUid | Query: '$query'");
    try {
      final snapshot = await _db
          .collection('users')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              debugPrint("[Velza FindUsers] Server query timed out after 20s, reading from local cache.");
              return _db.collection('users').get(const GetOptions(source: Source.cache));
            },
          );
          
      debugPrint("[Velza FindUsers] Firestore returned ${snapshot.docs.length} total user document(s) from 'users' collection (isFromCache: ${snapshot.metadata.isFromCache})");

      final allUsers = snapshot.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            if (data['uid'] == null || (data['uid'] as String).isEmpty) {
              data['uid'] = doc.id;
            }
            return UserModel.fromMap(data);
          })
          .where((user) {
            // Exclude ONLY currently logged in user's UID
            return currentUid.isEmpty || user.uid != currentUid;
          })
          .toList();

      debugPrint("[Velza FindUsers] Excluded current user ($currentUid). Remaining registered users count: ${allUsers.length}");

      final queryTrimmed = query.trim();
      if (queryTrimmed.isEmpty) {
        debugPrint("[Velza FindUsers] Query is empty, returning all ${allUsers.length} other registered user(s).");
        return allUsers;
      }

      final queryLower = queryTrimmed.toLowerCase();
      final queryDigits = queryTrimmed.replaceAll(RegExp(r'\D'), '');

      final matched = allUsers.where((user) {
        final nameMatch = user.displayName.toLowerCase().contains(queryLower) ||
            user.searchableName.contains(queryLower);
        final emailMatch = user.email.toLowerCase().contains(queryLower);
        final userPhoneDigits = user.phoneNumber.replaceAll(RegExp(r'\D'), '');
        final phoneMatch = (queryDigits.isNotEmpty && 
                            (userPhoneDigits.contains(queryDigits) || queryDigits.contains(userPhoneDigits))) ||
                           user.phoneNumber.contains(queryTrimmed);
        return nameMatch || emailMatch || phoneMatch;
      }).toList();

      debugPrint("[Velza FindUsers] Exact search filtering result for '$queryTrimmed': ${matched.length} user(s) -> ${matched.map((u) => '${u.displayName} (${u.email})').toList()}");
      return matched;
    } on FirebaseException catch (fe, stack) {
      debugPrint("[Velza FindUsers ERROR] [${fe.code}] ${fe.message}\n$stack");
      rethrow;
    } catch (e, stack) {
      debugPrint("[Velza FindUsers ERROR] $e\n$stack");
      rethrow;
    }
  }

  // Block User
  Future<void> blockUser(String currentUid, String blockUid) async {
    await _db.collection('users').doc(currentUid).update({
      'blockedUsers': FieldValue.arrayUnion([blockUid]),
    });
  }

  // Unblock User
  Future<void> unblockUser(String currentUid, String blockUid) async {
    await _db.collection('users').doc(currentUid).update({
      'blockedUsers': FieldValue.arrayRemove([blockUid]),
    });
  }

  // Report User
  Future<void> reportUser(String currentUid, String reportUid, String reason) async {
    await _db.collection('reports').add({
      'reporterId': currentUid,
      'reportedId': reportUid,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- Chats & Messages ---

  // Stream active chats of a user
  Stream<List<ChatModel>> streamUserChats(String uid) {
    return _db
        .collection('chats')
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final chats = snapshot.docs.map((doc) => ChatModel.fromMap(doc.data())).toList();
      // Sort in memory by lastMessageTime descending
      chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return chats;
    });
  }

  // Create or get 1-1 Chat ID
  Future<String> getOrCreateOneToOneChat(String uid1, String uid2, String name1, String name2, String photo1, String photo2) async {
    // Generate deterministic chat ID to avoid duplicate channels
    final List<String> sortedIds = [uid1, uid2]..sort();
    final String chatId = 'one_to_one_${sortedIds[0]}_${sortedIds[1]}';

    final docRef = _db.collection('chats').doc(chatId);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      final newChat = ChatModel(
        id: chatId,
        name: '$name1 & $name2', // Used as fallback
        photoUrl: '', // Dynamic on view layer
        isGroup: false,
        memberIds: sortedIds,
        lastMessageText: 'No messages yet',
        lastMessageTime: DateTime.now(),
        unreadCounts: {uid1: 0, uid2: 0},
        typingStatus: {uid1: 'none', uid2: 'none'},
      );
      await docRef.set(newChat.toMap());
    }
    return chatId;
  }

  // Create Group Chat
  Future<String> createGroupChat({
    required String name,
    required String photoUrl,
    required List<String> memberIds,
    required String creatorId,
  }) async {
    final String chatId = 'group_${DateTime.now().millisecondsSinceEpoch}';
    final docRef = _db.collection('chats').doc(chatId);

    final Map<String, int> unreadCounts = {};
    final Map<String, String> typingStatus = {};
    for (var member in memberIds) {
      unreadCounts[member] = 0;
      typingStatus[member] = 'none';
    }

    final newChat = ChatModel(
      id: chatId,
      name: name,
      photoUrl: photoUrl,
      isGroup: true,
      memberIds: memberIds,
      lastMessageText: 'Group created by $creatorId',
      lastMessageTime: DateTime.now(),
      unreadCounts: unreadCounts,
      typingStatus: typingStatus,
    );

    await docRef.set(newChat.toMap());
    return chatId;
  }

  // Stream messages inside a chat (paginated to latest limit messages, excluding deleted and cleared messages)
  Stream<List<MessageModel>> streamMessages(String chatId, [String? currentUserId, DateTime? clearedAt]) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(40)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data()))
          .where((msg) {
            if (currentUserId != null && currentUserId.isNotEmpty) {
              if (msg.deletedBy.contains(currentUserId)) return false;
            }
            if (clearedAt != null && msg.timestamp.isBefore(clearedAt)) {
              return false;
            }
            return true;
          })
          .toList();
    });
  }

  // Fetch older messages when scrolling upwards
  Future<List<MessageModel>> fetchOlderMessages({
    required String chatId,
    required DateTime beforeTimestamp,
    int limit = 40,
    String? currentUserId,
    DateTime? clearedAt,
  }) async {
    final query = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .startAfter([Timestamp.fromDate(beforeTimestamp)])
        .limit(limit)
        .get();

    return query.docs
        .map((doc) => MessageModel.fromMap(doc.data()))
        .where((msg) {
          if (currentUserId != null && currentUserId.isNotEmpty) {
            if (msg.deletedBy.contains(currentUserId)) return false;
          }
          if (clearedAt != null && msg.timestamp.isBefore(clearedAt)) {
            return false;
          }
          return true;
        })
        .toList();
  }

  // Send Message
  Future<void> sendMessage(String chatId, MessageModel message) async {
    final docRef = _db.collection('chats').doc(chatId);
    
    // Add message to subcollection
    await docRef.collection('messages').doc(message.id).set(message.toMap());

    // Get current chat metadata to update last message info and unread counts
    final chatDoc = await docRef.get();
    if (chatDoc.exists) {
      final chat = ChatModel.fromMap(chatDoc.data()!);
      final updatedUnreadCounts = Map<String, int>.from(chat.unreadCounts);
      
      // Increment unread count for everyone except the sender
      for (var memberId in chat.memberIds) {
        if (memberId != message.senderId) {
          updatedUnreadCounts[memberId] = (updatedUnreadCounts[memberId] ?? 0) + 1;
        }
      }

      String previewText;
      switch (message.type) {
        case MessageType.text:
          previewText = message.isEncrypted ? '🔒 Encrypted message' : message.text;
          break;
        case MessageType.sticker:
          previewText = '🏷️ Sticker';
          break;
        case MessageType.audio:
          previewText = '🎤 Voice message';
          break;
        case MessageType.image:
          previewText = '📷 Photo';
          break;
        case MessageType.video:
          previewText = '🎥 Video';
          break;
        case MessageType.document:
          previewText = message.fileName.isNotEmpty ? '📄 ${message.fileName}' : '📄 Document';
          break;
        case MessageType.quickPing:
          previewText = '${message.quickPingEmoji ?? '⚡'} ${message.quickPingLabel ?? 'Quick Ping'}';
          break;
        case MessageType.poll:
          previewText = '📊 Poll: ${message.pollQuestion ?? message.text}';
          break;
        case MessageType.scheduled:
          previewText = '⏳ Time Capsule';
          break;
        case MessageType.playlist:
          previewText = '🎵 Playlist: ${message.playlistName ?? 'Shared Playlist'}';
          break;
        case MessageType.gift:
          previewText = '🎁 Surprise Message';
          break;
      }

      // Streak calculation for 1-on-1 chats
      int streak = chat.streakCount;
      String? lastDate = chat.lastStreakDate;
      if (!chat.isGroup) {
        final now = DateTime.now();
        final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        if (lastDate == null) {
          streak = 1;
          lastDate = todayStr;
        } else if (lastDate != todayStr) {
          final parts = lastDate.split('-');
          if (parts.length == 3) {
            final prevDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
            final diffDays = DateTime(now.year, now.month, now.day).difference(DateTime(prevDate.year, prevDate.month, prevDate.day)).inDays;
            if (diffDays == 1) {
              streak += 1;
              lastDate = todayStr;
            } else if (diffDays > 1) {
              streak = 1;
              lastDate = todayStr;
            }
          }
        }
      }

      await docRef.update({
        'lastMessageText': previewText,
        'lastMessageTime': Timestamp.fromDate(message.timestamp),
        'unreadCounts': updatedUnreadCounts,
        'streakCount': streak,
        if (lastDate != null) 'lastStreakDate': lastDate,
      });

      // Queue background notifications for other members
      for (var memberId in chat.memberIds) {
        if (memberId != message.senderId) {
          try {
            _db.collection('notifications').add({
              'senderId': message.senderId,
              'senderName': message.senderName,
              'receiverId': memberId,
              'chatId': chatId,
              'title': message.senderName,
              'body': previewText,
              'type': message.type.name,
              'createdAt': FieldValue.serverTimestamp(),
              'status': 'pending',
            });
          } catch (_) {}
        }
      }
    }
  }

  // Open Gift Message
  Future<void> openGiftMessage({
    required String chatId,
    required String messageId,
    required String userId,
    String? revealedText,
  }) async {
    final docRef = _db.collection('chats').doc(chatId).collection('messages').doc(messageId);
    final updates = <String, dynamic>{
      'isGiftOpened': true,
      'openedAt': FieldValue.serverTimestamp(),
      'giftOpenedBy': userId,
    };
    if (revealedText != null && revealedText.isNotEmpty) {
      updates['text'] = revealedText;
    }
    await docRef.update(updates);
    try {
      if (revealedText != null && revealedText.isNotEmpty) {
        await _db.collection('chats').doc(chatId).update({
          'lastMessageText': '🎁 $revealedText',
        });
      }
    } catch (_) {}
  }

  // Edit Message (only allowed for own messages)
  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String senderId,
    required String newText,
    bool isEncrypted = false,
  }) async {
    final msgRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final msgSnap = await msgRef.get();
    if (!msgSnap.exists) return;
    
    final data = msgSnap.data()!;
    if (data['senderId'] != senderId) {
      throw Exception("Unauthorized: You can only edit your own messages.");
    }

    final updatePayload = <String, dynamic>{
      'text': newText,
      'edited': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (isEncrypted) {
      updatePayload['isEncrypted'] = true;
    }

    await msgRef.update(updatePayload);

    // Update chat lastMessageText if this was the last message
    final chatDoc = await _db.collection('chats').doc(chatId).get();
    if (chatDoc.exists) {
      final chatData = chatDoc.data()!;
      final Timestamp? lastTime = chatData['lastMessageTime'] as Timestamp?;
      final Timestamp? msgTime = data['timestamp'] as Timestamp? ?? data['createdAt'] as Timestamp?;
      if (lastTime != null && msgTime != null && lastTime.millisecondsSinceEpoch == msgTime.millisecondsSinceEpoch) {
        await _db.collection('chats').doc(chatId).update({
          'lastMessageText': newText,
        });
      }
    }
  }

  // Delete message for everyone (only allowed for own messages)
  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
    required String senderId,
  }) async {
    final msgRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final msgSnap = await msgRef.get();
    if (!msgSnap.exists) return;

    final data = msgSnap.data()!;
    if (data['senderId'] != senderId) {
      throw Exception("Unauthorized: You can only delete your own messages for everyone.");
    }

    await msgRef.update({
      'deleted': true,
      'deletedForEveryone': true,
      'text': 'This message was deleted',
      'url': '',
      'mediaUrl': '',
      'thumbnailUrl': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update chat preview if last message
    final chatDoc = await _db.collection('chats').doc(chatId).get();
    if (chatDoc.exists) {
      final chatData = chatDoc.data()!;
      final Timestamp? lastTime = chatData['lastMessageTime'] as Timestamp?;
      final Timestamp? msgTime = data['timestamp'] as Timestamp? ?? data['createdAt'] as Timestamp?;
      if (lastTime != null && msgTime != null && lastTime.millisecondsSinceEpoch == msgTime.millisecondsSinceEpoch) {
        await _db.collection('chats').doc(chatId).update({
          'lastMessageText': 'This message was deleted',
        });
      }
    }
  }

  // Delete message for current user ("Delete for me")
  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String currentUserId,
  }) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'deletedBy': FieldValue.arrayUnion([currentUserId]),
    });
  }

  // Vote on poll
  Future<void> votePoll({
    required String chatId,
    required String messageId,
    required String optionText,
    required String userId,
  }) async {
    final msgRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    final snap = await msgRef.get();
    if (!snap.exists) return;
    final data = snap.data()!;
    final votes = Map<String, dynamic>.from(data['pollVotes'] ?? {});
    List<String> voters = List<String>.from(votes[optionText] ?? []);
    if (voters.contains(userId)) {
      voters.remove(userId);
    } else {
      // In single vote mode, remove from other options first
      votes.forEach((key, list) {
        if (list is List) {
          list.remove(userId);
        }
      });
      voters.add(userId);
    }
    votes[optionText] = voters;
    await msgRef.update({'pollVotes': votes});
  }

  // Save/update user FCM token
  Future<void> saveUserFcmToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error updating FCM token: $e");
    }
  }

  // Update chat typing status
  Future<void> updateChatTypingStatus(String chatId, String userId, String state) async {
    await _db.collection('chats').doc(chatId).update({
      'typingStatus.$userId': state,
    });
  }

  // Clear unread counts for a user
  Future<void> clearUnreadCount(String chatId, String userId) async {
    await _db.collection('chats').doc(chatId).update({
      'unreadCounts.$userId': 0,
    });
  }

  // Mark message as delivered (double check)
  Future<void> markMessageDelivered(String chatId, String messageId, String recipientUid) async {
    try {
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'deliveredTo': FieldValue.arrayUnion([recipientUid]),
      });
    } catch (e) {
      debugPrint('[DatabaseService] markMessageDelivered notice: $e');
    }
  }

  // Mark message as read (Read receipts)
  Future<void> markMessageAsRead(String chatId, String messageId, String userId) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'readBy': FieldValue.arrayUnion([userId]),
      'deliveredTo': FieldValue.arrayUnion([userId]),
    });
  }

  // --- Strictly Private Per-Contact Nicknames ---
  // User A sets a nickname for User B -> ONLY User A sees it. User B NEVER sees it.

  // Stream private nicknames mapped by targetUid
  Stream<Map<String, String>> streamNicknames(String currentUid) {
    if (currentUid.isEmpty) return Stream.value({});
    return _db
        .collection('users')
        .doc(currentUid)
        .collection('privateNicknames')
        .snapshots()
        .asyncMap((snapshot) async {
      final Map<String, String> map = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final nickname = data['nickname']?.toString().trim();
        if (nickname != null && nickname.isNotEmpty) {
          map[doc.id] = nickname;
        }
      }
      // Also fallback to legacy nicknames if any
      if (map.isEmpty) {
        final legacySnap = await _db
            .collection('users')
            .doc(currentUid)
            .collection('nicknames')
            .get();
        for (var doc in legacySnap.docs) {
          final data = doc.data();
          final nickname = data['nickname']?.toString().trim();
          if (nickname != null && nickname.isNotEmpty) {
            map[doc.id] = nickname;
          }
        }
      }
      return map;
    });
  }

  // Set private / mutual contact nickname
  Future<void> setNickname({
    required String currentUid,
    required String targetUid,
    required String nickname,
    String? chatId,
  }) async {
    final cleanNickname = nickname.trim();
    final resolvedChatId = (chatId != null && chatId.isNotEmpty)
        ? chatId
        : (currentUid.compareTo(targetUid) < 0 ? '${currentUid}_$targetUid' : '${targetUid}_$currentUid');

    if (cleanNickname.isEmpty) {
      await deleteNickname(currentUid: currentUid, targetUid: targetUid, chatId: resolvedChatId);
      return;
    }

    final myKey = '${currentUid}_for_$targetUid';

    // 1. Store in shared 1-to-1 chat document (accessible in realtime by A and B, hidden from C)
    await _db.collection('chats').doc(resolvedChatId).set({
      'mutualNicknames': {
        myKey: cleanNickname,
      }
    }, SetOptions(merge: true));

    // 2. Also keep personal contact doc for backward compatibility
    final privateDocRef = _db
        .collection('users')
        .doc(currentUid)
        .collection('privateNicknames')
        .doc(targetUid);
    await privateDocRef.set({
      'targetUid': targetUid,
      'nickname': cleanNickname,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Remove private / mutual contact nickname
  Future<void> deleteNickname({
    required String currentUid,
    required String targetUid,
    String? chatId,
  }) async {
    final resolvedChatId = (chatId != null && chatId.isNotEmpty)
        ? chatId
        : (currentUid.compareTo(targetUid) < 0 ? '${currentUid}_$targetUid' : '${targetUid}_$currentUid');

    final myKey = '${currentUid}_for_$targetUid';

    // Remove from chat document
    try {
      await _db.collection('chats').doc(resolvedChatId).update({
        'mutualNicknames.$myKey': FieldValue.delete(),
      });
    } catch (_) {}

    // Remove from private collection
    await _db
        .collection('users')
        .doc(currentUid)
        .collection('privateNicknames')
        .doc(targetUid)
        .delete();
  }

  // Stream Instagram-like mutual nicknames (A sees what A set for B, and what B set for A; C sees neither)
  Stream<MutualNicknameInfo> streamMutualNicknames({
    required String currentUid,
    required String otherUid,
    String? chatId,
  }) {
    if (currentUid.isEmpty || otherUid.isEmpty) {
      return Stream.value(const MutualNicknameInfo());
    }

    final resolvedChatId = (chatId != null && chatId.isNotEmpty)
        ? chatId
        : (currentUid.compareTo(otherUid) < 0 ? '${currentUid}_$otherUid' : '${otherUid}_$currentUid');

    return _db
        .collection('chats')
        .doc(resolvedChatId)
        .snapshots()
        .map((chatSnap) {
      String? myNick;
      String? otherNick;

      if (chatSnap.exists) {
        final data = chatSnap.data();
        final raw = data?['mutualNicknames'];
        if (raw is Map) {
          final myKey = '${currentUid}_for_$otherUid';
          final otherKey = '${otherUid}_for_$currentUid';
          final val1 = raw[myKey]?.toString().trim();
          final val2 = raw[otherKey]?.toString().trim();
          if (val1 != null && val1.isNotEmpty) myNick = val1;
          if (val2 != null && val2.isNotEmpty) otherNick = val2;
        }
      }

      return MutualNicknameInfo(
        nicknameGivenByMe: myNick,
        nicknameGivenToMe: otherNick,
      );
    });
  }

  // --- Follow-to-Chat Relationship System ---

  Future<void> sendFollowRequest(String fromUid, String toUid) async {
    final relId = RelationshipModel.generateId(fromUid, toUid);
    await _db.collection('relationships').doc(relId).set({
      'relationshipId': relId,
      'fromUid': fromUid,
      'toUid': toUid,
      'status': RelationshipStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptFollowRequest(String fromUid, String toUid) async {
    final relId = RelationshipModel.generateId(fromUid, toUid);
    await _db.collection('relationships').doc(relId).set({
      'relationshipId': relId,
      'fromUid': fromUid,
      'toUid': toUid,
      'status': RelationshipStatus.accepted.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> rejectFollowRequest(String fromUid, String toUid) async {
    final relId = RelationshipModel.generateId(fromUid, toUid);
    await _db.collection('relationships').doc(relId).delete();
  }

  Future<void> unfollow(String fromUid, String toUid) async {
    final relId = RelationshipModel.generateId(fromUid, toUid);
    await _db.collection('relationships').doc(relId).delete();
  }

  Future<void> blockUserRelationship(String fromUid, String toUid) async {
    final relId = RelationshipModel.generateId(fromUid, toUid);
    await _db.collection('relationships').doc(relId).set({
      'relationshipId': relId,
      'fromUid': fromUid,
      'toUid': toUid,
      'status': RelationshipStatus.blocked.name,
      'blockedBy': fromUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unblockUserRelationship(String fromUid, String toUid) async {
    final relId = RelationshipModel.generateId(fromUid, toUid);
    await _db.collection('relationships').doc(relId).delete();
  }

  Stream<RelationshipModel?> streamRelationship(String uid1, String uid2) {
    final relId = RelationshipModel.generateId(uid1, uid2);
    return _db.collection('relationships').doc(relId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return RelationshipModel.fromMap(snap.data()!, snap.id);
    });
  }

  Future<void> setSharedRelationshipNickname(String uid1, String uid2, String nickname) async {
    final relId = RelationshipModel.generateId(uid1, uid2);
    final docRef = _db.collection('relationships').doc(relId);
    await docRef.set({
      'relationshipId': relId,
      'sharedNickname': nickname.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<RelationshipModel>> streamIncomingFollowRequests(String toUid) {
    return _db
        .collection('relationships')
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: RelationshipStatus.pending.name)
        .snapshots()
        .map((snap) => snap.docs.map((d) => RelationshipModel.fromMap(d.data(), d.id)).toList());
  }

  // Check whether a user is authorized to initiate or open chat with another user
  Future<bool> canUserChat(String currentUid, String otherUid) async {
    // 1. Check if symmetric relationship is accepted
    final relId = RelationshipModel.generateId(currentUid, otherUid);
    final snap = await _db.collection('relationships').doc(relId).get();
    if (snap.exists && snap.data()?['status'] == RelationshipStatus.accepted.name) {
      return true;
    }

    // 2. Existing authorized chats continue working safely
    final existingChatId = currentUid.compareTo(otherUid) < 0
        ? '${currentUid}_$otherUid'
        : '${otherUid}_$currentUid';
    final chatSnap = await _db.collection('chats').doc(existingChatId).get();
    if (chatSnap.exists) {
      return true;
    }

    return false;
  }

  // --- Message Reactions ---

  // Toggle emoji reaction on message (add, replace, or remove if same)
  Future<void> toggleMessageReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final msgRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final snap = await msgRef.get();
    if (!snap.exists) return;

    final data = snap.data() ?? {};
    final reactions = Map<String, String>.from(
      (data['reactions'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {},
    );

    if (reactions[userId] == emoji) {
      // Tapping same emoji removes reaction
      reactions.remove(userId);
    } else {
      // Add or change to new reaction
      reactions[userId] = emoji;
    }

    await msgRef.update({'reactions': reactions});
  }

  // --- Bulk Deletion (up to 999 messages) ---

  Future<void> bulkDeleteMessages({
    required String chatId,
    required List<MessageModel> messages,
    required bool forEveryone,
    required String currentUserId,
  }) async {
    if (messages.isEmpty) return;
    const int batchLimit = 400; // Chunk safely below Firestore's 500 limit
    for (int i = 0; i < messages.length; i += batchLimit) {
      final chunk = messages.sublist(
        i,
        (i + batchLimit < messages.length) ? i + batchLimit : messages.length,
      );
      final batch = _db.batch();
      for (final msg in chunk) {
        final docRef = _db.collection('chats').doc(chatId).collection('messages').doc(msg.id);
        if (forEveryone) {
          if (msg.senderId == currentUserId) {
            batch.update(docRef, {
              'deleted': true,
              'deletedForEveryone': true,
              'text': 'This message was deleted',
              'url': '',
              'mediaUrl': '',
              'thumbnailUrl': '',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } else {
          batch.update(docRef, {
            'deletedBy': FieldValue.arrayUnion([currentUserId]),
          });
        }
      }
      await batch.commit();
    }
  }

  // --- Clear Chat (Per-User) ---

  Future<void> clearChatForUser(String chatId, String currentUserId) async {
    await _db.collection('chats').doc(chatId).update({
      'clearedAtBy.$currentUserId': FieldValue.serverTimestamp(),
    });
  }

  // --- Shared Chat Theme / Wallpaper ---

  // Update shared wallpaper for all participants in a chat (Built-in)
  Future<void> updateChatWallpaper({
    required String chatId,
    required String wallpaperId,
  }) async {
    await _db.collection('chats').doc(chatId).update({
      'wallpaperType': 'builtin',
      'wallpaperId': wallpaperId,
      'wallpaperUrl': '',
      'wallpaperUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateChatWallpaperBuiltin({
    required String chatId,
    required String wallpaperId,
    required String updatedBy,
  }) async {
    await _db.collection('chats').doc(chatId).update({
      'wallpaperType': 'builtin',
      'wallpaperId': wallpaperId,
      'wallpaperUrl': '',
      'wallpaperUpdatedBy': updatedBy,
      'wallpaperUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateChatWallpaperGallery({
    required String chatId,
    required String wallpaperUrl,
    required String updatedBy,
  }) async {
    await _db.collection('chats').doc(chatId).update({
      'wallpaperType': 'gallery',
      'wallpaperId': 'custom_gallery',
      'wallpaperUrl': wallpaperUrl,
      'wallpaperUpdatedBy': updatedBy,
      'wallpaperUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Stream a single chat document for real-time metadata (theme, typing, unread counts)
  Stream<ChatModel?> streamChat(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ChatModel.fromMap(doc.data()!);
    });
  }

  // --- WhatsApp-style Status / Updates ---

  Future<void> createStatus(StatusModel status) async {
    await _db.collection('statuses').doc(status.statusId).set(status.toMap());
  }

  // Delete status permanently (only owner can delete)
  Future<void> deleteStatus(String statusId, String currentUid) async {
    final docRef = _db.collection('statuses').doc(statusId);
    final doc = await docRef.get();
    if (doc.exists && doc.data()?['userId'] == currentUid) {
      await docRef.delete();
    }
  }

  Stream<List<StatusModel>> streamActiveStatuses() {
    return _db
        .collection('statuses')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => StatusModel.fromMap(doc.data(), doc.id))
          .where((s) => !s.isExpired)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Update user mood
  Future<void> updateMood(String uid, String moodEmoji, dynamic moodColor) async {
    final int colorVal;
    if (moodColor is int) {
      colorVal = moodColor;
    } else if (moodColor is String && (moodColor.startsWith('0x') || moodColor.startsWith('0X'))) {
      colorVal = int.tryParse(moodColor.substring(2), radix: 16) ?? 0xFFD4AF37;
    } else {
      colorVal = int.tryParse(moodColor.toString()) ?? 0xFFD4AF37;
    }

    await _db.collection('users').doc(uid).update({
      'moodEmoji': moodEmoji,
      'moodColor': colorVal,
    });
    if (_userCache.containsKey(uid)) {
      _userCache[uid] = _userCache[uid]!.copyWith(
        moodEmoji: moodEmoji,
        moodColor: colorVal,
      );
    }
  }

  // Submit anonymous Q&A question to a user's status inbox
  Future<void> submitAnonymousQuestion({
    required String authorUid,
    required AnonymousQAModel question,
  }) async {
    await _db
        .collection('users')
        .doc(authorUid)
        .collection('questions')
        .doc(question.id)
        .set(question.toMap());
  }

  // Stream anonymous questions for status author
  Stream<List<AnonymousQAModel>> streamAnonymousQuestions(String authorUid) {
    return _db
        .collection('users')
        .doc(authorUid)
        .collection('questions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => AnonymousQAModel.fromMap(doc.data(), doc.id)).toList());
  }

  // Answer anonymous question
  Future<void> answerAnonymousQuestion({
    required String authorUid,
    required String questionId,
    required String answer,
  }) async {
    await _db
        .collection('users')
        .doc(authorUid)
        .collection('questions')
        .doc(questionId)
        .update({
      'answer': answer,
      'isAnswered': true,
    });
  }
}
