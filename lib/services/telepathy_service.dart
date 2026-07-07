import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/telepathy_game_model.dart';

class TelepathyFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference _gameRef(String hostId, String gameId) {
    return _db
        .collection('users')
        .doc(hostId)
        .collection('games')
        .doc('play')
        .collection('telepathy_sessions')
        .doc(gameId);
  }

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

    // Set initial structural keys, preserving active presence tracking if it exists
    await _gameRef(
      hostId,
      gameId,
    ).set(newGame.toMap(), SetOptions(merge: true));
  }

  // Forces a new prompt seed word mid-game
  Future<void> changeSeedWord({
    required String hostId,
    required String gameId,
    required String newSeed,
  }) async {
    final docRef = _gameRef(hostId, gameId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final game = TelepathyGame.fromDocument(snapshot);
      final int activeIndex = game.currentRoundIndex;
      List<TelepathyRound> updatedRounds = List.from(game.rounds);

      // Overwrite the current round's prompt directly
      updatedRounds[activeIndex] = TelepathyRound(
        roundNumber: activeIndex,
        prompt: newSeed,
        player1Input: null, // Clear inputs so they start fresh on this word
        player2Input: null,
        isMatch: false,
      );

      transaction.update(docRef, {
        'seedWord': newSeed,
        'rounds': updatedRounds.map((r) => r.toMap()).toList(),
      });
    });
  }

  // Increments or decrements the presence counter safely
  Future<void> updatePresence({
    required String hostId,
    required String gameId,
    required int countChange,
    required String fallbackSeed,
  }) async {
    final docRef = _gameRef(hostId, gameId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        // If room doesn't exist at all, initialize it with 1 player
        if (countChange > 0) {
          final newGame = TelepathyGame(
            gameId: gameId,
            hostId: hostId,
            partnerId: 'partner',
            gameMode: GameMode.wordsOnly,
            seedWord: fallbackSeed,
            status: 'active',
            currentRoundIndex: 0,
            rounds: [TelepathyRound(roundNumber: 0, prompt: fallbackSeed)],
          );
          transaction.set(docRef, newGame.toMap());
          transaction.update(docRef, {'activePlayers': 1});
        }
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      int currentPresence = data['activePlayers'] ?? 0;
      int newPresence = (currentPresence + countChange).clamp(0, 2);

      // CRITICAL RULE: If presence drops to 0, or players enter a dead room (0 players),
      // we auto-reset the prompt with a brand new word path so it cycles fresh.
      if (newPresence == 1 && currentPresence == 0) {
        final game = TelepathyGame.fromDocument(snapshot);
        List<TelepathyRound> updatedRounds = [
          TelepathyRound(roundNumber: 0, prompt: fallbackSeed),
        ];
        transaction.update(docRef, {
          'seedWord': fallbackSeed,
          'status': 'active',
          'currentRoundIndex': 0,
          'rounds': updatedRounds.map((r) => r.toMap()).toList(),
          'activePlayers': 1,
        });
      } else {
        transaction.update(docRef, {'activePlayers': newPresence});
      }
    });
  }

  Stream<TelepathyGame> streamGame(String hostId, String gameId) {
    return _gameRef(hostId, gameId).snapshots().map((doc) {
      if (!doc.exists) {
        throw Exception("Document does not exist");
      }
      return TelepathyGame.fromDocument(doc);
    });
  }

  bool _areWordsMatching(String input1, String input2) {
    final String w1 = input1.trim().toLowerCase().replaceAll(
      RegExp(r"[^\w\s]"),
      "",
    );
    final String w2 = input2.trim().toLowerCase().replaceAll(
      RegExp(r"[^\w\s]"),
      "",
    );
    if (w1 == w2) return true;
    if (w1 + 's' == w2 || w2 + 's' == w1) return true;
    if (w1 + 'es' == w2 || w2 + 'es' == w1) return true;
    if (w1.endsWith('y') && w1.substring(0, w1.length - 1) + 'ies' == w2)
      return true;
    if (w2.endsWith('y') && w2.substring(0, w2.length - 1) + 'ies' == w1)
      return true;
    return false;
  }

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
