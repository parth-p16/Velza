import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:velza/models/chat_model.dart';
import 'package:velza/models/message_model.dart';
import 'package:velza/models/user_model.dart';
import 'package:velza/models/relationship_model.dart';
import 'package:velza/services/database_service.dart';
import 'package:velza/services/storage_service.dart';
import 'package:velza/services/wallpaper_service.dart';

class ChatViewModel extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final StorageService _storageService = StorageService();

  final List<ChatModel> _chats = [];
  final List<MessageModel> _messages = [];
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  Map<String, String> _nicknames = {};
  StreamSubscription<Map<String, String>>? _nicknameSubscription;
  String? _subscribedUid;

  List<ChatModel> get chats => _chats;
  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  double get uploadProgress => _uploadProgress;
  Map<String, String> get nicknames => _nicknames;
  StorageService get storageService => _storageService;

  // --- Active Chat Stream Binding ---
  
  Stream<List<ChatModel>> streamUserChats(String uid) {
    return _dbService.streamUserChats(uid);
  }

  Stream<List<MessageModel>> streamMessages(String chatId, [String? currentUserId, DateTime? clearedAt]) {
    return _dbService.streamMessages(chatId, currentUserId, clearedAt);
  }

  Stream<UserModel> streamUserProfile(String uid) {
    return _dbService.streamUserProfile(uid);
  }

  // --- Actions ---

  // Clear unread messages count
  Future<void> clearUnreadCount(String chatId, String userId) async {
    await _dbService.clearUnreadCount(chatId, userId);
  }

  // Send Text Message
  Future<void> sendTextMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    bool isEncrypted = false,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
    List<String>? mentionedUserIds,
    Map<String, String>? mentions,
  }) async {
    if (text.trim().isEmpty) return;
    
    final String messageId = const Uuid().v4();
    final message = MessageModel(
      id: messageId,
      senderId: senderId,
      senderName: senderName,
      chatId: chatId,
      text: text.trim(),
      type: MessageType.text,
      url: '',
      fileName: '',
      timestamp: DateTime.now(),
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      replyToSenderId: replyToSenderId,
      replyToSenderName: replyToSenderName,
      readBy: [senderId],
      mentionedUserIds: mentionedUserIds ?? const [],
      mentions: mentions,
      isEncrypted: isEncrypted,
    );

    await _dbService.sendMessage(chatId, message);
  }

  // Send Scheduled Gift / Surprise Message 🎁
  Future<void> sendGiftMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String surpriseText,
    required DateTime scheduledFor,
  }) async {
    final message = MessageModel(
      id: const Uuid().v4(),
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      text: '🎁 Surprise Message',
      type: MessageType.gift,
      timestamp: DateTime.now(),
      scheduledFor: scheduledFor,
      giftPayload: surpriseText.trim(),
      isGiftOpened: false,
      readBy: [senderId],
    );
    await _dbService.sendMessage(chatId, message);
  }

  // Open Gift Message
  Future<void> openGiftMessage({
    required String chatId,
    required String messageId,
    required String userId,
    String? revealedText,
  }) async {
    await _dbService.openGiftMessage(
      chatId: chatId,
      messageId: messageId,
      userId: userId,
      revealedText: revealedText,
    );
  }

  // Send Media Message (Image, Video, Document)
  Future<void> sendMediaMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required File file,
    required MessageType type,
    String? customFileName,
    String? caption,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
  }) async {
    _isLoading = true;
    _uploadProgress = 0.0;
    notifyListeners();

    try {
      final String messageId = const Uuid().v4();
      final String extension = file.path.split('.').last;
      
      String folderName = 'images';
      if (type == MessageType.video) folderName = 'videos';
      if (type == MessageType.document) folderName = 'documents';

      final String downloadUrl = await _storageService.uploadChatMedia(
        chatId: chatId,
        messageId: messageId,
        file: file,
        fileExtension: extension,
        type: folderName,
        onProgress: (progress) {
          _uploadProgress = progress;
          notifyListeners();
        },
      );

      final messageText = (caption != null && caption.trim().isNotEmpty)
          ? caption.trim()
          : (customFileName ?? '${type.name} message');

      final message = MessageModel(
        id: messageId,
        senderId: senderId,
        senderName: senderName,
        chatId: chatId,
        text: messageText,
        type: type,
        url: downloadUrl,
        fileName: customFileName ?? file.path.split(Platform.pathSeparator).last,
        timestamp: DateTime.now(),
        replyToMessageId: replyToMessageId,
        replyToText: replyToText,
        replyToSenderId: replyToSenderId,
        replyToSenderName: replyToSenderName,
        readBy: [senderId],
      );

      await _dbService.sendMessage(chatId, message);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      _uploadProgress = 0.0;
      notifyListeners();
    }
  }

  // Send Voice Note (Audio)
  Future<void> sendVoiceNote({
    required String chatId,
    required String senderId,
    required String senderName,
    required File file,
    int audioDuration = 0,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
  }) async {
    _isLoading = true;
    _uploadProgress = 0.0;
    notifyListeners();

    try {
      final String messageId = const Uuid().v4();
      
      final String downloadUrl = await _storageService.uploadChatMedia(
        chatId: chatId,
        messageId: messageId,
        file: file,
        fileExtension: 'm4a',
        type: 'voice',
        onProgress: (progress) {
          _uploadProgress = progress;
          notifyListeners();
        },
      );

      final message = MessageModel(
        id: messageId,
        senderId: senderId,
        senderName: senderName,
        chatId: chatId,
        text: 'Voice message',
        type: MessageType.audio,
        url: downloadUrl,
        fileName: 'voice.m4a',
        audioDuration: audioDuration,
        timestamp: DateTime.now(),
        replyToMessageId: replyToMessageId,
        replyToText: replyToText,
        replyToSenderId: replyToSenderId,
        replyToSenderName: replyToSenderName,
        readBy: [senderId],
      );

      await _dbService.sendMessage(chatId, message);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      _uploadProgress = 0.0;
      notifyListeners();
    }
  }

  // Generic send message
  Future<void> sendMessage(String chatId, MessageModel message) async {
    await _dbService.sendMessage(chatId, message);
  }

  // Send Quick Ping
  Future<void> sendQuickPing({
    required String chatId,
    required String senderId,
    required String senderName,
    required String emoji,
    required String label,
  }) async {
    final message = MessageModel(
      id: const Uuid().v4(),
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      text: '$emoji $label',
      type: MessageType.quickPing,
      timestamp: DateTime.now(),
      quickPingEmoji: emoji,
      quickPingLabel: label,
      readBy: [senderId],
    );
    await _dbService.sendMessage(chatId, message);
  }

  // Send Group Poll
  Future<void> sendPoll({
    required String chatId,
    required String senderId,
    required String senderName,
    required String question,
    required List<String> options,
  }) async {
    final message = MessageModel(
      id: const Uuid().v4(),
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      text: question,
      type: MessageType.poll,
      timestamp: DateTime.now(),
      pollQuestion: question,
      pollOptions: options,
      pollVotes: {},
      readBy: [senderId],
    );
    await _dbService.sendMessage(chatId, message);
  }

  // Send Scheduled Time Capsule Message
  Future<void> sendScheduledMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    required DateTime scheduledFor,
  }) async {
    final message = MessageModel(
      id: const Uuid().v4(),
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      text: text,
      type: MessageType.scheduled,
      timestamp: DateTime.now(),
      scheduledFor: scheduledFor,
      readBy: [senderId],
    );
    await _dbService.sendMessage(chatId, message);
  }

  // Send Shared Playlist card
  Future<void> sendPlaylistCard({
    required String chatId,
    required String senderId,
    required String senderName,
    required String playlistName,
    required List<String> tracks,
  }) async {
    final message = MessageModel(
      id: const Uuid().v4(),
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      text: '🎵 $playlistName',
      type: MessageType.playlist,
      timestamp: DateTime.now(),
      playlistName: playlistName,
      playlistTracks: tracks.map((t) => {'title': t, 'artist': 'Unknown'}).toList(),
      readBy: [senderId],
    );
    await _dbService.sendMessage(chatId, message);
  }

  // Edit Text Message
  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String senderId,
    required String newText,
    bool isEncrypted = false,
  }) async {
    await _dbService.editMessage(
      chatId: chatId,
      messageId: messageId,
      senderId: senderId,
      newText: newText,
      isEncrypted: isEncrypted,
    );
  }

  // Vote on group poll
  Future<void> votePoll({
    required String chatId,
    required String messageId,
    required String optionText,
    required String userId,
  }) async {
    await _dbService.votePoll(
      chatId: chatId,
      messageId: messageId,
      optionText: optionText,
      userId: userId,
    );
  }

  // Delete message for everyone
  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
    required String senderId,
  }) async {
    await _dbService.deleteMessageForEveryone(
      chatId: chatId,
      messageId: messageId,
      senderId: senderId,
    );
  }

  // Delete message for me
  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String currentUserId,
  }) async {
    await _dbService.deleteMessageForMe(
      chatId: chatId,
      messageId: messageId,
      currentUserId: currentUserId,
    );
  }

  // Bulk Delete up to 999 messages with automatic chunking
  Future<void> bulkDeleteMessages({
    required String chatId,
    required List<MessageModel> messages,
    required bool forEveryone,
    required String currentUserId,
  }) async {
    await _dbService.bulkDeleteMessages(
      chatId: chatId,
      messages: messages,
      forEveryone: forEveryone,
      currentUserId: currentUserId,
    );
  }

  // Clear Chat for current user
  Future<void> clearChat({
    required String chatId,
    required String currentUserId,
  }) async {
    await _dbService.clearChatForUser(chatId, currentUserId);
  }

  // Update built-in wallpaper
  Future<void> updateChatWallpaperBuiltin({
    required String chatId,
    required String wallpaperId,
    required String updatedBy,
  }) async {
    await _dbService.updateChatWallpaperBuiltin(
      chatId: chatId,
      wallpaperId: wallpaperId,
      updatedBy: updatedBy,
    );
  }

  // Upload and set gallery wallpaper
  Future<String> updateChatWallpaperGallery({
    required String chatId,
    required File imageFile,
    required String updatedBy,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final downloadUrl = await _storageService.uploadChatWallpaper(
        chatId: chatId,
        file: imageFile,
      );
      await _dbService.updateChatWallpaperGallery(
        chatId: chatId,
        wallpaperUrl: downloadUrl,
        updatedBy: updatedBy,
      );
      return downloadUrl;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch older messages for pagination
  Future<List<MessageModel>> fetchOlderMessages({
    required String chatId,
    required DateTime beforeTimestamp,
    int limit = 40,
    String? currentUserId,
    DateTime? clearedAt,
  }) async {
    return await _dbService.fetchOlderMessages(
      chatId: chatId,
      beforeTimestamp: beforeTimestamp,
      limit: limit,
      currentUserId: currentUserId,
      clearedAt: clearedAt,
    );
  }

  UserModel? getCachedUser(String uid) => _dbService.getCachedUser(uid);
  Future<UserModel?> fetchUserCached(String uid) => _dbService.fetchUserCached(uid);

  // Update chat specific typing status
  Future<void> updateChatTypingStatus(String chatId, String userId, String state) async {
    await _dbService.updateChatTypingStatus(chatId, userId, state);
  }

  // Mark message as read
  Future<void> markMessageAsRead(String chatId, String messageId, String userId) async {
    await _dbService.markMessageAsRead(chatId, messageId, userId);
  }

  // Mark message as delivered
  Future<void> markMessageDelivered(String chatId, String messageId, String recipientUid) async {
    await _dbService.markMessageDelivered(chatId, messageId, recipientUid);
  }

  // Retry sending a failed message
  Future<void> retryFailedMessage(String chatId, MessageModel message) async {
    final retried = message.copyWith(isSending: false, isFailed: false);
    await _dbService.sendMessage(chatId, retried);
  }

  // --- Follow-to-Chat Relationship Actions ---

  Future<void> sendFollowRequest(String fromUid, String toUid) async {
    await _dbService.sendFollowRequest(fromUid, toUid);
  }

  Future<void> acceptFollowRequest(String fromUid, String toUid) async {
    await _dbService.acceptFollowRequest(fromUid, toUid);
  }

  Future<void> rejectFollowRequest(String fromUid, String toUid) async {
    await _dbService.rejectFollowRequest(fromUid, toUid);
  }

  Future<void> unfollow(String fromUid, String toUid) async {
    await _dbService.unfollow(fromUid, toUid);
  }

  Future<void> blockUserRelationship(String fromUid, String toUid) async {
    await _dbService.blockUserRelationship(fromUid, toUid);
  }

  Future<void> unblockUserRelationship(String fromUid, String toUid) async {
    await _dbService.unblockUserRelationship(fromUid, toUid);
  }

  Stream<RelationshipModel?> streamRelationship(String fromUid, String toUid) {
    return _dbService.streamRelationship(fromUid, toUid);
  }

  Future<void> setSharedRelationshipNickname(String uid1, String uid2, String nickname) async {
    await _dbService.setSharedRelationshipNickname(uid1, uid2, nickname);
    notifyListeners();
  }

  Stream<List<RelationshipModel>> streamIncomingFollowRequests(String toUid) {
    return _dbService.streamIncomingFollowRequests(toUid);
  }

  Future<bool> canUserChat(String currentUid, String otherUid) async {
    return await _dbService.canUserChat(currentUid, otherUid);
  }

  // --- Personal Chat Wallpaper ---

  WallpaperModel getPersonalWallpaper(String uid, String chatId) {
    return WallpaperService().getPersonalWallpaper(uid, chatId);
  }

  Future<void> setPersonalWallpaper({
    required String uid,
    required String chatId,
    required WallpaperModel wallpaper,
  }) async {
    await WallpaperService().setPersonalWallpaper(
      uid: uid,
      chatId: chatId,
      wallpaper: wallpaper,
    );
    notifyListeners();
  }

  Future<WallpaperModel> savePersonalGalleryWallpaper({
    required String uid,
    required String chatId,
    required File file,
  }) async {
    final model = await WallpaperService().savePersonalGalleryWallpaper(
      uid: uid,
      chatId: chatId,
      sourceFile: file,
    );
    notifyListeners();
    return model;
  }

  // Start direct chat with user
  Future<String> startDirectChat({
    required UserModel currentUser,
    required UserModel otherUser,
  }) async {
    return await _dbService.getOrCreateOneToOneChat(
      currentUser.uid,
      otherUser.uid,
      currentUser.displayName,
      otherUser.displayName,
      currentUser.photoUrl,
      otherUser.photoUrl,
    );
  }

  // Create Group Chat
  Future<String> createGroupChat({
    required String name,
    required String photoUrl,
    required List<String> memberIds,
    required String creatorId,
  }) async {
    return await _dbService.createGroupChat(
      name: name,
      photoUrl: photoUrl,
      memberIds: memberIds,
      creatorId: creatorId,
    );
  }

  // Stream registered users (excluding ONLY current user's UID)
  Stream<List<UserModel>> streamRegisteredUsers(String currentUid) {
    return _dbService.streamRegisteredUsers(currentUid);
  }

  // Search for users (excluding ONLY current user's UID)
  Future<List<UserModel>> searchUsers(String query, String currentUid) async {
    return await _dbService.searchUsers(query, currentUid);
  }

  // Block User
  Future<void> blockUser(String currentUid, String blockUid) async {
    await _dbService.blockUser(currentUid, blockUid);
  }

  // Unblock User
  Future<void> unblockUser(String currentUid, String blockUid) async {
    await _dbService.unblockUser(currentUid, blockUid);
  }

  // Report User
  Future<void> reportUser(String currentUid, String reportUid, String reason) async {
    await _dbService.reportUser(currentUid, reportUid, reason);
  }

  // --- Private Per-Contact Nickname Management ---

  // Send Sticker Message (No Firebase Storage required)
  Future<void> sendStickerMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String stickerId,
    required String stickerAsset,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
  }) async {
    final String messageId = const Uuid().v4();
    final message = MessageModel(
      id: messageId,
      senderId: senderId,
      senderName: senderName,
      chatId: chatId,
      text: 'Sticker',
      type: MessageType.sticker,
      url: stickerAsset,
      thumbnailUrl: '',
      fileName: '',
      stickerId: stickerId,
      timestamp: DateTime.now(),
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      replyToSenderId: replyToSenderId,
      replyToSenderName: replyToSenderName,
      readBy: [senderId],
    );

    await _dbService.sendMessage(chatId, message);
  }

  // Toggle Message Reaction
  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await _dbService.toggleMessageReaction(
      chatId: chatId,
      messageId: messageId,
      userId: userId,
      emoji: emoji,
    );
  }

  // Update Shared Chat Wallpaper
  Future<void> updateChatWallpaper({
    required String chatId,
    required String wallpaperId,
  }) async {
    await _dbService.updateChatWallpaper(
      chatId: chatId,
      wallpaperId: wallpaperId,
    );
  }

  // Clear chat for current user
  Future<void> clearChatForUser(String chatId, String currentUserId) async {
    await _dbService.clearChatForUser(chatId, currentUserId);
  }

  // Stream single chat metadata in real-time
  Stream<ChatModel?> streamChat(String chatId) {
    return _dbService.streamChat(chatId);
  }

  // --- Mutual Nicknames Management ---
  Map<String, String> _nicknamesGivenToMe = {}; // Map of otherUid -> nickname they gave current user

  // Stream mutual nicknames in a 1-to-1 chat relationship
  Stream<MutualNicknameInfo> streamMutualNicknames({
    required String currentUid,
    required String otherUid,
    String? chatId,
  }) {
    return _dbService.streamMutualNicknames(
      currentUid: currentUid,
      otherUid: otherUid,
      chatId: chatId,
    );
  }

  // Get nickname that another user assigned to the current user
  String? getNicknameGivenToMe(String otherUid) {
    return _nicknamesGivenToMe[otherUid];
  }

  // Initialize and subscribe to current user's private nicknames stream
  void initNicknames(String currentUid) {
    if (currentUid.isEmpty || _subscribedUid == currentUid) return;
    _subscribedUid = currentUid;
    _nicknameSubscription?.cancel();
    _nicknameSubscription = _dbService.streamNicknames(currentUid).listen((map) {
      _nicknames = map;
      notifyListeners();
    });
  }

  // Get private nickname for contact if exists
  String? getNickname(String targetUid) {
    final name = _nicknames[targetUid];
    return (name != null && name.trim().isNotEmpty) ? name.trim() : null;
  }

  // Resolve effective display name: prefers private nickname if set, otherwise fallback
  String getEffectiveName(String targetUid, String fallbackName) {
    final nick = getNickname(targetUid);
    return (nick != null && nick.isNotEmpty) ? nick : fallbackName;
  }

  // Set or update mutual / private nickname
  Future<void> setNickname({
    required String currentUid,
    required String targetUid,
    required String nickname,
    String? chatId,
  }) async {
    await _dbService.setNickname(
      currentUid: currentUid,
      targetUid: targetUid,
      nickname: nickname,
      chatId: chatId,
    );
    // Optimistic local update
    if (nickname.trim().isEmpty) {
      _nicknames.remove(targetUid);
    } else {
      _nicknames[targetUid] = nickname.trim();
    }
    notifyListeners();
  }

  // Delete mutual / private nickname
  Future<void> deleteNickname({
    required String currentUid,
    required String targetUid,
    String? chatId,
  }) async {
    await _dbService.deleteNickname(
      currentUid: currentUid,
      targetUid: targetUid,
      chatId: chatId,
    );
    _nicknames.remove(targetUid);
    notifyListeners();
  }

  @visibleForTesting
  void updateNicknamesCacheForTest(Map<String, String> testNicknames) {
    _nicknames = Map.from(testNicknames);
    notifyListeners();
  }

  @visibleForTesting
  void updateNicknamesGivenToMeCacheForTest(Map<String, String> testNicknames) {
    _nicknamesGivenToMe = Map.from(testNicknames);
    notifyListeners();
  }

  @override
  void dispose() {
    _nicknameSubscription?.cancel();
    super.dispose();
  }
}
