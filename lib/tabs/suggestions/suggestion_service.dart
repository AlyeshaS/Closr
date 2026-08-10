import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/streaks_service.dart';

class SuggestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StreaksService _streaks = StreaksService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveSuggestion(
    String suggestionId,
    Map<String, dynamic> data,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not signed in');
    await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('suggestions')
        .doc(suggestionId)
        .set(data, SetOptions(merge: true));
    await _streaks.recordActivity('date_suggestion_generated');
  }

  Stream<QuerySnapshot> getSuggestionsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('suggestions')
        .snapshots();
  }

  Future<void> swipeSuggestion(String suggestionId, String action) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not signed in');

    await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('suggestions')
        .doc(suggestionId)
        .set({
          'swipe': action,
          'swipedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> saveMatchedSuggestion(
    String suggestionId,
    Map<String, dynamic> data,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not signed in');
    await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('matched_suggestions')
        .doc(suggestionId)
        .set(data, SetOptions(merge: true));
  }
}
