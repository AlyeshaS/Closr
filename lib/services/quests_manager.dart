// lib/services/quests_manager.dart
import 'dart:math';

class QuestItem {
  final String id;
  final String title;
  final String emoji;

  QuestItem({required this.id, required this.title, required this.emoji});

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'emoji': emoji,
    'done': false,
  };
}

class QuestsManager {
  static final List<QuestItem> _questPool = [
    QuestItem(
      id: 'cook_recipe',
      title: 'Cook a new recipe together',
      emoji: '🍳',
    ),
    QuestItem(id: 'watch_sunset', title: 'Watch the sunset', emoji: '🌅'),
    QuestItem(
      id: 'write_compliment',
      title: 'Write each other a compliment',
      emoji: '💌',
    ),
    QuestItem(
      id: 'take_photo',
      title: 'Take a photo together today',
      emoji: '📸',
    ),
    QuestItem(id: 'coffee_shop', title: 'Try a new coffee shop', emoji: '☕'),
    QuestItem(id: 'board_game', title: 'Play a board game', emoji: '🎲'),
    QuestItem(
      id: 'craft_project',
      title: 'Work on a DIY craft project',
      emoji: '🎨',
    ),
    QuestItem(
      id: 'deep_questions',
      title: 'Ask each other 3 deep questions',
      emoji: '🧠',
    ),
    QuestItem(
      id: 'park_walk',
      title: 'Explore a new local park or trail',
      emoji: '🌲',
    ),
    QuestItem(
      id: 'late_treat',
      title: 'Go on a late-night treat run',
      emoji: '🍦',
    ),
    QuestItem(
      id: 'stargazing',
      title: 'Spend 10 minutes stargazing tonight',
      emoji: '✨',
    ),
    QuestItem(
      id: 'playlist_build',
      title: 'Build a shared 5-song playlist',
      emoji: '🎵',
    ),
    QuestItem(
      id: 'bake_treat',
      title: 'Bake a dessert completely from scratch',
      emoji: '🧁',
    ),
    QuestItem(
      id: 'stretching',
      title: 'Do a 10-minute partner stretch routine',
      emoji: '🧘',
    ),
    QuestItem(
      id: 'book_read',
      title: 'Read a chapter of a book out loud to each other',
      emoji: '📖',
    ),
  ];

  static List<Map<String, dynamic>> generateWeeklyQuests({
    List<String> lastWeekIds = const [],
  }) {
    final availablePool = _questPool
        .where((quest) => !lastWeekIds.contains(quest.id))
        .toList();
    final selectionPool = availablePool.length >= 6
        ? availablePool
        : _questPool;

    final random = Random();
    final shuffled = List<QuestItem>.from(selectionPool)..shuffle(random);
    return shuffled.take(6).map((q) => q.toMap()).toList();
  }

  /// Calculates the DateTime for the most recent Sunday at 12:00 AM
  static DateTime getMostRecentSundayMidnight() {
    DateTime now = DateTime.now();
    // DateTime.weekday returns 1 for Monday, 7 for Sunday.
    int daysSinceSunday = now.weekday % 7;
    DateTime lastSunday = now.subtract(Duration(days: daysSinceSunday));

    return DateTime(lastSunday.year, lastSunday.month, lastSunday.day, 0, 0, 0);
  }
}
