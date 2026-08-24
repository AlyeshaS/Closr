import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/love_letter.dart';

class LoveLetterService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  LoveLetterService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

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

    final myDocRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('love_letters')
        .doc(resolvedLetterId);

    batch.set(myDocRef, {
      ...payload,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

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
    return resolvedLetterId;
  }

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
