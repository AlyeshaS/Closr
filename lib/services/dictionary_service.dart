// lib/services/dictionary_service.dart
import 'package:flutter/services.dart' show rootBundle;

class DictionaryService {
  // Using a Set gives us a O(1) instant lookup time complexity
  static Set<String> _validFourLetterWords = {};
  static bool _isLoaded = false;

  /// Loads the text asset file into memory on startup
  static Future<void> initialize() async {
    if (_isLoaded) return;
    try {
      // Reads the full document from assets
      final String rawData = await rootBundle.loadString(
        'assets/four_letter_words.txt',
      );

      // Splits lines and sanitizes white spaces/returns
      _validFourLetterWords = rawData
          .split('\n')
          .map((word) => word.trim().toUpperCase())
          .where((word) => word.length == 4)
          .toSet();

      _isLoaded = true;
    } catch (e) {
      // Fail-safe fallbacks if asset path reading errors out
      _validFourLetterWords = {'LANE', 'LATE', 'LINE', 'MIND', 'BIND', 'CORE'};
    }
  }

  /// Exposes the dictionary for the engine's background simulation checks
  static Set<String> getValidFourLetterWords() {
    return _validFourLetterWords;
  }

  /// Master turn checker
  static bool isValidWord(String word, String gameMode) {
    final cleanWord = word.trim().toUpperCase();

    if (gameMode == 'versus') {
      return _validFourLetterWords.contains(cleanWord);
    }

    // Co-op mode basic validation
    return cleanWord.length >= 2 && RegExp(r'^[A-Z]+$').hasMatch(cleanWord);
  }
}
