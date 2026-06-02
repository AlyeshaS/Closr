import 'package:cloud_firestore/cloud_firestore.dart';

enum TimelineEntryType { scrapbook, watch, loveLetter, activity }

class TimelineEntry {
  final String id;
  final TimelineEntryType type;
  final String title;
  final String subtitle;
  final String emoji;
  final DateTime occurredAt;
  final bool isMilestone;

  const TimelineEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.occurredAt,
    required this.isMilestone,
  });

  String get typeLabel => switch (type) {
    TimelineEntryType.scrapbook => 'Scrapbook',
    TimelineEntryType.watch => 'Watch',
    TimelineEntryType.loveLetter => 'Love Letter',
    TimelineEntryType.activity => 'Activity',
  };

  static String activityTitleFor(String activity) {
    return switch (activity) {
      'quest_completed' => 'Completed a quest',
      'deep_talk_generate' => 'Generated Deep Talk topics',
      'deep_talk_view' => 'Used Deep Talk',
      'deep_talk_complete' => 'Completed Deep Talk',
      'date_suggestion_generated' => 'Generated date ideas',
      'date_ideas_view' => 'Browsed date ideas',
      _ => activity.replaceAll('_', ' '),
    };
  }

  static String activitySubtitleFor(
    String activity,
    int currentStreak,
    int bestStreak,
  ) {
    return switch (activity) {
      'quest_completed' => 'Progress logged for your streak',
      'deep_talk_generate' => 'Fresh prompts were added to your flow',
      'deep_talk_view' => 'Conversation notes were opened',
      'deep_talk_complete' => 'All 10 questions were explored',
      'date_suggestion_generated' => 'A new idea was saved for later',
      'date_ideas_view' => 'Ideas were refreshed for the day',
      _ => 'Streak $currentStreak · Best $bestStreak',
    };
  }

  static String activityEmojiFor(String activity) {
    return switch (activity) {
      'quest_completed' => '✅',
      'deep_talk_generate' => '✨',
      'deep_talk_view' => '💬',
      'deep_talk_complete' => '🗣️',
      'date_suggestion_generated' => '💡',
      'date_ideas_view' => '🌷',
      _ => '⭐',
    };
  }

  static String loveLetterSnippet() {
    return 'Love letter sent';
  }

  static Map<String, Object?> activityPayload({
    required String activity,
    required DateTime occurredAt,
    required int currentStreak,
    required int bestStreak,
  }) {
    return {
      'type': TimelineEntryType.activity.name,
      'activity': activity,
      'title': activityTitleFor(activity),
      'subtitle': activitySubtitleFor(activity, currentStreak, bestStreak),
      'emoji': activityEmojiFor(activity),
      'occurredAt': Timestamp.fromDate(occurredAt),
      'isMilestone': currentStreak > 0 && currentStreak % 7 == 0,
      'createdAt': Timestamp.fromDate(occurredAt),
    };
  }

  factory TimelineEntry.fromActivityDoc(String id, Map<String, dynamic> data) {
    final occurredTs = data['occurredAt'] as Timestamp?;
    return TimelineEntry(
      id: id,
      type: TimelineEntryType.activity,
      title: (data['title'] as String?) ?? 'Activity logged',
      subtitle: (data['subtitle'] as String?) ?? '',
      emoji: (data['emoji'] as String?) ?? '⭐',
      occurredAt: occurredTs?.toDate() ?? DateTime.now(),
      isMilestone: (data['isMilestone'] as bool?) ?? false,
    );
  }
}
