import 'dart:math';

class EmojiPool {
  static final Random _random = Random();

  /// Generates a completely random emoji from standard Unicode ranges
  static String getRandomEmoji() {
    // A mix of popular emoji blocks (Smileys, Animals, Food, Activities)
    final List<List<int>> ranges = [
      [0x1F600, 0x1F64F], // Emoticons (😀 - 🙏)
      [0x1F1E6, 0x1F1FF], // Flags
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
