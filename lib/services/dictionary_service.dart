// lib/services/dictionary_service.dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:characters/characters.dart';

class DictionaryService {
  static Set<String> _validFourLetterWords = {};
  static bool _isLoaded = false;

  /// Returns true if the asset file loaded perfectly, false if it failed.
  static Future<bool> initialize() async {
    if (_isLoaded) return true;
    try {
      final String rawData = await rootBundle.loadString(
        'assets/four_letter_words.txt',
      );

      _validFourLetterWords = rawData
          .split(
            RegExp(r'\r?\n'),
          ) // Handles both Windows and Mac line breaks safely
          .map((word) => word.trim().toUpperCase())
          .where((word) => word.length == 4)
          .toSet();

      _isLoaded = true;
      return true;
    } catch (e) {
      // Fail-safe fallback list if path is wrong or asset isn't registered
      _validFourLetterWords = {'LANE', 'LATE', 'LINE', 'MIND', 'BIND', 'CORE'};
      return false;
    }
  }

  static Set<String> getValidFourLetterWords() => _validFourLetterWords;

  /// Strict dictionary check for BOTH modes to block fake words
  static bool isValidWord(String word, String gameMode) {
    final cleanWord = word.trim().toUpperCase();
    return _validFourLetterWords.contains(cleanWord);
  }

  /// Scans if there are any remaining legal modifications left for the current player
  static bool hasValidMovesLeft({
    required String currentWord,
    required List<int> lockedIndices,
    required List<String> wordsUsed,
    required String gameMode,
  }) {
    if (gameMode == 'coop') {
      if (currentWord.isEmpty) return true;
      final String lastChar = currentWord.characters.last.toUpperCase();

      for (String word in _validFourLetterWords) {
        if (word.startsWith(lastChar) && !wordsUsed.contains(word)) {
          return true;
        }
      }
      return false;
    } else {
      if (currentWord.isEmpty) return true;
      final List<String> currentLetters = currentWord.toUpperCase().split('');

      for (int i = 0; i < currentLetters.length; i++) {
        if (lockedIndices.contains(i)) continue;

        for (int charCode = 65; charCode <= 90; charCode++) {
          final String potentialChar = String.fromCharCode(charCode);
          if (currentLetters[i] == potentialChar) continue;

          List<String> testLetters = List.from(currentLetters);
          testLetters[i] = potentialChar;
          final String testWord = testLetters.join('');

          if (_validFourLetterWords.contains(testWord) &&
              !wordsUsed.contains(testWord)) {
            return true;
          }
        }
      }
      return false;
    }
  }
}
