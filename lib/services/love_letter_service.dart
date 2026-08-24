// lib/services/love_letter_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/love_letter.dart';
import './badge_service.dart';

class LoveLetterService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final BadgeService _badgeService;

  LoveLetterService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    BadgeService? badgeService,
  }) : _db = db ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _badgeService = badgeService ?? BadgeService();

  /// Streams love letters from users/{uid}/love_letters
  Stream<List<LoveLetter>> streamForCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('love_letters')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return LoveLetter.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  /// Saves the love letter to both user subcollections and increments badge progress
  Future<String> sendLoveLetter({
    String? letterId,
    required String title,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No signed-in user found.');
    }

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? <String, dynamic>{};

    final myEmail = ((data['emailLower'] as String?) ?? user.email ?? '')
        .trim()
        .toLowerCase();
    final partnerEmail =
        ((data['partnerEmailLower'] as String?) ??
                (data['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();

    String partnerUid = ((data['partnerUid'] as String?) ?? '').trim();

    if (partnerUid.isEmpty && partnerEmail.isNotEmpty) {
      final partnerByLower = await _db
          .collection('users')
          .where('emailLower', isEqualTo: partnerEmail)
          .limit(1)
          .get();

      if (partnerByLower.docs.isNotEmpty) {
        partnerUid = partnerByLower.docs.first.id;
      } else {
        final partnerByEmail = await _db
            .collection('users')
            .where('email', isEqualTo: partnerEmail)
            .limit(1)
            .get();
        if (partnerByEmail.docs.isNotEmpty) {
          partnerUid = partnerByEmail.docs.first.id;
        }
      }
    }

    final isNewLetter = letterId == null;
    final resolvedLetterId =
        letterId ??
        _db
            .collection('users')
            .doc(user.uid)
            .collection('love_letters')
            .doc()
            .id;

    final payload = <String, dynamic>{
      'id': resolvedLetterId,
      'title': title,
      'text': text,
      'senderId': user.uid,
      'recipientId': partnerUid,
      'submittedByUid': user.uid,
      'submittedByEmail': myEmail,
      'partnerEmail': partnerEmail,
      'partnerUid': partnerUid,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final batch = _db.batch();

    // 1. Write to current user's subcollection
    final myDocRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('love_letters')
        .doc(resolvedLetterId);

    batch.set(myDocRef, {
      ...payload,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Write to partner's subcollection
    if (partnerUid.isNotEmpty && partnerUid != user.uid) {
      final partnerDocRef = _db
          .collection('users')
          .doc(partnerUid)
          .collection('love_letters')
          .doc(resolvedLetterId);

      batch.set(partnerDocRef, {
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();

    // 3. Increment the badge statistic for new letters
    if (isNewLetter) {
      await _badgeService.incrementStat(statKey: 'letters_sent', by: 1);
    }

    return resolvedLetterId;
  }

  /// Deletes the love letter from both subcollections
  Future<void> deleteLoveLetter(String letterId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No signed-in user found.');

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? <String, dynamic>{};

    final partnerEmail =
        ((data['partnerEmailLower'] as String?) ??
                (data['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();

    String partnerUid = ((data['partnerUid'] as String?) ?? '').trim();

    if (partnerUid.isEmpty && partnerEmail.isNotEmpty) {
      final partnerByLower = await _db
          .collection('users')
          .where('emailLower', isEqualTo: partnerEmail)
          .limit(1)
          .get();

      if (partnerByLower.docs.isNotEmpty) {
        partnerUid = partnerByLower.docs.first.id;
      } else {
        final partnerByEmail = await _db
            .collection('users')
            .where('email', isEqualTo: partnerEmail)
            .limit(1)
            .get();
        if (partnerByEmail.docs.isNotEmpty) {
          partnerUid = partnerByEmail.docs.first.id;
        }
      }
    }

    final batch = _db.batch();
    batch.delete(
      _db
          .collection('users')
          .doc(user.uid)
          .collection('love_letters')
          .doc(letterId),
    );

    if (partnerUid.isNotEmpty && partnerUid != user.uid) {
      batch.delete(
        _db
            .collection('users')
            .doc(partnerUid)
            .collection('love_letters')
            .doc(letterId),
      );
    }

    await batch.commit();
  }
}
