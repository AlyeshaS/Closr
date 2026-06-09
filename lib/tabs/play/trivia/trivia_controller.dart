import 'package:cloud_firestore/cloud_firestore.dart';

class TriviaController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Local state mirrored from Firestore streams
  String myStage = 'setup'; // 'setup', 'waiting', 'guessing', 'results'
  List<int> mySelfAnswers = [];
  List<int> myGuessesForPartner = [];
  int myGlobalWins = 0; // Tracking personal lifetime leaderboard wins

  bool isPartnerSetupComplete = false;
  List<int> partnerSelfAnswers = [];
  List<int> partnerGuessesForMe = [];
  int partnerGlobalWins = 0; // Tracking partner lifetime leaderboard wins

  /// Real-time stream targeting the current user's trivia profile node.
  /// This automatically pulls data from the subcollection within the user's document.
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToMyTrivia(
    String myUid,
  ) {
    return _firestore
        .collection('users')
        .doc(myUid)
        .collection('trivia')
        .doc('session')
        .snapshots();
  }

  /// Real-time stream tracking the partner's trivia profile node using the active match link.
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToPartnerTrivia(
    String myUid,
  ) {
    // We stream the user's root document to find their active matchId dynamically,
    // then map it to pipe the partner's trivia subcollection snapshot back to the UI.
    return _firestore.collection('users').doc(myUid).snapshots().asyncExpand((
      userDoc,
    ) {
      final String matchId = userDoc.data()?['matchId'] ?? '';

      if (matchId.isEmpty) {
        // Return an empty stream if no active relationship link is present
        return const Stream.empty();
      }

      return _firestore
          .collection('users')
          .doc(matchId)
          .collection('trivia')
          .doc('session')
          .snapshots();
    });
  }

  /// Synchronizes incoming Firestore changes into the controller's local instance variables for your own profile.
  void updateMyData(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!snapshot.exists || snapshot.data() == null) {
      // Safe default initialization if no cloud document has been written yet
      myStage = 'setup';
      mySelfAnswers = [];
      myGuessesForPartner = [];
      myGlobalWins = 0;
      return;
    }

    final data = snapshot.data()!;
    myStage = data['stage'] ?? 'setup';
    mySelfAnswers = List<int>.from(data['selfAnswers'] ?? []);
    myGuessesForPartner = List<int>.from(data['guessesForPartner'] ?? []);
    myGlobalWins = data['globalWins'] ?? 0;
  }

  /// Synchronizes incoming Firestore changes from your partner's profile to compute matches.
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

    // Partner is ready to be guessed if they have finished their setup stage
    isPartnerSetupComplete =
        (partnerStage == 'waiting' ||
        partnerStage == 'guessing' ||
        partnerStage == 'results');
    partnerSelfAnswers = List<int>.from(data['selfAnswers'] ?? []);
    partnerGuessesForMe = List<int>.from(data['guessesForPartner'] ?? []);
    partnerGlobalWins = data['globalWins'] ?? 0;
  }

  /// Writes your personal answers to your trivia document subcollection.
  Future<void> submitSelfAnswer(String myUid, List<int> answers) async {
    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('trivia')
        .doc('session')
        .set({'selfAnswers': answers}, SetOptions(merge: true));
  }

  /// Writes your mental guesses regarding your partner's preferences to your subcollection.
  Future<void> submitGuessAnswer(String myUid, List<int> guesses) async {
    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('trivia')
        .doc('session')
        .set({'guessesForPartner': guesses}, SetOptions(merge: true));
  }

  /// Updates the current interactive state machine block (e.g., 'setup' -> 'waiting').
  Future<void> updateUserStage(String myUid, String stage) async {
    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('trivia')
        .doc('session')
        .set({'stage': stage}, SetOptions(merge: true));
  }

  /// Flushes out the previous game state data points inside the user's subcollection
  /// so you can run a clean session round together later.
  Future<void> evaluateAndPurgeMatch(String myUid) async {
    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('trivia')
        .doc('session')
        .set({
          'stage': 'setup',
          'selfAnswers': [],
          'guessesForPartner': [],
        }, SetOptions(merge: true));
  }
}
