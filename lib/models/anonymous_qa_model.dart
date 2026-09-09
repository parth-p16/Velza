import 'package:cloud_firestore/cloud_firestore.dart';

class AnonymousQAModel {
  final String id;
  final String statusId;
  final String question;
  final String senderUid; // Retained securely for moderation/abuse prevention
  final DateTime createdAt;
  final String? answer;
  final bool isAnswered;

  const AnonymousQAModel({
    required this.id,
    required this.statusId,
    required this.question,
    required this.senderUid,
    required this.createdAt,
    this.answer,
    this.isAnswered = false,
  });

  factory AnonymousQAModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return AnonymousQAModel(
      id: docId ?? (map['id'] ?? '').toString(),
      statusId: (map['statusId'] ?? '').toString(),
      question: (map['question'] ?? '').toString(),
      senderUid: (map['senderUid'] ?? '').toString(),
      createdAt: parseDate(map['createdAt']),
      answer: map['answer']?.toString(),
      isAnswered: map['isAnswered'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'statusId': statusId,
      'question': question,
      'senderUid': senderUid,
      'createdAt': Timestamp.fromDate(createdAt),
      if (answer != null) 'answer': answer,
      'isAnswered': isAnswered,
    };
  }
}
