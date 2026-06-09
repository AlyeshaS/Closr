// lib/tabs/play/trivia/trivia_dashboard_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'trivia_controller.dart';
import 'trivia_game_screen.dart';

class TriviaDashboardTab extends StatefulWidget {
  const TriviaDashboardTab({super.key});

  @override
  State<TriviaDashboardTab> createState() => _TriviaDashboardTabState();
}

class _TriviaDashboardTabState extends State<TriviaDashboardTab> {
  final TriviaController _controller = TriviaController();

  // TODO: Link these variables directly to your global Session getters/provider models
  final String myAuthUserEmail = 'user1@example.com';
  final String partnerAuthUserEmail = 'user2@example.com';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final String partnerName = "Your Partner";

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _controller.listenToMyTrivia(myAuthUserEmail),
      builder: (context, mySnapshot) {
        if (mySnapshot.hasData) {
          _controller.updateMyData(mySnapshot.data!);
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _controller.listenToPartnerTrivia(partnerAuthUserEmail),
          builder: (context, partnerSnapshot) {
            if (partnerSnapshot.hasData) {
              _controller.updatePartnerData(partnerSnapshot.data!);
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildScoreStat(
                          context,
                          '${_controller.myGlobalWins}',
                          'Your Wins',
                          cs.primary,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: cs.outlineVariant,
                        ),
                        _buildScoreStat(
                          context,
                          '${_controller.partnerGlobalWins}',
                          '$partnerName\'s Wins',
                          cs.secondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('GAMES', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          // Clean and simple: no more email parameters needed!
                          builder: (_) => const TriviaGameScreen(),
                        ),
                      );
                    },
                    // Ensure you close the child widget of your GestureDetector below
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF231519)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cs.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.star_rounded, color: cs.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Our Trivia',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: cs.onSurface,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getSubtitleMessage(),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getSubtitleMessage() {
    switch (_controller.myStage) {
      case 'setup':
        return 'Tap to set up your 10 profile answers!';
      case 'waiting':
        if (_controller.isPartnerSetupComplete &&
            _controller.myGuessesForPartner.length < 10) {
          return 'Your partner is ready! Tap to start guessing ✨';
        }
        return 'Waiting on your partner...';
      case 'guessing':
        return 'Round in progress! Finish guessing their answers.';
      case 'results':
        return 'Match complete! Tap to see who won.';
      default:
        return 'Tap to play a 10-question round';
    }
  }

  Widget _buildScoreStat(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            fontSize: 36,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
