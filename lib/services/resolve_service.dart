import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResolveService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  ResolveService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  Future<String> saveSession({
    String? sessionId,
    required String selectedMode,
    required Map<String, List<String>> responses,
    required int currentStage,
    required int currentPromptIndex,
    required bool isCompleted,
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

    final resolvedSessionId =
        sessionId ??
        _db.collection('users').doc(user.uid).collection('resolve').doc().id;
    final expiresAt = Timestamp.fromDate(
      DateTime.now().toUtc().add(const Duration(days: 30)),
    );

    final payload = <String, dynamic>{
      'sessionId': resolvedSessionId,
      'selectedMode': selectedMode,
      'responses': responses,
      'currentStage': currentStage,
      'currentPromptIndex': currentPromptIndex,
      'isCompleted': isCompleted,
      'connectedByEmail': partnerEmail.isNotEmpty,
      'submittedByUid': user.uid,
      'submittedByEmail': myEmail,
      'partnerEmail': partnerEmail,
      'partnerUid': partnerUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
    };

    final batch = _db.batch();

    final myDocRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('resolve')
        .doc(resolvedSessionId);

    batch.set(myDocRef, {
      ...payload,
      'ownerUid': user.uid,
      'ownerEmail': myEmail,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (partnerUid.isNotEmpty && partnerUid != user.uid) {
      final partnerDocRef = _db
          .collection('users')
          .doc(partnerUid)
          .collection('resolve')
          .doc(resolvedSessionId);

      batch.set(partnerDocRef, {
        ...payload,
        'ownerUid': partnerUid,
        'ownerEmail': partnerEmail,
        'createdAt': FieldValue.serverTimestamp(),
        'sharedFromUid': user.uid,
        'sharedFromEmail': myEmail,
      }, SetOptions(merge: true));
    }

    await batch.commit();
    return resolvedSessionId;
  }
}
