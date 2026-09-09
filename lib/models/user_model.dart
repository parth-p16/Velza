import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String phoneNumber;
  final String email;
  final String displayName;
  final String searchableName;
  final String photoUrl;
  final bool isOnline;
  final String typingTo; // Uid of chat user they are typing to, or "none"
  final DateTime createdAt;
  final DateTime lastSeen;
  final List<String> blockedUsers;
  final String fcmToken;
  final String? moodEmoji;
  final int? moodColor;

  UserModel({
    required this.uid,
    required this.phoneNumber,
    required this.email,
    required this.displayName,
    String? searchableName,
    required this.photoUrl,
    required this.isOnline,
    required this.typingTo,
    DateTime? createdAt,
    required this.lastSeen,
    required this.blockedUsers,
    this.fcmToken = '',
    this.moodEmoji,
    this.moodColor,
  })  : searchableName = (searchableName != null && searchableName.isNotEmpty)
            ? searchableName.toLowerCase().trim()
            : displayName.toLowerCase().trim(),
        createdAt = createdAt ?? DateTime.now();

  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    int? parseColor(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) {
        final s = val.trim();
        if (s.isEmpty) return null;
        if (s.startsWith('0x') || s.startsWith('0X')) {
          return int.tryParse(s.substring(2), radix: 16);
        }
        if (s.startsWith('#')) {
          final hex = s.substring(1);
          if (hex.length == 6) {
            return int.tryParse('FF$hex', radix: 16);
          }
          return int.tryParse(hex, radix: 16);
        }
        return int.tryParse(s) ?? (double.tryParse(s)?.toInt());
      }
      return null;
    }

    final displayName = (map['displayName'] ?? '').toString();
    final rawSearchable = (map['searchableName'] ?? '').toString();
    final searchableName = rawSearchable.isNotEmpty
        ? rawSearchable.toLowerCase().trim()
        : displayName.toLowerCase().trim();

    return UserModel(
      uid: (map['uid'] ?? '').toString(),
      phoneNumber: (map['phoneNumber'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      displayName: displayName,
      searchableName: searchableName,
      photoUrl: (map['photoUrl'] ?? '').toString(),
      isOnline: map['isOnline'] == true,
      typingTo: (map['typingTo'] ?? 'none').toString(),
      createdAt: parseDate(map['createdAt']),
      lastSeen: parseDate(map['lastSeen']),
      blockedUsers: (map['blockedUsers'] as List?)?.map((e) => e.toString()).toList() ?? [],
      fcmToken: (map['fcmToken'] ?? '').toString(),
      moodEmoji: map['moodEmoji']?.toString(),
      moodColor: parseColor(map['moodColor']),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'phoneNumber': phoneNumber,
      'email': email,
      'displayName': displayName,
      'searchableName': searchableName.isNotEmpty ? searchableName : displayName.toLowerCase().trim(),
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'typingTo': typingTo,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'blockedUsers': blockedUsers,
    };
    if (fcmToken.isNotEmpty) {
      map['fcmToken'] = fcmToken;
    }
    if (moodEmoji != null) {
      map['moodEmoji'] = moodEmoji;
    }
    if (moodColor != null) {
      map['moodColor'] = moodColor;
    }
    return map;
  }

  UserModel copyWith({
    String? phoneNumber,
    String? email,
    String? displayName,
    String? searchableName,
    String? photoUrl,
    bool? isOnline,
    String? typingTo,
    DateTime? createdAt,
    DateTime? lastSeen,
    List<String>? blockedUsers,
    String? fcmToken,
    String? moodEmoji,
    int? moodColor,
  }) {
    return UserModel(
      uid: uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      searchableName: searchableName ?? this.searchableName,
      photoUrl: photoUrl ?? this.photoUrl,
      isOnline: isOnline ?? this.isOnline,
      typingTo: typingTo ?? this.typingTo,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      fcmToken: fcmToken ?? this.fcmToken,
      moodEmoji: moodEmoji ?? this.moodEmoji,
      moodColor: moodColor ?? this.moodColor,
    );
  }
}
