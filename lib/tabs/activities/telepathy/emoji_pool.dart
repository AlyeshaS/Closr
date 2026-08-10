// lib/features/telepathy/presentation/emoji_pool.dart
import 'dart:math';

class EmojiPool {
  static final Random _random = Random();

  /// Generates a completely random emoji from standard non-text Unicode ranges
  static String getRandomEmoji() {
    // Curated emoji blocks excluding regional indicators/flag letters (0x1F1E6 - 0x1F1FF)
    final List<List<int>> ranges = [
      [0x1F600, 0x1F64F], // Smileys & Emoticons (😀 - 🙏)
      [0x1F330, 0x1F37F], // Nature & Food (🌱 - 🍿)
      [0x1F300, 0x1F5FF], // Symbols & Pictographs (🌌 - 🗿)
      [0x1F680, 0x1F6FF], // Transport & Map Symbols (🚀 - 🛑)
      [0x1F900, 0x1F9FF], // Supplemental Pictographs (🧠 - 🦪)
    ];

    // Pick a random category range
    final selectedRange = ranges[_random.nextInt(ranges.length)];

    // Generate a random code point within that category
    final int codePoint =
        selectedRange[0] +
        _random.nextInt(selectedRange[1] - selectedRange[0] + 1);

    return String.fromCharCode(codePoint);
  }
}
