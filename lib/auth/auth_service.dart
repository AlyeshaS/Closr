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
      final payload = <String, Object?>{
        'uid': user.uid,
        'email': user.email,
        'emailLower': user.email?.trim().toLowerCase(),
        'displayName': user.displayName,
      };

      if (normalizedPartnerEmail.isNotEmpty) {
        payload['partnerEmail'] = normalizedPartnerEmail;
        payload['partnerEmailLower'] = normalizedPartnerEmail;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));
    }
    return user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Stream<User?> get userChanges => _auth.userChanges();
}
