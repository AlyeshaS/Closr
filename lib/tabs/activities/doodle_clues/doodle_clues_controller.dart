// lib/screens/activities/doodle_clues/doodle_clues_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DoodleCluesController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Length of the drawing round. The guesser can watch + guess live for
  /// this entire window; the round only ends early on a correct guess.
  static const int drawDurationSeconds = 120; // 2 minutes

  DocumentReference<Map<String, dynamic>> _gameDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('games')
        .doc('doodleclues');
  }

  /// Listens to the artist's live document (the single source of truth)
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToLiveGame(
    String artistUid,
  ) {
    return _gameDoc(artistUid).snapshots();
  }

  /// Listens to your own document to see if a partner has initiated a match with you
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToMyGame(String myUid) {
    return _gameDoc(myUid).snapshots();
  }

  /// Establishes the match structure cleanly inside the drawer's own folder.
  Future<void> startNewRound({
    required String myUid,
    required String partnerUid,
    required String secretWord,
  }) async {
    final payload = {
      'stage': 'drawing',
      'secretWord': secretWord.trim().toUpperCase(),
      'artistUid': myUid,
      'guesserUid': partnerUid,
      'status': 'active',
      'drawingPaths': [],
      'guessCount': 0,
      'drawDurationSeconds': drawDurationSeconds,
      'roundStartedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();
    batch.set(_gameDoc(myUid), payload);
    batch.set(_gameDoc(partnerUid), payload);
    await batch.commit();
  }

  /// Pushes the in-progress stroke data so the guesser can watch it appear live
  Future<void> updateLiveDrawing(
    String artistUid,
    List<Map<String, double>> livePaths,
  ) async {
    await _gameDoc(artistUid).update({
      'drawingPaths': livePaths,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Evaluates a guess.
  Future<void> registerGuessAttempt({
    required String artistUid,
    required String
    guesserUid, // 🌟 Added parameter to identify the guesser for scoring
    required bool isCorrect,
    required int currentGuessCount,
  }) async {
    final docRef = _gameDoc(artistUid);

    if (isCorrect) {
      final batch = _firestore.batch();

      // 1. Update the game loop state machine indicators
      batch.update(docRef, {
        'stage': 'results',
        'isWin': true,
        'guessCount': currentGuessCount + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. 🏆 Targets the collaborative subcollection score folders for BOTH partners simultaneously
      final artistScoreDoc = _firestore
          .collection('users')
          .doc(artistUid)
          .collection('scores')
          .doc('doodleclues');

      final guesserScoreDoc = _firestore
          .collection('users')
          .doc(guesserUid)
          .collection('scores')
          .doc('doodleclues');

      batch.set(artistScoreDoc, {
        'wins': FieldValue.increment(1),
      }, SetOptions(merge: true));
      batch.set(guesserScoreDoc, {
        'wins': FieldValue.increment(1),
      }, SetOptions(merge: true));

      await batch.commit();
    } else {
      // Wrong guess: just log it and keep the round going. No cap.
      await docRef.update({
        'guessCount': currentGuessCount + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Called by either device once the local 2-minute countdown hits zero
  Future<void> endRoundTimeout(String artistUid) async {
    final docRef = _gameDoc(artistUid);
    final snap = await docRef.get();
    final data = snap.data();
    if (data == null) return;
    if (data['stage'] == 'results') return;

    await docRef.update({
      'stage': 'results',
      'isWin': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Alerts the partner via cancellation parameters
  Future<void> triggerForcedCancellation(
    String myUid,
    String partnerUid,
  ) async {
    final cancelPayload = {
      'stage': 'setup',
      'status': 'cancelled',
      'secretWord': '',
      'artistUid': '',
      'drawingPaths': [],
    };

    final batch = _firestore.batch();
    batch.set(_gameDoc(myUid), cancelPayload);
    if (partnerUid.isNotEmpty) {
      batch.set(_gameDoc(partnerUid), cancelPayload);
    }
    await batch.commit();
  }

  /// Restores a clean state for both paths
  Future<void> purgeMatch(String myUid, String partnerUid) async {
    final clearPayload = {
      'stage': 'setup',
      'status': 'inactive',
      'secretWord': '',
      'artistUid': '',
      'drawingPaths': [],
      'guessCount': 0,
    };

    final batch = _firestore.batch();
    batch.set(_gameDoc(myUid), clearPayload);
    if (partnerUid.isNotEmpty) {
      batch.set(_gameDoc(partnerUid), clearPayload);
    }
    await batch.commit();
  }
}
