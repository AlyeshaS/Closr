enum GameMode { wordsOnly, emojisOnly, customPrompt }

class TelepathyGame {
  final String gameId;
  final String hostId;
  final String partnerId;
  final GameMode gameMode;
  final String seedWord;
  final String status;
  final int currentRoundIndex;
  final List<TelepathyRound> rounds;

  TelepathyGame({
    required this.gameId,
    required this.hostId,
    required this.partnerId,
    required this.gameMode,
    required this.seedWord,
    required this.status,
    required this.currentRoundIndex,
    required this.rounds,
  });

  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'hostId': hostId,
      'partnerId': partnerId,
      'gameMode': gameMode.name,
      'seedWord': seedWord,
      'status': status,
      'currentRoundIndex': currentRoundIndex,
      'rounds': rounds.map((r) => r.toMap()).toList(),
    };
  }

  factory TelepathyGame.fromDocument(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>;

    return TelepathyGame(
      gameId: data['gameId'] ?? '',
      hostId: data['hostId'] ?? '',
      partnerId: data['partnerId'] ?? '',
      gameMode: GameMode.values.firstWhere(
        (e) => e.name == data['gameMode'],
        orElse: () => GameMode.wordsOnly,
      ),
      seedWord: data['seedWord'] ?? '',
      status: data['status'] ?? 'active',
      currentRoundIndex: data['currentRoundIndex'] ?? 0,
      rounds:
          (data['rounds'] as List<dynamic>?)
              ?.map((r) => TelepathyRound.fromMap(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TelepathyRound {
  final int roundNumber;
  final String prompt;
  final String? player1Input;
  final String? player2Input;
  final bool isMatch;

  TelepathyRound({
    required this.roundNumber,
    required this.prompt,
    this.player1Input,
    this.player2Input,
    required this.isMatch,
  });

  Map<String, dynamic> toMap() {
    return {
      'roundNumber': roundNumber,
      'prompt': prompt,
      'player1Input': player1Input,
      'player2Input': player2Input,
      'isMatch': isMatch,
    };
  }

  factory TelepathyRound.fromMap(Map<String, dynamic> map) {
    return TelepathyRound(
      roundNumber: map['roundNumber'] ?? 0,
      prompt: map['prompt'] ?? '',
      player1Input: map['player1Input'],
      player2Input: map['player2Input'],
      isMatch: map['isMatch'] ?? false,
    );
  }
}
