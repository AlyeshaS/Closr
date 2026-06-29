// lib/play/letter_locked/letter_locked_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class LetterLockedController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream to listen to the shared LetterLocked game room document
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToGame(String roomId) {
    return _firestore
        .collection('games')
        .doc(roomId) // Mapped explicitly to clean email-resolved path
        .snapshots();
  }

  /// Initializes a brand new match room for LetterLocked
  Future<void> startNewGame({
    required String roomId,
    required String myUid,
    required String partnerUid,
    required String mode, // 'coop' or 'versus'
  }) async {
    // Standard starting letters for a co-op match or empty state for versus
    List<String> startingBoard = mode == 'coop'
        ? ['T', 'A', 'E', 'L', 'M', 'K', 'S', 'O', 'R']
        : [];

    await _firestore.collection('games').doc(roomId).set({
      'gameId': roomId,
      'gameType': 'letter_locked',
      'gameMode': mode,
      'status': 'active',
      'turn': myUid, // Whichever player clicks start goes first
      'updatedAt': FieldValue.serverTimestamp(),
      'gameData': {
        'currentWord': mode == 'versus'
            ? 'LANE'
            : '', // Versus needs a starting trap word
        'lockedIndices': [],
        'boardLetters': startingBoard,
        'usedLetters': [],
        'scores': {myUid: 0, partnerUid: 0},
      },
    });
  }

  /// Submits a player's move and flips the turn to the partner
  Future<void> submitMove({
    required String roomId,
    required String partnerUid,
    required String newWord,
    required List<int> updatedLockedIndices,
    required List<String> updatedUsedLetters,
  }) async {
    await _firestore.collection('games').doc(roomId).update({
      'turn': partnerUid, // Toggle turn to partner immediately
      'updatedAt': FieldValue.serverTimestamp(),
      'gameData.currentWord': newWord.toUpperCase(),
      'gameData.lockedIndices': updatedLockedIndices,
      'gameData.usedLetters': updatedUsedLetters,
    });
  }
}
