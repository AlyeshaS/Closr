// lib/features/telepathy/presentation/telepathy_controller.dart
import 'package:flutter/material.dart';
import '../../../models/telepathy_game_model.dart';
import '../../../services/telepathy_service.dart';

class TelepathyController extends ChangeNotifier {
  final TelepathyFirebaseService _service = TelepathyFirebaseService();
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  /// Maps the updated raw DocumentSnapshot stream into a clean TelepathyGame model stream
  Stream<TelepathyGame> watchGame(String myUid) {
    return _service
        .streamGame(myUid)
        .map((doc) => TelepathyGame.fromDocument(doc));
  }

  /// Submits the single link guess using the updated signature properties
  Future<void> submitGuess({
    required String userId,
    required String input,
    required TelepathyGame game,
  }) async {
    setLoading(true);
    try {
      await _service.submitInput(
        currentUserId: userId,
        input: input,
        game: game,
      );
    } finally {
      setLoading(false);
    }
  }
}
