import 'package:flutter/material.dart';
import '../../../models/telepathy_game_model.dart';
import "../../../services/telepathy_service.dart";

class TelepathyController extends ChangeNotifier {
  final TelepathyFirebaseService _service = TelepathyFirebaseService();
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  Stream<TelepathyGame> watchGame(String hostId, String gameId) {
    return _service.streamGame(hostId, gameId);
  }

  Future<void> submitGuess({
    required String hostId,
    required String gameId,
    required String userId,
    required String input,
    required TelepathyGame game,
  }) async {
    setLoading(true);
    try {
      await _service.submitInput(
        hostId: hostId,
        gameId: gameId,
        userId: userId,
        input: input,
        currentGame: game,
      );
    } finally {
      setLoading(false);
    }
  }
}
