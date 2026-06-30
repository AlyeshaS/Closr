// lib/play/letter_locked/letter_locked_controller.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/dictionary_service.dart';

class LetterLockedController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToGame(String roomId) {
    return _firestore.collection('games').doc(roomId).snapshots();
  }

  Future<void> startNewGame({
    required String roomId,
    required String myUid,
    required String partnerUid,
    required String mode,
    Map<String, int>? existingScores,
  }) async {
    List<String> startingBoard = [];
    String baseWord = '';

    if (mode == 'coop') {
      // 🎲 DYNAMIC CO-OP BOARD: Randomly choose 9 unique letters
      final List<String> alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
      alphabet.shuffle(Random());
      startingBoard = alphabet.take(9).toList();
    } else {
      // 🎲 DYNAMIC VERSUS WORD: Grab a random valid 4-letter word from your asset dictionary file
      baseWord = DictionaryService.getRandomFourLetterWord();
    }

    Map<String, int> finalScores = existingScores ?? {myUid: 0, partnerUid: 0};

    await _firestore.collection('games').doc(roomId).set({
      'gameId': roomId,
      'gameType': 'letter_locked',
      'gameMode': mode,
      'status': 'active',
      'turn': myUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'gameData': {
        'currentWord': baseWord,
        'lockedIndices': [],
        'boardLetters': startingBoard,
        'usedLetters': [],
        'wordsUsed': baseWord.isNotEmpty ? [baseWord] : [],
        'scores': finalScores,
      },
    });
  }

  Future<void> submitMove({
    required String roomId,
    required String myUid,
    required String partnerUid,
    required String newWord,
    required List<int> updatedLockedIndices,
    required List<String> updatedUsedLetters,
    required bool isCoopTurn,
  }) async {
    final cleanWord = newWord.toUpperCase();

    final Map<String, dynamic> updates = {
      'turn': partnerUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'gameData.currentWord': cleanWord,
      'gameData.lockedIndices': updatedLockedIndices,
      'gameData.usedLetters': updatedUsedLetters,
      'gameData.wordsUsed': FieldValue.arrayUnion([cleanWord]),
    };

    if (!isCoopTurn) {
      updates['gameData.scores.$myUid'] = FieldValue.increment(1);
    }

    await _firestore.collection('games').doc(roomId).update(updates);
  }
}
