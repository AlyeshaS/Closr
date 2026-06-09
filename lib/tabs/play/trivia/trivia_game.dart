// lib/screens/activities/trivia/models/trivia_game.dart

class TriviaQuestion {
  final String questionText;
  final List<String> options;
  final int creatorAnswerIndex; // What the partner actually prefers
  final int? guesserGuessIndex; // What the user guessed they prefer

  TriviaQuestion({
    required this.questionText,
    required this.options,
    required this.creatorAnswerIndex,
    this.guesserGuessIndex,
  });

  bool get isCorrect => creatorAnswerIndex == guesserGuessIndex;
}

class TriviaGame {
  final String id;
  final String creatorId;
  final String guesserId;
  final String status; // 'setup', 'waiting_for_guesser', 'completed'
  final List<TriviaQuestion> questions;

  TriviaGame({
    required this.id,
    required this.creatorId,
    required this.guesserId,
    required this.status,
    required this.questions,
  });

  // Calculate scores dynamically based on the 10 questions
  int get correctGuessesCount => questions.where((q) => q.isCorrect).length;
}
