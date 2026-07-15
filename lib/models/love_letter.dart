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

  // --- ADD THIS METHOD FOR YOUR TIMELINE ---
  // This maps a Firestore DocumentSnapshot directly to your LoveLetter object
  factory LoveLetter.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Safely handle Firestore Timestamp or ISO String for createdAt
    DateTime parsedDate = DateTime.now();
    if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        parsedDate = (data['createdAt'] as Timestamp).toDate();
      } else {
        parsedDate =
            DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now();
      }
    }

    return LoveLetter(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      recipientId: data['recipientId'] ?? '',
      title: data['title'] ?? 'Untitled Letter',
      text: data['text'] ?? '',
      createdAt: parsedDate,
    );
  }

  factory LoveLetter.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parsedDate = DateTime.now();
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Timestamp) {
        parsedDate = (map['createdAt'] as Timestamp).toDate();
      } else {
        parsedDate =
            DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now();
      }
    }

    return LoveLetter(
      id: documentId,
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      title: map['title'] ?? 'Untitled Letter',
      text: map['text'] ?? '',
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'recipientId': recipientId,
      'title': title,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
