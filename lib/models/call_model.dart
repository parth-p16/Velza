import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType { audio, video }
enum CallDirection { incoming, outgoing, missed }

class CallModel {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerPhotoUrl;
  final String receiverId;
  final String receiverName;
  final String receiverPhotoUrl;
  final CallType callType;
  final CallDirection direction;
  final DateTime timestamp;
  final int durationSeconds;

  const CallModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerPhotoUrl = '',
    required this.receiverId,
    required this.receiverName,
    this.receiverPhotoUrl = '',
    required this.callType,
    required this.direction,
    required this.timestamp,
    this.durationSeconds = 0,
  });

  factory CallModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawType = (map['callType'] ?? 'audio').toString();
    final rawDir = (map['direction'] ?? 'incoming').toString();

    return CallModel(
      callId: (map['callId'] ?? docId ?? '').toString(),
      callerId: (map['callerId'] ?? '').toString(),
      callerName: (map['callerName'] ?? '').toString(),
      callerPhotoUrl: (map['callerPhotoUrl'] ?? '').toString(),
      receiverId: (map['receiverId'] ?? '').toString(),
      receiverName: (map['receiverName'] ?? '').toString(),
      receiverPhotoUrl: (map['receiverPhotoUrl'] ?? '').toString(),
      callType: CallType.values.firstWhere((e) => e.name == rawType, orElse: () => CallType.audio),
      direction: CallDirection.values.firstWhere((e) => e.name == rawDir, orElse: () => CallDirection.incoming),
      timestamp: parseDate(map['timestamp']),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ??
          (int.tryParse(map['durationSeconds']?.toString() ?? '0') ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'callerPhotoUrl': callerPhotoUrl,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPhotoUrl': receiverPhotoUrl,
      'callType': callType.name,
      'direction': direction.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'durationSeconds': durationSeconds,
    };
  }
}
