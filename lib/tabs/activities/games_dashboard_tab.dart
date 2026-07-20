// lib/play/games_dashboard_tab.dart
import 'package:flutter/material.dart';

class GamesDashboardTab extends StatefulWidget {
  const GamesDashboardTab({super.key});

  @override
  State<GamesDashboardTab> createState() => _GamesDashboardTabState();
}

class _GamesDashboardTabState extends State<GamesDashboardTab> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AVAILABLE GAMES',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 14),

          // Placeholder/Container for your 2-player app game modes
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cs.outlineVariant.withOpacity(0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.videogame_asset_rounded,
                  size: 48,
                  color: cs.primary.withOpacity(0.8),
                ),
                const SizedBox(height: 12),
                Text(
                  'Relationship Games',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Play customized split-screen or turn-based challenges together.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
