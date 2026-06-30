// lib/play/letter_locked/letter_locked_models.dart

class LetterLockedModel {
  final String gameId;
  final String coupleId;
  final String gameType; // 'letter_locked'
  final String gameMode; // 'coop' or 'versus'
  final String status; // 'active', 'completed', 'archived'
  final String turn; // UID of the player whose turn it is
  final String winnerUid; // ✨ DEFINED COMPONENT FIELD

  // Game data specific to LetterLocked
  final String currentWord;
  final List<int> lockedIndices;
  final List<String> boardLetters;
  final List<String> usedLetters;
  final List<String> wordsUsed; // Tracked list for duplicate prevention
  final Map<String, int> scores; // uid: score

  LetterLockedModel({
    required this.gameId,
    required this.coupleId,
    required this.gameType,
    required this.gameMode,
    required this.status,
    required this.turn,
    required this.winnerUid, // ✨ DEFINED NAMED CONSTRUCTOR PARAMETER
    required this.currentWord,
    required this.lockedIndices,
    required this.boardLetters,
    required this.usedLetters,
    required this.wordsUsed,
    required this.scores,
  });

  factory LetterLockedModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    final gameData = data['gameData'] as Map<String, dynamic>? ?? {};
    final scoresMap = gameData['scores'] as Map<String, dynamic>? ?? {};

    return LetterLockedModel(
      gameId: id,
      coupleId: data['coupleId'] ?? '',
      gameType: data['gameType'] ?? 'letter_locked',
      gameMode: data['gameMode'] ?? 'coop',
      status: data['status'] ?? 'active',
      turn: data['turn'] ?? '',
      winnerUid: data['winnerUid'] ?? '', // ✨ DEFINED FACTORY MAPPING VALUE
      currentWord: gameData['currentWord'] ?? '',
      lockedIndices: List<int>.from(gameData['lockedIndices'] ?? []),
      boardLetters: List<String>.from(gameData['boardLetters'] ?? []),
      usedLetters: List<String>.from(gameData['usedLetters'] ?? []),
      wordsUsed: List<String>.from(gameData['wordsUsed'] ?? []),
      scores: scoresMap.map((key, value) => MapEntry(key, value as int)),
    );
  }
}
