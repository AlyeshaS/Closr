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

  /// Real-time stream tracking the partner's trivia profile node using their email link.
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToPartnerTrivia(
    String myUid,
  ) {
    // 1. Listen to your own root user document first
    return _firestore.collection('users').doc(myUid).snapshots().asyncExpand((
      userDoc,
    ) {
      // 2. Extract the partner email field saved by your AuthService
      final String partnerEmailLower =
          userDoc.data()?['partnerEmailLower'] ?? '';

      if (partnerEmailLower.isEmpty) {
        return const Stream.empty();
      }

      // 3. Query the users collection to find the document where 'emailLower' matches your partner's email
      return _firestore
          .collection('users')
          .where('emailLower', isEqualTo: partnerEmailLower)
          .snapshots()
          .asyncExpand((querySnapshot) {
            if (querySnapshot.docs.isEmpty) {
              // Partner hasn't logged in yet, or the matching record isn't created under their UID
              return const Stream.empty();
            }

            // 4. Get the partner's actual user UID doc and stream their trivia session subcollection
            final partnerUserUid = querySnapshot.docs.first.id;
            return _firestore
                .collection('users')
                .doc(partnerUserUid)
                .collection('trivia')
                .doc('session')
                .snapshots();
          });
    });
  }

  /// Synchronizes incoming Firestore changes into the controller's local instance variables for your own profile.
  /// Synchronizes incoming Firestore changes into the controller's local instance variables for your own profile.
  void updateMyData(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String myUid,
  ) {
    if (!snapshot.exists || snapshot.data() == null) {
      myStage = 'setup';
      mySelfAnswers = [];
      myGuessesForPartner = [];
      myGlobalWins = 0;

      //  AUTO-INITIALIZE: If document was deleted, create a fresh one instantly!
      _firestore
          .collection('users')
          .doc(myUid)
          .collection('trivia')
          .doc('session')
          .set({
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
