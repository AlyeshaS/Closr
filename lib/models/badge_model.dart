// lib/models/badge_model.dart
import 'package:flutter/material.dart';

enum BadgeCategory { tutorial, milestone, streak, games, scrapbook, romance }

class BadgeDefinition {
  final String id;
  final String title;
  final String description;
  final String statKey;
  final int target;
  final int points;
  final IconData icon;
  final BadgeCategory category;

  const BadgeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.statKey,
    required this.target,
    required this.points,
    required this.icon,
    required this.category,
  });
}

final List<BadgeDefinition> allBadges = [
  // --- TUTORIAL / ONBOARDING ---
  const BadgeDefinition(
    id: 'first_letter',
    title: 'First Spark',
    description: 'Send your first love letter or sweet note',
    statKey: 'letters_sent',
    target: 1,
    points: 50,
    icon: Icons.mark_email_read_rounded,
    category: BadgeCategory.tutorial,
  ),
  const BadgeDefinition(
    id: 'first_nudge',
    title: 'Gentle Touch',
    description: 'Send your first care nudge to your partner',
    statKey: 'nudges_sent',
    target: 1,
    points: 50,
    icon: Icons.volunteer_activism_rounded,
    category: BadgeCategory.tutorial,
  ),
  const BadgeDefinition(
    id: 'first_goal',
    title: 'Step Together',
    description: 'Complete your first shared couple goal',
    statKey: 'couple_goals_completed',
    target: 1,
    points: 50,
    icon: Icons.task_alt_rounded,
    category: BadgeCategory.tutorial,
  ),
  const BadgeDefinition(
    id: 'first_photo',
    title: 'Picture Perfect',
    description: 'Upload your first photo to the scrapbook',
    statKey: 'photos_count',
    target: 1,
    points: 50,
    icon: Icons.add_photo_alternate_rounded,
    category: BadgeCategory.tutorial,
  ),
  const BadgeDefinition(
    id: 'first_game',
    title: 'Playtime Begins',
    description: 'Play your first mini-game or quiz together',
    statKey: 'games_played',
    target: 1,
    points: 50,
    icon: Icons.sports_esports_rounded,
    category: BadgeCategory.tutorial,
  ),

  // --- TIME IN APP & ANNIVERSARY MILESTONES ---
  const BadgeDefinition(
    id: 'app_age_1m',
    title: 'Honeymoon Month',
    description: 'Use closr together for 1 month (30 days)',
    statKey: 'days_together_app',
    target: 30,
    points: 100,
    icon: Icons.calendar_month_rounded,
    category: BadgeCategory.milestone,
  ),
  const BadgeDefinition(
    id: 'app_age_3m',
    title: 'Quarter Milestone',
    description: 'Cherishing moments for 3 months (90 days)',
    statKey: 'days_together_app',
    target: 90,
    points: 200,
    icon: Icons.wb_twilight_rounded,
    category: BadgeCategory.milestone,
  ),
  const BadgeDefinition(
    id: 'app_age_6m',
    title: 'Half-Year Harmony',
    description: '6 months of shared memories in the app (180 days)',
    statKey: 'days_together_app',
    target: 180,
    points: 350,
    icon: Icons.loyalty_rounded,
    category: BadgeCategory.milestone,
  ),
  const BadgeDefinition(
    id: 'app_age_1y',
    title: 'Year One Complete',
    description: 'A full 365 days of building your digital world',
    statKey: 'days_together_app',
    target: 365,
    points: 600,
    icon: Icons.cake_rounded,
    category: BadgeCategory.milestone,
  ),
  const BadgeDefinition(
    id: 'app_age_2y',
    title: 'Timeless Duo',
    description: '2 whole years connected on closr (730 days)',
    statKey: 'days_together_app',
    target: 730,
    points: 1000,
    icon: Icons.workspace_premium_rounded,
    category: BadgeCategory.milestone,
  ),

  // --- GAMES PLAYED & WINS ---
  const BadgeDefinition(
    id: 'games_5',
    title: 'Casual Gamers',
    description: 'Play 5 mini-games or quizzes together',
    statKey: 'games_played',
    target: 5,
    points: 60,
    icon: Icons.extension_rounded,
    category: BadgeCategory.games,
  ),
  const BadgeDefinition(
    id: 'games_20',
    title: 'Dynamic Challengers',
    description: 'Play 20 interactive couple games',
    statKey: 'games_played',
    target: 20,
    points: 150,
    icon: Icons.videogame_asset_rounded,
    category: BadgeCategory.games,
  ),
  const BadgeDefinition(
    id: 'games_50',
    title: 'Arcade Royalty',
    description: 'Play 50 games together',
    statKey: 'games_played',
    target: 50,
    points: 300,
    icon: Icons.casino_rounded,
    category: BadgeCategory.games,
  ),
  const BadgeDefinition(
    id: 'games_won_10',
    title: 'Friendly Rivalry',
    description: 'Reach 10 total victories in head-to-head games',
    statKey: 'total_game_wins',
    target: 10,
    points: 100,
    icon: Icons.emoji_events_rounded,
    category: BadgeCategory.games,
  ),
  const BadgeDefinition(
    id: 'games_won_30',
    title: 'Master Strategists',
    description: 'Reach 30 total game victories',
    statKey: 'total_game_wins',
    target: 30,
    points: 250,
    icon: Icons.military_tech_rounded,
    category: BadgeCategory.games,
  ),
  const BadgeDefinition(
    id: 'perfect_sync',
    title: 'Mind Readers',
    description: 'Get a 100% match on 5 compatibility or quiz games',
    statKey: 'perfect_quiz_matches',
    target: 5,
    points: 200,
    icon: Icons.psychology_alt_rounded,
    category: BadgeCategory.games,
  ),

  // --- SCRAPBOOK PHOTO MILESTONES ---
  const BadgeDefinition(
    id: 'photo_5',
    title: 'Memory Novice',
    description: 'Add 5 photos to your shared scrapbook',
    statKey: 'photos_count',
    target: 5,
    points: 75,
    icon: Icons.photo_library_rounded,
    category: BadgeCategory.scrapbook,
  ),
  const BadgeDefinition(
    id: 'photo_20',
    title: 'Visual Diary',
    description: 'Add 20 photos to your scrapbook',
    statKey: 'photos_count',
    target: 20,
    points: 150,
    icon: Icons.collections_rounded,
    category: BadgeCategory.scrapbook,
  ),
  const BadgeDefinition(
    id: 'photo_50',
    title: 'Storytellers',
    description: 'Add 50 photos to your shared scrapbook',
    statKey: 'photos_count',
    target: 50,
    points: 250,
    icon: Icons.photo_album_rounded,
    category: BadgeCategory.scrapbook,
  ),
  const BadgeDefinition(
    id: 'photo_100',
    title: 'Museum of Us',
    description: 'Add 100 photos to your scrapbook',
    statKey: 'photos_count',
    target: 100,
    points: 450,
    icon: Icons.museum_rounded,
    category: BadgeCategory.scrapbook,
  ),

  // --- DAILY STREAKS ---
  const BadgeDefinition(
    id: 'streak_7',
    title: 'Week of Harmony',
    description: 'Maintain a 7-day active app streak',
    statKey: 'current_streak_days',
    target: 7,
    points: 120,
    icon: Icons.local_fire_department_rounded,
    category: BadgeCategory.streak,
  ),
  const BadgeDefinition(
    id: 'streak_30',
    title: 'Monthly Dedication',
    description: 'Maintain a 30-day active app streak',
    statKey: 'current_streak_days',
    target: 30,
    points: 250,
    icon: Icons.whatshot_rounded,
    category: BadgeCategory.streak,
  ),
  const BadgeDefinition(
    id: 'streak_100',
    title: 'Centennial Bond',
    description: 'Maintain a 100-day active app streak',
    statKey: 'current_streak_days',
    target: 100,
    points: 500,
    icon: Icons.diamond_rounded,
    category: BadgeCategory.streak,
  ),
];
