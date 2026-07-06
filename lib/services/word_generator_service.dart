// lib/features/telepathy/services/word_generator_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class WordGeneratorService {
  /// Fetches a random, common English noun using the highly reliable DataMuse API
  static Future<String> getRandomSeedWord() async {
    try {
      // Fetching common, popular nouns to keep the game fun and relatable
      final response = await http
          .get(
            Uri.parse(
              'https://api.datamuse.com/words?rel_jja=beautiful&max=50',
            ),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          // Shuffle the results and pick a random word from the top list
          data.shuffle();
          final String word = data.first['word'].toString();

          // Capitalize the first letter nicely for the UI
          return word[0].toUpperCase() + word.substring(1);
        }
      }
    } catch (e) {
      print("Word API error, falling back to local pool: $e");
    }

    // High-quality offline fallback pool just in case internet drops out
    final offlineFallbackPool = [
      'Camping',
      'Coffee',
      'Hollywood',
      'Space',
      'Ocean',
      'Breakfast',
      'Midnight',
      'Concert',
      'Roadtrip',
      'Picnic',
    ];
    return (offlineFallbackPool..shuffle()).first;
  }
}
