// lib/screens/activities/doodle_clues/doodle_clues_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DoodleCluesController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _gameDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('games')
        .doc('doodleclues');
  }

  /// Listens to the artist's live document (The single source of truth)
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToLiveGame(
    String artistUid,
  ) {
    return _gameDoc(artistUid).snapshots();
  }

  /// Listens to your own document to see if a partner has initiated a match with you
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToMyGame(String myUid) {
    return _gameDoc(myUid).snapshots();
  }

  /// Establishes the match structure cleanly inside the drawer's own folder
  Future<void> startNewRound({
    required String myUid,
    required String partnerUid,
    required String secretWord,
  }) async {
    final payload = {
      'stage': 'drawing',
      'secretWord': secretWord.toUpperCase(),
      'artistUid': myUid,
      'guesserUid': partnerUid,
      'status': 'active',
      'drawingPaths': [],
      'attemptsLeft': 3,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();
    batch.set(_gameDoc(myUid), payload);
    batch.set(_gameDoc(partnerUid), payload);
    await batch.commit();
  }

  /// Uploads the entire finalized vector path array at once
  Future<void> submitDrawing(
    String artistUid,
    List<Map<String, double>> finalizedPaths,
  ) async {
    await _gameDoc(artistUid).update({
      'stage': 'guessing',
      'drawingPaths': finalizedPaths,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Evaluates guesses directly on the artist's authoritative state document
  Future<void> registerGuessAttempt({
    required String artistUid,
    required bool isCorrect,
    required int currentAttemptsLeft,
  }) async {
    final docRef = _gameDoc(artistUid);

    if (isCorrect) {
      await docRef.update({
        'stage': 'results',
        'isWin': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final nextAttempts = currentAttemptsLeft - 1;
      if (nextAttempts <= 0) {
        await docRef.update({
          'stage': 'results',
          'isWin': false,
          'attemptsLeft': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.update({'attemptsLeft': nextAttempts});
      }
    }
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
      'attemptsLeft': 3,
    };

    final batch = _firestore.batch();
    batch.set(_gameDoc(myUid), clearPayload);
    if (partnerUid.isNotEmpty) {
      batch.set(_gameDoc(partnerUid), clearPayload);
    }
    await batch.commit();
  }
}
