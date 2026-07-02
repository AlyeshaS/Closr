// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<User?> signInWithGoogle({String? partnerEmail}) async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null) {
      final normalizedPartnerEmail = partnerEmail?.trim().toLowerCase() ?? '';
      String foundPartnerUid = '';

      // Look up partner UID once during authentication sequence
      if (normalizedPartnerEmail.isNotEmpty) {
        final partnerQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('emailLower', isEqualTo: normalizedPartnerEmail)
            .get();
        if (partnerQuery.docs.isNotEmpty) {
          foundPartnerUid = partnerQuery.docs.first.id;
        }
      }

      // Initialize keys safely via flat dot-notation parameters
      final payload = <String, Object?>{
        'uid': user.uid,
        'email': user.email,
        'emailLower': user.email?.trim().toLowerCase(),
        'displayName': user.displayName,
        'scores.letterlocked': FieldValue.increment(0),
        'scores.trivia': FieldValue.increment(0),
      };

      if (normalizedPartnerEmail.isNotEmpty) {
        payload['partnerEmail'] = normalizedPartnerEmail;
        payload['partnerEmailLower'] = normalizedPartnerEmail;
        if (foundPartnerUid.isNotEmpty) {
          payload['partnerUid'] = foundPartnerUid;
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      // Mutual sync linking
      if (foundPartnerUid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(foundPartnerUid)
            .set({
              'partnerUid': user.uid,
              'partnerEmail': user.email?.trim().toLowerCase(),
              'partnerEmailLower': user.email?.trim().toLowerCase(),
            }, SetOptions(merge: true));
      }
    }
    return user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Stream<User?> get userChanges => _auth.userChanges();
}
