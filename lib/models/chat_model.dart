import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final String name; // For groups, group name; for 1-1, dynamic recipient name
  final String photoUrl; // Dynamic for 1-1
  final bool isGroup;
  final List<String> memberIds;
  final String lastMessageText;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCounts; // Map of uid to unread message count
  final Map<String, String> typingStatus; // Map of uid to typing state (e.g. "typing", "recording", "none")
  final String wallpaperId; // Shared chat theme preset id
  final String wallpaperType; // 'builtin' | 'gallery'
  final String wallpaperUrl; // Remote URL if type is gallery
  final String? wallpaperUpdatedBy;
  final DateTime? wallpaperUpdatedAt;
  final Map<String, DateTime> clearedAtBy; // Map of uid to clearedAt timestamp
  final int streakCount;
  final String? lastStreakDate;

  ChatModel({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.isGroup,
    required this.memberIds,
    required this.lastMessageText,
    required this.lastMessageTime,
    required this.unreadCounts,
    required this.typingStatus,
    this.wallpaperId = 'velza_default',
    this.wallpaperType = 'builtin',
    this.wallpaperUrl = '',
    this.wallpaperUpdatedBy,
    this.wallpaperUpdatedAt,
    this.clearedAtBy = const {},
    this.streakCount = 0,
    this.lastStreakDate,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    Map<String, DateTime> parseClearedAtBy(dynamic raw) {
      if (raw is! Map) return {};
      final result = <String, DateTime>{};
      raw.forEach((k, v) {
        if (v is Timestamp) {
          result[k.toString()] = v.toDate();
        } else if (v is int) {
          result[k.toString()] = DateTime.fromMillisecondsSinceEpoch(v);
        } else if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) result[k.toString()] = parsed;
        }
      });
      return result;
    }

    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ChatModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      isGroup: map['isGroup'] ?? false,
      memberIds: List<String>.from(map['memberIds'] ?? []),
      lastMessageText: map['lastMessageText'] ?? '',
      lastMessageTime: map['lastMessageTime'] != null
          ? (map['lastMessageTime'] is Timestamp
              ? (map['lastMessageTime'] as Timestamp).toDate()
              : (parseDate(map['lastMessageTime']) ?? DateTime.now()))
          : DateTime.now(),
      unreadCounts: Map<String, int>.from(map['unreadCounts'] ?? {}),
      typingStatus: Map<String, String>.from(map['typingStatus'] ?? {}),
      wallpaperId: map['wallpaperId']?.toString() ?? 'velza_default',
      wallpaperType: map['wallpaperType']?.toString() ?? 'builtin',
      wallpaperUrl: map['wallpaperUrl']?.toString() ?? '',
      wallpaperUpdatedBy: map['wallpaperUpdatedBy']?.toString(),
      wallpaperUpdatedAt: parseDate(map['wallpaperUpdatedAt']),
      clearedAtBy: parseClearedAtBy(map['clearedAtBy']),
      streakCount: (map['streakCount'] as num?)?.toInt() ?? 0,
      lastStreakDate: map['lastStreakDate']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'photoUrl': photoUrl,
      'isGroup': isGroup,
      'memberIds': memberIds,
      'lastMessageText': lastMessageText,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadCounts': unreadCounts,
      'typingStatus': typingStatus,
      'wallpaperId': wallpaperId,
      'wallpaperType': wallpaperType,
      'wallpaperUrl': wallpaperUrl,
      if (wallpaperUpdatedBy != null) 'wallpaperUpdatedBy': wallpaperUpdatedBy,
      if (wallpaperUpdatedAt != null) 'wallpaperUpdatedAt': Timestamp.fromDate(wallpaperUpdatedAt!),
      if (clearedAtBy.isNotEmpty)
        'clearedAtBy': clearedAtBy.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
      'streakCount': streakCount,
      if (lastStreakDate != null) 'lastStreakDate': lastStreakDate,
    };
  }

  ChatModel copyWith({
    String? id,
    String? name,
    String? photoUrl,
    bool? isGroup,
    List<String>? memberIds,
    String? lastMessageText,
    DateTime? lastMessageTime,
    Map<String, int>? unreadCounts,
    Map<String, String>? typingStatus,
    String? wallpaperId,
    String? wallpaperType,
    String? wallpaperUrl,
    String? wallpaperUpdatedBy,
    DateTime? wallpaperUpdatedAt,
    Map<String, DateTime>? clearedAtBy,
    int? streakCount,
    String? lastStreakDate,
  }) {
    return ChatModel(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      isGroup: isGroup ?? this.isGroup,
      memberIds: memberIds ?? this.memberIds,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      typingStatus: typingStatus ?? this.typingStatus,
      wallpaperId: wallpaperId ?? this.wallpaperId,
      wallpaperType: wallpaperType ?? this.wallpaperType,
      wallpaperUrl: wallpaperUrl ?? this.wallpaperUrl,
      wallpaperUpdatedBy: wallpaperUpdatedBy ?? this.wallpaperUpdatedBy,
      wallpaperUpdatedAt: wallpaperUpdatedAt ?? this.wallpaperUpdatedAt,
      clearedAtBy: clearedAtBy ?? this.clearedAtBy,
      streakCount: streakCount ?? this.streakCount,
      lastStreakDate: lastStreakDate ?? this.lastStreakDate,
    );
  }
}
