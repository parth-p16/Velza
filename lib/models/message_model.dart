import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, video, audio, document, sticker, quickPing, poll, scheduled, playlist, gift }

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String chatId;
  final String text;
  final MessageType type;
  final String url; // For media attachments (maps to mediaUrl)
  final String thumbnailUrl; // For video preview
  final String fileName; // For documents
  final int audioDuration; // Duration in seconds for audio messages
  final String? stickerId; // Unique identifier for sticker message
  final Map<String, String> reactions; // Map of uid -> emoji reaction
  final DateTime timestamp; // Creation timestamp (maps to createdAt)
  final DateTime? updatedAt;
  final bool edited;
  final bool deleted;
  final bool deletedForEveryone;
  final List<String> deletedBy; // User UIDs who deleted message for themselves
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderId;
  final String? replyToSenderName;
  final List<String> readBy; // List of UIDs who have read the message
  final List<String> deliveredTo; // List of UIDs who received the message
  final bool isSending; // Transient local flag for optimistic UI
  final bool isFailed; // Transient local flag for failed network dispatch

  // Phase 2 feature fields
  final String? quickPingEmoji;
  final String? quickPingLabel;
  final String? pollQuestion;
  final List<String>? pollOptions;
  final Map<String, List<String>>? pollVotes; // option -> List of uids
  final DateTime? scheduledFor;
  final String? playlistName;
  final List<Map<String, String>>? playlistTracks;

  // Mentions
  final List<String> mentionedUserIds;
  final Map<String, String>? mentions; // uid -> name

  // Gift / Surprise message fields
  final String? giftPayload; // hidden surprise text
  final bool isGiftOpened;
  final DateTime? openedAt;
  final String? giftOpenedBy;

  // E2EE flag
  final bool isEncrypted;

  // Convenient aliases requested by specifications
  String get messageId => id;
  String get mediaUrl => url;
  DateTime get createdAt => timestamp;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.chatId = '',
    required this.text,
    required this.type,
    this.url = '',
    this.thumbnailUrl = '',
    this.fileName = '',
    this.audioDuration = 0,
    this.stickerId,
    this.reactions = const {},
    required this.timestamp,
    this.updatedAt,
    this.edited = false,
    this.deleted = false,
    this.deletedForEveryone = false,
    this.deletedBy = const [],
    this.replyToMessageId,
    this.replyToText,
    this.replyToSenderId,
    this.replyToSenderName,
    this.readBy = const [],
    this.deliveredTo = const [],
    this.isSending = false,
    this.isFailed = false,
    this.quickPingEmoji,
    this.quickPingLabel,
    this.pollQuestion,
    this.pollOptions,
    this.pollVotes,
    this.scheduledFor,
    this.playlistName,
    this.playlistTracks,
    this.mentionedUserIds = const [],
    this.mentions,
    this.giftPayload,
    this.isGiftOpened = false,
    this.openedAt,
    this.giftOpenedBy,
    this.isEncrypted = false,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawType = (map['type'] ?? 'text').toString();

    // Parse poll votes
    Map<String, List<String>>? parsedVotes;
    if (map['pollVotes'] is Map) {
      parsedVotes = {};
      (map['pollVotes'] as Map).forEach((k, v) {
        if (v is List) {
          parsedVotes![k.toString()] = List<String>.from(v.map((e) => e.toString()));
        }
      });
    }

    // Parse playlist tracks
    List<Map<String, String>>? parsedTracks;
    if (map['playlistTracks'] is List) {
      parsedTracks = (map['playlistTracks'] as List)
          .map((item) => Map<String, String>.from((item as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
          .toList();
    }

    return MessageModel(
      id: (map['messageId'] ?? map['id'] ?? '').toString(),
      senderId: (map['senderId'] ?? '').toString(),
      senderName: (map['senderName'] ?? '').toString(),
      chatId: (map['chatId'] ?? map['receiverId'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      type: MessageType.values.firstWhere(
        (e) => e.name == rawType || e.toString().split('.').last == rawType,
        orElse: () => MessageType.text,
      ),
      url: (map['mediaUrl'] ?? map['url'] ?? '').toString(),
      thumbnailUrl: (map['thumbnailUrl'] ?? '').toString(),
      fileName: (map['fileName'] ?? '').toString(),
      audioDuration: map['audioDuration'] is num
          ? (map['audioDuration'] as num).toInt()
          : int.tryParse(map['audioDuration']?.toString() ?? '0') ?? 0,
      stickerId: map['stickerId']?.toString(),
      reactions: Map<String, String>.from(
        (map['reactions'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {},
      ),
      timestamp: map['createdAt'] != null
          ? parseDate(map['createdAt'])
          : (map['timestamp'] != null ? parseDate(map['timestamp']) : DateTime.now()),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
      edited: map['edited'] == true,
      deleted: map['deleted'] == true,
      deletedForEveryone: map['deletedForEveryone'] == true,
      deletedBy: (map['deletedBy'] as List?)?.map((e) => e.toString()).toList() ?? [],
      replyToMessageId: map['replyToMessageId']?.toString(),
      replyToText: map['replyToText']?.toString(),
      replyToSenderId: map['replyToSenderId']?.toString(),
      replyToSenderName: map['replyToSenderName']?.toString(),
      readBy: (map['readBy'] as List?)?.map((e) => e.toString()).toList() ?? [],
      deliveredTo: (map['deliveredTo'] as List?)?.map((e) => e.toString()).toList() ?? [],
      quickPingEmoji: map['quickPingEmoji']?.toString(),
      quickPingLabel: map['quickPingLabel']?.toString(),
      pollQuestion: map['pollQuestion']?.toString(),
      pollOptions: (map['pollOptions'] as List?)?.map((e) => e.toString()).toList(),
      pollVotes: parsedVotes,
      scheduledFor: map['scheduledFor'] != null ? parseDate(map['scheduledFor']) : null,
      playlistName: map['playlistName']?.toString(),
      playlistTracks: parsedTracks,
      mentionedUserIds: (map['mentionedUserIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      mentions: map['mentions'] != null
          ? Map<String, String>.from((map['mentions'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())))
          : null,
      giftPayload: map['giftPayload']?.toString(),
      isGiftOpened: map['isGiftOpened'] == true,
      openedAt: map['openedAt'] != null ? parseDate(map['openedAt']) : null,
      giftOpenedBy: map['giftOpenedBy']?.toString(),
      isEncrypted: map['isEncrypted'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'messageId': id,
      'senderId': senderId,
      'senderName': senderName,
      'chatId': chatId,
      'receiverId': chatId,
      'text': text,
      'type': type.name,
      'url': url,
      'mediaUrl': url,
      'thumbnailUrl': thumbnailUrl,
      'fileName': fileName,
      'audioDuration': audioDuration,
      if (isEncrypted) 'isEncrypted': true,
      if (stickerId != null) 'stickerId': stickerId,
      if (reactions.isNotEmpty) 'reactions': reactions,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(timestamp),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'edited': edited,
      'deleted': deleted,
      'deletedForEveryone': deletedForEveryone,
      'deletedBy': deletedBy,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSenderId != null) 'replyToSenderId': replyToSenderId,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
      'readBy': readBy,
      'deliveredTo': deliveredTo,
      if (quickPingEmoji != null) 'quickPingEmoji': quickPingEmoji,
      if (quickPingLabel != null) 'quickPingLabel': quickPingLabel,
      if (pollQuestion != null) 'pollQuestion': pollQuestion,
      if (pollOptions != null) 'pollOptions': pollOptions,
      if (pollVotes != null) 'pollVotes': pollVotes,
      if (scheduledFor != null) 'scheduledFor': Timestamp.fromDate(scheduledFor!),
      if (playlistName != null) 'playlistName': playlistName,
      if (playlistTracks != null) 'playlistTracks': playlistTracks,
      if (mentionedUserIds.isNotEmpty) 'mentionedUserIds': mentionedUserIds,
      if (mentions != null && mentions!.isNotEmpty) 'mentions': mentions,
      if (giftPayload != null) 'giftPayload': giftPayload,
      'isGiftOpened': isGiftOpened,
      if (openedAt != null) 'openedAt': Timestamp.fromDate(openedAt!),
      if (giftOpenedBy != null) 'giftOpenedBy': giftOpenedBy,
    };
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? chatId,
    String? text,
    MessageType? type,
    String? url,
    String? thumbnailUrl,
    String? fileName,
    int? audioDuration,
    String? stickerId,
    Map<String, String>? reactions,
    DateTime? timestamp,
    DateTime? updatedAt,
    bool? edited,
    bool? deleted,
    bool? deletedForEveryone,
    List<String>? deletedBy,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
    List<String>? readBy,
    List<String>? deliveredTo,
    bool? isSending,
    bool? isFailed,
    List<String>? mentionedUserIds,
    Map<String, String>? mentions,
    String? giftPayload,
    bool? isGiftOpened,
    DateTime? openedAt,
    String? giftOpenedBy,
    bool? isEncrypted,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      chatId: chatId ?? this.chatId,
      text: text ?? this.text,
      type: type ?? this.type,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fileName: fileName ?? this.fileName,
      audioDuration: audioDuration ?? this.audioDuration,
      stickerId: stickerId ?? this.stickerId,
      reactions: reactions ?? this.reactions,
      timestamp: timestamp ?? this.timestamp,
      updatedAt: updatedAt ?? this.updatedAt,
      edited: edited ?? this.edited,
      deleted: deleted ?? this.deleted,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
      deletedBy: deletedBy ?? this.deletedBy,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      readBy: readBy ?? this.readBy,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      isSending: isSending ?? this.isSending,
      isFailed: isFailed ?? this.isFailed,
      quickPingEmoji: quickPingEmoji,
      quickPingLabel: quickPingLabel,
      pollQuestion: pollQuestion,
      pollOptions: pollOptions,
      pollVotes: pollVotes,
      scheduledFor: scheduledFor,
      playlistName: playlistName,
      playlistTracks: playlistTracks,
      mentionedUserIds: mentionedUserIds ?? this.mentionedUserIds,
      mentions: mentions ?? this.mentions,
      giftPayload: giftPayload ?? this.giftPayload,
      isGiftOpened: isGiftOpened ?? this.isGiftOpened,
      openedAt: openedAt ?? this.openedAt,
      giftOpenedBy: giftOpenedBy ?? this.giftOpenedBy,
      isEncrypted: isEncrypted ?? this.isEncrypted,
    );
  }

  MessageDeliveryStatus getDeliveryStatus({
    String? otherUserId,
    bool readReceiptsEnabled = true,
  }) {
    if (isFailed) return MessageDeliveryStatus.failed;
    if (isSending) return MessageDeliveryStatus.sending;

    final targetUid = otherUserId;
    final isRead = targetUid != null
        ? (readBy.contains(targetUid) && readReceiptsEnabled)
        : (readBy.length > 1 && readReceiptsEnabled);
    if (isRead) return MessageDeliveryStatus.read;

    final isDelivered = targetUid != null
        ? (deliveredTo.contains(targetUid) || readBy.contains(targetUid))
        : (deliveredTo.isNotEmpty || readBy.length > 1);
    if (isDelivered) return MessageDeliveryStatus.delivered;

    return MessageDeliveryStatus.sent;
  }
}

enum MessageDeliveryStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}
