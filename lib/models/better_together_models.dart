// lib/models/better_together_models.dart
import 'package:flutter/material.dart';

enum PairDeck {
  food('Food', Icons.restaurant_rounded, [
    ['🍿', '🎬'],
    ['🍓', '🍫'],
    ['☕', '🍩'],
    ['🍔', '🍟'],
    ['🧀', '🍷'],
    ['🌮', '🥑'],
  ]),
  cute('Cute', Icons.favorite_rounded, [
    ['🌙', '⭐'],
    ['🐝', '🍯'],
    ['🌧️', '🌈'],
    ['🐈', '🧶'],
    ['🌸', '🦋'],
    ['🕯️', '📖'],
  ]),
  travel('Travel', Icons.flight_takeoff_rounded, [
    ['✈️', '🧳'],
    ['🏖️', '🕶️'],
    ['⛰️', '⛺'],
    ['🚀', '🪐'],
    ['🗺️', '📍'],
    ['📸', '🖼️'],
  ]);

  final String label;
  final IconData icon;
  final List<List<String>> pairs;
  const PairDeck(this.label, this.icon, this.pairs);
}

class CardTile {
  final int id;
  final String content;
  final int pairId;

  CardTile({required this.id, required this.content, required this.pairId});

  Map<String, dynamic> toMap() => {
    'id': id,
    'content': content,
    'pairId': pairId,
  };

  factory CardTile.fromMap(Map<String, dynamic> map) {
    return CardTile(
      id: map['id'] ?? 0,
      content: map['content'] ?? '',
      pairId: map['pairId'] ?? 0,
    );
  }
}

class BetterTogetherGame {
  final String gameId;
  final String hostId;
  final String partnerId;
  final String status;
  final String turn;
  final String deckName;
  final bool isClassicMode;
  final List<CardTile> board;
  final List<int> flippedIndices;
  final Map<String, String> matchedPairsBy; // pairId String -> player UID
  final Map<String, int> scores;

  BetterTogetherGame({
    required this.gameId,
    required this.hostId,
    required this.partnerId,
    required this.status,
    required this.turn,
    required this.deckName,
    required this.isClassicMode,
    required this.board,
    required this.flippedIndices,
    required this.matchedPairsBy,
    required this.scores,
  });

  factory BetterTogetherGame.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    final gameData = data['gameData'] as Map<String, dynamic>? ?? {};
    final boardRaw = gameData['board'] as List<dynamic>? ?? [];

    return BetterTogetherGame(
      gameId: id,
      hostId: data['hostId'] ?? '',
      partnerId: data['partnerId'] ?? '',
      status: data['status'] ?? 'active',
      turn: data['turn'] ?? '',
      deckName: gameData['deckName'] ?? PairDeck.food.name,
      isClassicMode: gameData['isClassicMode'] ?? false,
      board: boardRaw
          .map((e) => CardTile.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      flippedIndices: List<int>.from(gameData['flippedIndices'] ?? []),
      matchedPairsBy: Map<String, String>.from(
        gameData['matchedPairsBy'] ?? {},
      ),
      scores: Map<String, int>.from(gameData['scores'] ?? {}),
    );
  }
}
