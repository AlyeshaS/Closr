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
    final cleanInput = input.trim().toUpperCase();
    final currentRound = game.rounds[game.currentRoundIndex];

    if (cleanInput == currentRound.prompt.trim().toUpperCase()) {
      throw ArgumentError('PROMPT_MATCH_VIOLATION');
    }

    for (final round in game.rounds) {
      if (round.prompt.trim().toUpperCase() == cleanInput ||
          round.player1Input?.trim().toUpperCase() == cleanInput ||
          round.player2Input?.trim().toUpperCase() == cleanInput) {
        throw ArgumentError('DUPLICATE_ENTRY_VIOLATION');
      }
    }

    if (game.gameMode == GameMode.emojisOnly && !_isOnlyEmojis(input)) {
      throw ArgumentError('EMOJI_ONLY_VIOLATION');
    }

    if (game.gameMode != GameMode.emojisOnly && _containsEmoji(input)) {
      throw ArgumentError('WORD_MODE_NO_EMOJI_VIOLATION');
    }

    final int activeIndex = game.currentRoundIndex;
    List<TelepathyRound> updatedRounds = List.from(game.rounds);
    TelepathyRound activeRound = updatedRounds[activeIndex];

    final bool isHost = currentUserId == game.hostId;
    String? p1Input = isHost ? input : activeRound.player1Input;
    String? p2Input = !isHost ? input : activeRound.player2Input;

    Map<String, dynamic> updateData = {};

    if (p1Input != null && p2Input != null) {
      if (game.gameMode == GameMode.customPrompt && activeIndex == 0) {
        final String mergedPrompt = "${p1Input.trim()} + ${p2Input.trim()}";
        updatedRounds[activeIndex] = TelepathyRound(
          roundNumber: activeIndex,
          prompt: activeRound.prompt,
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
          prompt: activeRound.prompt,
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
        prompt: activeRound.prompt,
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

/// Checks if a string contains only valid emoji characters
bool _isOnlyEmojis(String text) {
  if (text.trim().isEmpty) return false;

  // Regular expression matching standard emojis, symbols, modifiers, and pictographs
  final RegExp emojiRegex = RegExp(
    r'^[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E6}-\u{1F1FF}'
    r'\u{2700}-\u{27BF}\u{1F900}-\u{1F9FF}\u{1F018}-\u{1F0F5}\u{1F004}\u{1F170}-\u{1F19A}'
    r'\u{1F200}-\u{1F251}\u{1F300}-\u{1F5FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}'
    r'\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FAFF}'
    r'\u{2600}-\u{26FF}\u{2300}-\u{23FF}\u{2B50}\u{2B55}\u{2934}\u{2935}\u{2190}-\u{21FF}]+$',
    unicode: true,
  );

  // Remove invisible whitespaces/spaces before checking matching rules
  return emojiRegex.hasMatch(text.trim().replaceAll(' ', ''));
}

bool _containsEmoji(String text) {
  if (text.trim().isEmpty) return false;

  for (final rune in text.runes) {
    if ((rune >= 0x1F300 && rune <= 0x1FAFF) ||
        (rune >= 0x2600 && rune <= 0x27BF) ||
        (rune >= 0x1F1E6 && rune <= 0x1F1FF)) {
      return true;
    }
  }

  return false;
}
