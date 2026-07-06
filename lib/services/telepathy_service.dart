import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/telepathy_game_model.dart';

class TelepathyFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Path Helper: Updated to route through the 'play' document structure
  DocumentReference _gameRef(String hostId, String gameId) {
    return _db
        .collection('users')
        .doc(hostId)
        .collection('games')
        .doc('play') // Your specific structural mid-folder layer
        .collection(
          'telepathy_sessions',
        ) // Collection containing specific round instances
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
    return _gameRef(
      hostId,
      gameId,
    ).snapshots().map((doc) => TelepathyGame.fromDocument(doc));
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
          isMatch =
              p1Input.trim().toLowerCase() == p2Input.trim().toLowerCase();
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
