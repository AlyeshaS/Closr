import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/telepathy_game_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TelepathyFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Path Helper: Routes through user's subcollections to target the 'play' document
  DocumentReference _gameRef(String hostId, String gameId) {
    return _db
        .collection('users')
        .doc(hostId)
        .collection('games')
        .doc('play')
        .collection('telepathy_sessions')
        .doc(gameId);
  }

  // Create a brand new game
  Future<void> startNewGame({
    required String gameId,
    required String hostId,
    required String partnerId,
    required GameMode mode,
    required String seedWord,
  }) async {
    final newGame = TelepathyGame(
      gameId: gameId,
      hostId: hostId,
      partnerId: partnerId,
      gameMode: mode,
      seedWord: seedWord,
      status: 'active',
      currentRoundIndex: 0,
      rounds: [TelepathyRound(roundNumber: 0, prompt: seedWord)],
    );

    await _gameRef(hostId, gameId).set(newGame.toMap());
  }

  // Real-time updates listener stream
  Stream<TelepathyGame> streamGame(String hostId, String gameId) {
    return _gameRef(hostId, gameId).snapshots().map((doc) {
      if (!doc.exists) {
        throw Exception("Document does not exist");
      }
      return TelepathyGame.fromDocument(doc);
    });
  }

  // Smart matching helper to handle singular vs plural and basic typos
  bool _areWordsMatching(String input1, String input2) {
    // 1. Clean both inputs: lowercase, remove extra spaces, and strip punctuation/apostrophes
    final String w1 = input1.trim().toLowerCase().replaceAll(
      RegExp(r"[^\w\s]"),
      "",
    );
    final String w2 = input2.trim().toLowerCase().replaceAll(
      RegExp(r"[^\w\s]"),
      "",
    );

    // 2. Exact match check
    if (w1 == w2) return true;

    // 3. Handle standard plurals ending in 's' (e.g., "smore" vs "smores")
    if (w1 + 's' == w2 || w2 + 's' == w1) return true;

    // 4. Handle plurals ending in 'es' (e.g., "box" vs "boxes")
    if (w1 + 'es' == w2 || w2 + 'es' == w1) return true;

    // 5. Handle common relationship/y-to-ies mutations (e.g., "puppy" vs "puppies")
    if (w1.endsWith('y') && w1.substring(0, w1.length - 1) + 'ies' == w2)
      return true;
    if (w2.endsWith('y') && w2.substring(0, w2.length - 1) + 'ies' == w1)
      return true;

    return false;
  }

  // Lock an input inside the dynamic transaction boundary
  Future<void> submitInput({
    required String hostId,
    required String gameId,
    required String userId,
    required String input,
    required TelepathyGame currentGame,
  }) async {
    final docRef = _gameRef(hostId, gameId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final game = TelepathyGame.fromDocument(snapshot);
      final int activeIndex = game.currentRoundIndex;
      List<TelepathyRound> updatedRounds = List.from(game.rounds);
      TelepathyRound currentRound = updatedRounds[activeIndex];

      final bool isHost = userId == game.hostId;

      String? p1Input = isHost ? input : currentRound.player1Input;
      String? p2Input = !isHost ? input : currentRound.player2Input;

      if (p1Input != null && p2Input != null) {
        bool isMatch = false;
        if (game.gameMode == GameMode.emojisOnly) {
          isMatch = p1Input.trim() == p2Input.trim();
        } else {
          // Evaluates using our smart matching helper rules
          isMatch = _areWordsMatching(p1Input, p2Input);
        }

        if (isMatch) {
          updatedRounds[activeIndex] = TelepathyRound(
            roundNumber: activeIndex,
            prompt: currentRound.prompt,
            player1Input: p1Input,
            player2Input: p2Input,
            isMatch: true,
          );
          transaction.update(docRef, {
            'rounds': updatedRounds.map((r) => r.toMap()).toList(),
            'status': 'completed',
          });
        } else {
          updatedRounds[activeIndex] = TelepathyRound(
            roundNumber: activeIndex,
            prompt: currentRound.prompt,
            player1Input: p1Input,
            player2Input: p2Input,
            isMatch: false,
          );

          final String nextPrompt = "${p1Input.trim()} + ${p2Input.trim()}";
          updatedRounds.add(
            TelepathyRound(roundNumber: activeIndex + 1, prompt: nextPrompt),
          );

          transaction.update(docRef, {
            'rounds': updatedRounds.map((r) => r.toMap()).toList(),
            'currentRoundIndex': activeIndex + 1,
          });
        }
      } else {
        updatedRounds[activeIndex] = TelepathyRound(
          roundNumber: activeIndex,
          prompt: currentRound.prompt,
          player1Input: p1Input,
          player2Input: p2Input,
          isMatch: false,
        );
        transaction.update(docRef, {
          'rounds': updatedRounds.map((r) => r.toMap()).toList(),
        });
      }
    });
  }
}
