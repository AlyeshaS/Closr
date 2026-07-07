import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/telepathy_game_model.dart';

class TelepathyFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference _playerGameRef(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('games')
        .doc('telepathy');
  }

  Future<void> startNewGame({
    required String gameId,
    required String myUid,
    required String partnerUid,
    required GameMode mode,
    required String seedWord,
  }) async {
    final newGame = TelepathyGame(
      gameId: gameId,
      hostId: myUid,
      partnerId: partnerUid,
      gameMode: mode,
      seedWord: seedWord,
      status: 'active',
      currentRoundIndex: 0,
      rounds: [
        TelepathyRound(roundNumber: 0, prompt: seedWord, isMatch: false),
      ],
    );

    final batch = _db.batch();
    batch.set(_playerGameRef(myUid), newGame.toMap());
    batch.set(_playerGameRef(partnerUid), newGame.toMap());
    await batch.commit();
  }

  Future<void> changeSeedWord({
    required TelepathyGame game,
    required String newSeed,
  }) async {
    final int activeIndex = game.currentRoundIndex;
    List<TelepathyRound> updatedRounds = List.from(game.rounds);

    updatedRounds[activeIndex] = TelepathyRound(
      roundNumber: activeIndex,
      prompt: newSeed,
      player1Input: null,
      player2Input: null,
      isMatch: false,
    );

    final Map<String, dynamic> updateData = {
      'seedWord': newSeed,
      'rounds': updatedRounds.map((r) => r.toMap()).toList(),
    };

    final batch = _db.batch();
    batch.update(_playerGameRef(game.hostId), updateData);
    batch.update(_playerGameRef(game.partnerId), updateData);
    await batch.commit();
  }

  Stream<DocumentSnapshot> streamGame(String myUid) {
    return _playerGameRef(myUid).snapshots();
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
    return false;
  }

  Future<void> submitInput({
    required String currentUserId,
    required String input,
    required TelepathyGame game,
  }) async {
    final int activeIndex = game.currentRoundIndex;
    List<TelepathyRound> updatedRounds = List.from(game.rounds);
    TelepathyRound currentRound = updatedRounds[activeIndex];

    final bool isHost = currentUserId == game.hostId;
    String? p1Input = isHost ? input : currentRound.player1Input;
    String? p2Input = !isHost ? input : currentRound.player2Input;

    Map<String, dynamic> updateData = {};

    if (p1Input != null && p2Input != null) {
      if (game.gameMode == GameMode.customPrompt && activeIndex == 0) {
        final String mergedPrompt = "${p1Input.trim()} + ${p2Input.trim()}";
        updatedRounds[activeIndex] = TelepathyRound(
          roundNumber: activeIndex,
          prompt: currentRound.prompt,
          player1Input: p1Input,
          player2Input: p2Input,
          isMatch: false,
        );
        updatedRounds.add(
          TelepathyRound(
            roundNumber: activeIndex + 1,
            prompt: mergedPrompt,
            isMatch: false,
          ),
        );

        updateData = {
          'rounds': updatedRounds.map((r) => r.toMap()).toList(),
          'currentRoundIndex': activeIndex + 1,
        };
      } else {
        bool isMatch = game.gameMode == GameMode.emojisOnly
            ? p1Input.trim() == p2Input.trim()
            : _areWordsMatching(p1Input, p2Input);

        updatedRounds[activeIndex] = TelepathyRound(
          roundNumber: activeIndex,
          prompt: currentRound.prompt,
          player1Input: p1Input,
          player2Input: p2Input,
          isMatch: isMatch,
        );

        if (isMatch) {
          updateData = {
            'rounds': updatedRounds.map((r) => r.toMap()).toList(),
            'status': 'completed',
          };
        } else {
          final String nextPrompt = "${p1Input.trim()} + ${p2Input.trim()}";
          updatedRounds.add(
            TelepathyRound(
              roundNumber: activeIndex + 1,
              prompt: nextPrompt,
              isMatch: false,
            ),
          );
          updateData = {
            'rounds': updatedRounds.map((r) => r.toMap()).toList(),
            'currentRoundIndex': activeIndex + 1,
          };
        }
      }
    } else {
      updatedRounds[activeIndex] = TelepathyRound(
        roundNumber: activeIndex,
        prompt: currentRound.prompt,
        player1Input: p1Input,
        player2Input: p2Input,
        isMatch: false,
      );
      updateData = {'rounds': updatedRounds.map((r) => r.toMap()).toList()};
    }

    final batch = _db.batch();
    batch.update(_playerGameRef(game.hostId), updateData);
    batch.update(_playerGameRef(game.partnerId), updateData);
    await batch.commit();
  }
}
