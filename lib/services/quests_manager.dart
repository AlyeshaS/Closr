// lib/services/quests_manager.dart
import 'dart:math';

class QuestItem {
  final String id;
  final String title;
  final String icon;

  QuestItem({required this.id, required this.title, required this.icon});

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'icon': icon,
    'done': false,
  };
}

class QuestsManager {
  static final List<QuestItem> _questPool = [
    QuestItem(
      id: 'cook_recipe',
      title: 'Cook a new recipe together',
      icon: 'food',
    ),
    QuestItem(id: 'watch_sunset', title: 'Watch the sunset', icon: 'photo'),
    QuestItem(
      id: 'write_compliment',
      title: 'Write each other a compliment',
      icon: 'letter',
    ),
    QuestItem(
      id: 'take_photo',
      title: 'Take a photo together today',
      icon: 'photo',
    ),
    QuestItem(id: 'coffee_shop', title: 'Try a new coffee shop', icon: 'food'),
    QuestItem(id: 'board_game', title: 'Play a board game', icon: 'game'),
    QuestItem(
      id: 'craft_project',
      title: 'Work on a DIY craft project',
      icon: 'heart',
    ),
    QuestItem(
      id: 'deep_questions',
      title: 'Ask each other 3 deep questions',
      icon: 'chat',
    ),
    QuestItem(
      id: 'park_walk',
      title: 'Explore a new local park or trail',
      icon: 'walk',
    ),
    QuestItem(
      id: 'late_treat',
      title: 'Go on a late-night treat run',
      icon: 'food',
    ),
    QuestItem(
      id: 'stargazing',
      title: 'Spend 10 minutes stargazing tonight',
      icon: 'chat',
    ),
    QuestItem(
      id: 'playlist_build',
      title: 'Build a shared 5-song playlist',
      icon: 'movie',
    ),
    QuestItem(
      id: 'bake_treat',
      title: 'Bake a dessert completely from scratch',
      icon: 'food',
    ),
    QuestItem(
      id: 'stretching',
      title: 'Do a 10-minute partner stretch routine',
      icon: 'walk',
    ),
    QuestItem(
      id: 'book_read',
      title: 'Read a chapter of a book out loud to each other',
      icon: 'letter',
    ),
  ];

  static Future<List<Map<String, dynamic>>> generateWeeklyQuestsAsync({
    List<String> lastWeekIds = const [],
    int count = 6,
  }) async {
    return generateWeeklyQuests(lastWeekIds: lastWeekIds, count: count);
  }

  static List<Map<String, dynamic>> generateWeeklyQuests({
    List<String> lastWeekIds = const [],
    int count = 6,
  }) {
    final availablePool = _questPool
        .where((quest) => !lastWeekIds.contains(quest.id))
        .toList();
    final selectionPool = availablePool.length >= count
        ? availablePool
        : _questPool;

    final random = Random();
    final shuffled = List<QuestItem>.from(selectionPool)..shuffle(random);
    return shuffled.take(count).map((q) => q.toMap()).toList();
  }

  static DateTime getMostRecentSundayMidnight() {
    DateTime now = DateTime.now();
    int daysSinceSunday = now.weekday % 7;
    DateTime lastSunday = now.subtract(Duration(days: daysSinceSunday));
    return DateTime(lastSunday.year, lastSunday.month, lastSunday.day, 0, 0, 0);
  }
}
