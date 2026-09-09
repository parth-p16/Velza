import 'package:cloud_firestore/cloud_firestore.dart';

enum RelationshipStatus {
  none,
  pending,
  accepted,
  blocked;

  static RelationshipStatus fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'pending':
        return RelationshipStatus.pending;
      case 'accepted':
        return RelationshipStatus.accepted;
      case 'blocked':
        return RelationshipStatus.blocked;
      default:
        return RelationshipStatus.none;
    }
  }
}

class RelationshipModel {
  final String relationshipId;
  final String fromUid;
  final String toUid;
  final RelationshipStatus status;
  final String? blockedBy;
  final String? sharedNickname;
  final DateTime createdAt;
  final DateTime? updatedAt;

  RelationshipModel({
    required this.relationshipId,
    required this.fromUid,
    required this.toUid,
    required this.status,
    this.blockedBy,
    this.sharedNickname,
    required this.createdAt,
    this.updatedAt,
  });

  static String generateId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  bool get isAccepted => status == RelationshipStatus.accepted;
  bool get isPending => status == RelationshipStatus.pending;
  bool get isBlocked => status == RelationshipStatus.blocked;

  factory RelationshipModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return RelationshipModel(
      relationshipId: id ?? (map['relationshipId'] ?? '').toString(),
      fromUid: (map['fromUid'] ?? '').toString(),
      toUid: (map['toUid'] ?? '').toString(),
      status: RelationshipStatus.fromString(map['status']?.toString()),
      blockedBy: map['blockedBy']?.toString(),
      sharedNickname: map['sharedNickname']?.toString(),
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'relationshipId': relationshipId,
      'fromUid': fromUid,
      'toUid': toUid,
      'status': status.name,
      if (blockedBy != null) 'blockedBy': blockedBy,
      if (sharedNickname != null) 'sharedNickname': sharedNickname,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }
}
