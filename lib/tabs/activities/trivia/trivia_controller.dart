// lib/screens/activities/trivia/trivia_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TriviaController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _triviaDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('games')
        .doc('trivia');
  }

  DocumentReference<Map<String, dynamic>> _legacyTriviaDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('trivia')
        .doc('session');
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _watchTriviaDoc(String uid) {
    final primaryStream = _triviaDoc(uid).snapshots();
    final legacyStream = _legacyTriviaDoc(uid).snapshots().asyncMap((
      snapshot,
    ) async {
      if (snapshot.exists && snapshot.data() != null) {
        await _triviaDoc(uid).set(snapshot.data()!, SetOptions(merge: true));
      }

      return snapshot;
    });

    return primaryStream.asyncExpand((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return Stream.value(snapshot);
      }

      return legacyStream;
    });
  }

  String myStage = 'setup';
  List<int> mySelfAnswers = [];
  List<int> myGuessesForPartner = [];
  int myGlobalWins = 0;

  bool isPartnerSetupComplete = false;
  List<int> partnerSelfAnswers = [];
  List<int> partnerGuessesForMe = [];
  int partnerGlobalWins = 0;

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToMyTrivia(
    String myUid,
  ) {
    return _watchTriviaDoc(myUid);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToPartnerTrivia(
    String myUid,
  ) {
    return _firestore.collection('users').doc(myUid).snapshots().asyncExpand((
      userDoc,
    ) {
      final String partnerEmailLower =
          userDoc.data()?['partnerEmailLower'] ?? '';

      if (partnerEmailLower.isEmpty) {
        return const Stream.empty();
      }

      return _firestore
          .collection('users')
          .where('emailLower', isEqualTo: partnerEmailLower)
          .snapshots()
          .asyncExpand((querySnapshot) {
            if (querySnapshot.docs.isEmpty) {
              return const Stream.empty();
            }

            final partnerUserUid = querySnapshot.docs.first.id;
            return _watchTriviaDoc(partnerUserUid);
          });
    });
  }

  void updateMyData(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String myUid,
  ) {
    if (!snapshot.exists || snapshot.data() == null) {
      myStage = 'setup';
      mySelfAnswers = [];
      myGuessesForPartner = [];
      myGlobalWins = 0;

      _triviaDoc(myUid).set({
        'stage': 'setup',
        'selfAnswers': [],
        'guessesForPartner': [],
        'globalWins': 0,
      }, SetOptions(merge: true));
      return;
    }

    final data = snapshot.data()!;
    myStage = data['stage'] ?? 'setup';
    mySelfAnswers = List<int>.from(data['selfAnswers'] ?? []);
    myGuessesForPartner = List<int>.from(data['guessesForPartner'] ?? []);
    myGlobalWins = data['globalWins'] ?? 0;
  }

  void updatePartnerData(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!snapshot.exists || snapshot.data() == null) {
      isPartnerSetupComplete = false;
      partnerSelfAnswers = [];
      partnerGuessesForMe = [];
      partnerGlobalWins = 0;
      return;
    }

    final data = snapshot.data()!;
    final String partnerStage = data['stage'] ?? 'setup';

    isPartnerSetupComplete =
        (partnerStage == 'waiting' ||
        partnerStage == 'guessing' ||
        partnerStage == 'results');
    partnerSelfAnswers = List<int>.from(data['selfAnswers'] ?? []);
    partnerGuessesForMe = List<int>.from(data['guessesForPartner'] ?? []);
    partnerGlobalWins = data['globalWins'] ?? 0;
  }

  Future<void> submitSelfAnswer(String myUid, List<int> answers) async {
    await _triviaDoc(
      myUid,
    ).set({'selfAnswers': answers}, SetOptions(merge: true));
  }

  Future<void> submitGuessAnswer(String myUid, List<int> guesses) async {
    await _triviaDoc(
      myUid,
    ).set({'guessesForPartner': guesses}, SetOptions(merge: true));
  }

  Future<void> updateUserStage(String myUid, String stage) async {
    await _triviaDoc(myUid).set({'stage': stage}, SetOptions(merge: true));
  }

  Future<void> evaluateAndPurgeMatch(String myUid) async {
    await _triviaDoc(myUid).set({
      'stage': 'setup',
      'selfAnswers': [],
      'guessesForPartner': [],
    }, SetOptions(merge: true));
  }

  // 🏆 Centralized Subcollection Score Router
  Future<void> rewardTriviaWinner(String winnerUid) async {
    // 🌟 FIX: Saves directly into users/uid/scores/trivia containing a numeric 'wins' key
    await _firestore
        .collection('users')
        .doc(winnerUid)
        .collection('scores')
        .doc('trivia')
        .set({'wins': FieldValue.increment(1)}, SetOptions(merge: true));
  }
}
