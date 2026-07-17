import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/love_letter.dart';

class LoveLetterService {
  /// Streams all love letters nested under the unique couple email identifier.
  Stream<List<LoveLetter>> streamForCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    // 1. First get the user document to grab both emails
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .asyncExpand((userSnap) {
          if (!userSnap.exists || userSnap.data() == null) {
            return Stream.value([]);
          }

          final data = userSnap.data()!;

          // Grab the user's normalized email and their partner's email
          final String? myEmail = (data['email'] ?? data['emailLower'])
              ?.toString()
              .trim()
              .toLowerCase();
          final String? partnerEmail =
              (data['partnerEmail'] ?? data['partnerEmailLower'])
                  ?.toString()
                  .trim()
                  .toLowerCase();

          // We need both emails to create the shared collection path
          if (myEmail == null ||
              myEmail.isEmpty ||
              partnerEmail == null ||
              partnerEmail.isEmpty) {
            return Stream.value([]);
          }

          final List<String> emails = [myEmail, partnerEmail]..sort();
          final String coupleId = '${emails[0]}_${emails[1]}';

          // 3. Stream the letters subcollection ordered by creation date
          return FirebaseFirestore.instance
              .collection('couples')
              .doc(coupleId)
              .collection('love_letters')
              .orderBy('createdAt', descending: true)
              .snapshots()
              .map((snapshot) {
                return snapshot.docs.map((doc) {
                  return LoveLetter.fromMap(doc.data(), doc.id);
                }).toList();
              });
        });
  }
}
