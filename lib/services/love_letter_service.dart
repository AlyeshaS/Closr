import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/love_letter.dart';

class LoveLetterService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<LoveLetter>> streamForCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('loveLetters')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => LoveLetter.fromDoc(d)).toList());
  }

  Future<String?> _getPartnerUid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final partnerEmail =
        ((userData?['partnerEmailLower'] as String?) ??
                (userData?['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();
    if (partnerEmail.isEmpty) return null;
    final partnerQuery = await _db
        .collection('users')
        .where('emailLower', isEqualTo: partnerEmail)
        .get();
    if (partnerQuery.docs.isNotEmpty) return partnerQuery.docs.first.id;
    final fallbackQuery = await _db
        .collection('users')
        .where('email', isEqualTo: partnerEmail)
        .get();
    if (fallbackQuery.docs.isNotEmpty) return fallbackQuery.docs.first.id;

    final allUsers = await _db.collection('users').limit(250).get();
    for (final doc in allUsers.docs) {
      final data = doc.data();
      final email =
          ((data['emailLower'] as String?) ?? (data['email'] as String?) ?? '')
              .trim()
              .toLowerCase();
      if (email == partnerEmail) {
        return doc.id;
      }
    }
    return null;
  }

  Future<void> sendLetter(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    final docRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('loveLetters')
        .doc();
    final letter = {
      'senderId': user.uid,
      'recipientId': '',
      'text': text,
      'createdAt': Timestamp.fromDate(now),
    };
    // Save to sender's collection
    await docRef.set(letter);

    // Also save to partner's collection if partner exists
    final partnerUid = await _getPartnerUid();
    if (partnerUid != null) {
      final partnerRef = _db
          .collection('users')
          .doc(partnerUid)
          .collection('loveLetters')
          .doc();
      final partnerLetter = {
        'senderId': user.uid,
        'recipientId': partnerUid,
        'text': text,
        'createdAt': Timestamp.fromDate(now),
      };
      await partnerRef.set(partnerLetter);
    }
  }

  Future<void> updateLetter(String letterId, String newText) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    final docRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('loveLetters')
        .doc(letterId);
    await docRef.update({
      'text': newText,
      'createdAt': Timestamp.fromDate(now),
    });
  }
}
