// lib/features/better_together/better_together_controller.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/better_together_models.dart';

class BetterTogetherController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _gameDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('games')
        .doc('bettertogether');
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToGame(String myUid) {
    return _gameDoc(myUid).snapshots();
  }

  Future<void> startNewGame({
    required String myUid,
    required String partnerUid,
    required PairDeck deck,
    required bool isClassicMode,
  }) async {
    List<CardTile> tiles = [];
    int tileId = 0;

    for (int pairIdx = 0; pairIdx < deck.pairs.length; pairIdx++) {
      final pair = deck.pairs[pairIdx];

      if (isClassicMode) {
        final String emoji = pair[0];
        tiles.add(CardTile(id: tileId++, content: emoji, pairId: pairIdx));
        tiles.add(CardTile(id: tileId++, content: emoji, pairId: pairIdx));
      } else {
        tiles.add(CardTile(id: tileId++, content: pair[0], pairId: pairIdx));
        tiles.add(CardTile(id: tileId++, content: pair[1], pairId: pairIdx));
      }
    }
    tiles.shuffle(Random());

    final payload = {
      'gameId': 'bettertogether',
      'gameType': 'better_together',
      'hostId': myUid,
      'partnerId': partnerUid,
      'status': 'active',
      'turn': myUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'gameData': {
        'deckName': deck.name,
        'isClassicMode': isClassicMode,
        'board': tiles.map((t) => t.toMap()).toList(),
        'flippedIndices': [],
        'matchedPairsBy': {}, // Map pairId -> UID
        'scores': {myUid: 0, partnerUid: 0},
      },
    };

    final batch = _firestore.batch();
    batch.set(_gameDoc(myUid), payload);
    batch.set(_gameDoc(partnerUid), payload);
    await batch.commit();
  }

  Future<void> selectCard({
    required String myUid,
    required String partnerUid,
    required BetterTogetherGame game,
    required int index,
  }) async {
    if (game.flippedIndices.contains(index) ||
        game.matchedPairsBy.containsKey(game.board[index].pairId.toString())) {
      return;
    }

    final newFlipped = List<int>.from(game.flippedIndices)..add(index);

    if (newFlipped.length == 1) {
      final updates = {'gameData.flippedIndices': newFlipped};
      final batch = _firestore.batch();
      batch.update(_gameDoc(myUid), updates);
      batch.update(_gameDoc(partnerUid), updates);
      await batch.commit();
    } else if (newFlipped.length == 2) {
      final firstTile = game.board[newFlipped[0]];
      final secondTile = game.board[newFlipped[1]];
      final bool isMatch = firstTile.pairId == secondTile.pairId;

      final batch = _firestore.batch();

      if (isMatch) {
        final Map<String, String> newMatchedBy = Map.from(game.matchedPairsBy);
        newMatchedBy[firstTile.pairId.toString()] = myUid;

        final bool isGameOver = newMatchedBy.length == (game.board.length ~/ 2);
        final int myCurrentScore = (game.scores[myUid] ?? 0) + 1;
        final int partnerScore = game.scores[partnerUid] ?? 0;

        final Map<String, dynamic> updates = {
          'gameData.flippedIndices': [],
          'gameData.matchedPairsBy': newMatchedBy,
          'gameData.scores.$myUid': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (isGameOver) {
          updates['status'] = 'completed';

          // Score increments for winner
          if (myCurrentScore > partnerScore) {
            final myScoreRef = _firestore
                .collection('users')
                .doc(myUid)
                .collection('scores')
                .doc('bettertogether');
            batch.set(myScoreRef, {
              'wins': FieldValue.increment(1),
            }, SetOptions(merge: true));
          } else if (partnerScore > myCurrentScore) {
            final partnerScoreRef = _firestore
                .collection('users')
                .doc(partnerUid)
                .collection('scores')
                .doc('bettertogether');
            batch.set(partnerScoreRef, {
              'wins': FieldValue.increment(1),
            }, SetOptions(merge: true));
          }
        }

        batch.update(_gameDoc(myUid), updates);
        batch.update(_gameDoc(partnerUid), updates);
        await batch.commit();
      } else {
        batch.update(_gameDoc(myUid), {'gameData.flippedIndices': newFlipped});
        batch.update(_gameDoc(partnerUid), {
          'gameData.flippedIndices': newFlipped,
        });
        await batch.commit();

        await Future.delayed(const Duration(milliseconds: 1000));

        final resetBatch = _firestore.batch();
        final resetUpdates = {
          'turn': partnerUid,
          'gameData.flippedIndices': [],
          'updatedAt': FieldValue.serverTimestamp(),
        };
        resetBatch.update(_gameDoc(myUid), resetUpdates);
        resetBatch.update(_gameDoc(partnerUid), resetUpdates);
        await resetBatch.commit();
      }
    }
  }
}
