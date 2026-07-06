import 'package:cloud_firestore/cloud_firestore.dart';

enum GameMode { wordsOnly, emojisOnly }

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
    this.isMatch = false,
  });

  factory TelepathyRound.fromMap(Map<String, dynamic> map) {
    return TelepathyRound(
      roundNumber: map['roundNumber'] ?? 0,
      prompt: map['prompt'] ?? '',
      player1Input: map['player1_input'],
      player2Input: map['player2_input'],
      isMatch: map['isMatch'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roundNumber': roundNumber,
      'prompt': prompt,
      'player1_input': player1Input,
      'player2_input': player2Input,
      'isMatch': isMatch,
    };
  }
}

class TelepathyGame {
  final String gameId;
  final String hostId;
  final String partnerId;
  final GameMode gameMode;
  final String seedWord;
  final String status; // 'active' or 'completed'
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

  factory TelepathyGame.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final roundsList = (data['rounds'] as List? ?? [])
        .map((r) => TelepathyRound.fromMap(Map<String, dynamic>.from(r)))
        .toList();

    return TelepathyGame(
      gameId: doc.id,
      hostId: data['hostId'] ?? '',
      partnerId: data['partnerId'] ?? '',
      gameMode: data['gameMode'] == 'emojis_only'
          ? GameMode.emojisOnly
          : GameMode.wordsOnly,
      seedWord: data['seedWord'] ?? '',
      status: data['status'] ?? 'active',
      currentRoundIndex: data['currentRoundIndex'] ?? 0,
      rounds: roundsList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'partnerId': partnerId,
      'gameMode': gameMode == GameMode.emojisOnly
          ? 'emojis_only'
          : 'words_only',
      'seedWord': seedWord,
      'status': status,
      'currentRoundIndex': currentRoundIndex,
      'rounds': rounds.map((r) => r.toMap()).toList(),
    };
  }
}
