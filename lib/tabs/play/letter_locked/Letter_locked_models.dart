class LetterLockedModel {
  final String gameId;
  final String coupleId;
  final String gameType;
  final String gameMode;
  final String status;
  final String turn;

  final String currentWord;
  final List<int> lockedIndices;
  final List<String> boardLetters;
  final List<String> usedLetters;
  final List<String>
  wordsUsed; // 1️⃣ Check that this exact property field is here!
  final Map<String, int> scores;

  LetterLockedModel({
    required this.gameId,
    required this.coupleId,
    required this.gameType,
    required this.gameMode,
    required this.status,
    required this.turn,
    required this.currentWord,
    required this.lockedIndices,
    required this.boardLetters,
    required this.usedLetters,
    required this.wordsUsed, // 2️⃣ Check that this parameter is here!
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
      currentWord: gameData['currentWord'] ?? '',
      lockedIndices: List<int>.from(gameData['lockedIndices'] ?? []),
      boardLetters: List<String>.from(gameData['boardLetters'] ?? []),
      usedLetters: List<String>.from(gameData['usedLetters'] ?? []),
      wordsUsed: List<String>.from(
        gameData['wordsUsed'] ?? [],
      ), // 3️⃣ Check that this parser is here!
      scores: scoresMap.map((key, value) => MapEntry(key, value as int)),
    );
  }
}
