// lib/play/letter_locked/letter_locked_controller.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/dictionary_service.dart';

class LetterLockedController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _gameDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('games')
        .doc('letterlocked');
  }

  DocumentReference<Map<String, dynamic>> _legacyGameDoc(String roomId) {
    return _firestore.collection('games').doc(roomId);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToGame(
    String myUid, {
    String? legacyRoomId,
  }) {
    final primaryStream = _gameDoc(myUid).snapshots();

    if (legacyRoomId == null || legacyRoomId.isEmpty) {
      return primaryStream;
    }

    return primaryStream.asyncExpand((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return Stream.value(snapshot);
      }

      return _legacyGameDoc(legacyRoomId).snapshots();
    });
  }

  Future<void> migrateLegacyRoomIfNeeded({
    required String myUid,
    required String partnerUid,
    required String legacyRoomId,
  }) async {
    if (legacyRoomId.isEmpty || partnerUid.isEmpty) return;

    final primarySnapshot = await _gameDoc(myUid).get();
    if (primarySnapshot.exists && primarySnapshot.data() != null) {
      return;
    }

    final legacySnapshot = await _legacyGameDoc(legacyRoomId).get();
    if (!legacySnapshot.exists || legacySnapshot.data() == null) {
      return;
    }

    final data = Map<String, dynamic>.from(legacySnapshot.data()!);
    data['gameId'] = 'letterlocked';

    final batch = _firestore.batch();
    batch.set(_gameDoc(myUid), data, SetOptions(merge: true));
    batch.set(_gameDoc(partnerUid), data, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> startNewGame({
    required String myUid,
    required String partnerUid,
    required String mode,
    Map<String, int>? existingScores,
  }) async {
    List<String> startingBoard = [];
    String baseWord = '';

    if (mode == 'coop') {
      final List<String> alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
      alphabet.shuffle(Random());
      startingBoard = alphabet.take(9).toList();
    } else {
      baseWord = DictionaryService.getRandomFourLetterWord();
    }

    Map<String, int> finalScores = existingScores ?? {myUid: 0, partnerUid: 0};

    final payload = {
      'gameId': 'letterlocked',
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
    };

    final batch = _firestore.batch();
    batch.set(_gameDoc(myUid), payload);
    batch.set(_gameDoc(partnerUid), payload);
    await batch.commit();
  }

  Future<void> submitMove({
    required String myUid,
    required String partnerUid,
    required String newWord,
    required List<int> updatedLockedIndices,
    required List<String> updatedUsedLetters,
    required bool isCoopTurn,
  }) async {
    final cleanWord = newWord.toUpperCase();

    // 🛠️ FIX: Use root dot-notation to cleanly merge game data parameters safely
    final Map<String, dynamic> payload = {
      'turn': partnerUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'gameData.currentWord': cleanWord,
      'gameData.lockedIndices': updatedLockedIndices,
      'gameData.usedLetters': updatedUsedLetters,
      'gameData.wordsUsed': FieldValue.arrayUnion([cleanWord]),
    };

    final batch = _firestore.batch();
    batch.set(_gameDoc(myUid), payload, SetOptions(merge: true));
    batch.set(_gameDoc(partnerUid), payload, SetOptions(merge: true));

    // 🏆 CENTRALIZED SCORE ROUTING: Points are pushed out to the main user directory
    if (!isCoopTurn) {
      final myUserDoc = _firestore.collection('users').doc(myUid);
      batch.set(myUserDoc, {
        'scores': {'letterlocked': FieldValue.increment(1)},
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }
}
