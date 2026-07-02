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
  /// [secretWord] is chosen by the artist themselves (not auto-generated).
  /// `roundStartedAt` is a server timestamp so both devices can derive an
  /// identical 2-minute countdown regardless of clock drift.
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

  /// Pushes the in-progress stroke data so the guesser can watch it appear
  /// live, point by point, while the artist is still drawing. Call this
  /// throttled (e.g. every ~300ms) while the pointer is moving, plus once
  /// immediately when a stroke ends, rather than on every single frame.
  Future<void> updateLiveDrawing(
    String artistUid,
    List<Map<String, double>> livePaths,
  ) async {
    await _gameDoc(artistUid).update({
      'drawingPaths': livePaths,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Evaluates a guess. Guesses are unlimited — the only things that end
  /// the round are a correct guess or the timer running out.
  Future<void> registerGuessAttempt({
    required String artistUid,
    required bool isCorrect,
    required int currentGuessCount,
  }) async {
    final docRef = _gameDoc(artistUid);

    if (isCorrect) {
      await docRef.update({
        'stage': 'results',
        'isWin': true,
        'guessCount': currentGuessCount + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Wrong guess: just log it and keep the round going. No cap.
      await docRef.update({
        'guessCount': currentGuessCount + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Called by either device once the local 2-minute countdown hits zero
  /// with no correct guess yet. Guarded against double-resolution so it's
  /// safe for both the artist and guesser clients to call it.
  Future<void> endRoundTimeout(String artistUid) async {
    final docRef = _gameDoc(artistUid);
    final snap = await docRef.get();
    final data = snap.data();
    if (data == null) return;
    if (data['stage'] == 'results') return; // already resolved elsewhere

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
