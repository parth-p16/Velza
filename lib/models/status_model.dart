import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusType { text, image, video }

class StatusModel {
  final String statusId;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final StatusType type;
  final String text;
  final String mediaUrl;
  final String caption;
  final int backgroundColor; // Color value as int for text statuses
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewedBy;
  final String privacy; // 'contacts', 'everyone', 'selected'
  final bool isQA;
  final List<String> mentionedUserIds;
  final Map<String, String>? mentions; // uid -> name

  StatusModel({
    required this.statusId,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.type,
    this.text = '',
    this.mediaUrl = '',
    this.caption = '',
    this.backgroundColor = 0xFF6A1B9A,
    required this.createdAt,
    required this.expiresAt,
    this.viewedBy = const [],
    this.privacy = 'contacts',
    this.isQA = false,
    this.mentionedUserIds = const [],
    this.mentions,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory StatusModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawType = (map['type'] ?? 'text').toString();
    final createdAt = parseDate(map['createdAt']);
    final expiresAt = map['expiresAt'] != null
        ? parseDate(map['expiresAt'])
        : createdAt.add(const Duration(hours: 24));

    return StatusModel(
      statusId: (map['statusId'] ?? docId ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      userName: (map['userName'] ?? '').toString(),
      userPhotoUrl: (map['userPhotoUrl'] ?? '').toString(),
      type: StatusType.values.firstWhere(
        (e) => e.name == rawType,
        orElse: () => StatusType.text,
      ),
      text: (map['text'] ?? '').toString(),
      mediaUrl: (map['mediaUrl'] ?? '').toString(),
      caption: (map['caption'] ?? '').toString(),
      backgroundColor: () {
        final val = map['backgroundColor'];
        if (val == null) return 0xFF6A1B9A;
        if (val is int) return val;
        if (val is num) return val.toInt();
        if (val is String) {
          final s = val.trim();
          if (s.startsWith('0x') || s.startsWith('0X')) {
            return int.tryParse(s.substring(2), radix: 16) ?? 0xFF6A1B9A;
          }
          return int.tryParse(s) ?? 0xFF6A1B9A;
        }
        return 0xFF6A1B9A;
      }(),
      createdAt: createdAt,
      expiresAt: expiresAt,
      viewedBy: (map['viewedBy'] as List?)?.map((e) => e.toString()).toList() ?? [],
      privacy: (map['privacy'] ?? 'contacts').toString(),
      isQA: map['isQA'] == true,
      mentionedUserIds: (map['mentionedUserIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      mentions: map['mentions'] != null
          ? Map<String, String>.from((map['mentions'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'statusId': statusId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'type': type.name,
      'text': text,
      'mediaUrl': mediaUrl,
      'caption': caption,
      'backgroundColor': backgroundColor,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewedBy': viewedBy,
      'privacy': privacy,
      'isQA': isQA,
      if (mentionedUserIds.isNotEmpty) 'mentionedUserIds': mentionedUserIds,
      if (mentions != null) 'mentions': mentions,
    };
  }
}
