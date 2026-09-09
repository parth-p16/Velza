import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityModel {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final String creatorId;
  final List<String> memberIds;
  final List<String> channelIds;
  final DateTime createdAt;

  const CommunityModel({
    required this.id,
    required this.name,
    required this.description,
    this.iconUrl = '',
    required this.creatorId,
    required this.memberIds,
    this.channelIds = const [],
    required this.createdAt,
  });

  factory CommunityModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return CommunityModel(
      id: (map['id'] ?? docId ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      iconUrl: (map['iconUrl'] ?? '').toString(),
      creatorId: (map['creatorId'] ?? '').toString(),
      memberIds: List<String>.from(map['memberIds'] ?? []),
      channelIds: List<String>.from(map['channelIds'] ?? []),
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'creatorId': creatorId,
      'memberIds': memberIds,
      'channelIds': channelIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
