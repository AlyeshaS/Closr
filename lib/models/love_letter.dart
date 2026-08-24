// love_letter.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class LoveLetter {
  final String id;
  final String senderId;
  final String recipientId;
  final String title;
  final String text;
  final DateTime createdAt;

  LoveLetter({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  factory LoveLetter.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LoveLetter.fromMap(data, doc.id);
  }

  factory LoveLetter.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parsedDate = DateTime.now();
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Timestamp) {
        parsedDate = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is String) {
        parsedDate = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
      }
    }

    return LoveLetter(
      id: documentId,
      senderId: map['senderId'] ?? map['senderUid'] ?? '',
      recipientId: map['recipientId'] ?? map['partnerUid'] ?? '',
      title: map['title'] ?? 'Untitled Letter',
      text: map['text'] ?? '',
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'title': title,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
