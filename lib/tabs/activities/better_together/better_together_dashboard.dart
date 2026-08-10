// lib/features/better_together/better_together_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/better_together_models.dart';
import 'better_together_controller.dart';
import 'better_together_game_screen.dart';

class BetterTogetherDashboard extends StatefulWidget {
  const BetterTogetherDashboard({super.key});

  @override
  State<BetterTogetherDashboard> createState() =>
      _BetterTogetherDashboardState();
}

class _BetterTogetherDashboardState extends State<BetterTogetherDashboard> {
  final BetterTogetherController _controller = BetterTogetherController();
  String _myUid = '';
  String _partnerUid = '';
  String _partnerEmail = '';
  bool _isLoading = true;
  bool _isClassicMode = false; // false = Perfect Pair, true = Classic

  @override
  void initState() {
    super.initState();
    _resolveSession();
  }

  void _resolveSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _myUid = user.uid;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_myUid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          _partnerEmail =
              (data['partnerEmailLower'] ?? data['partnerEmail'] ?? '')
                  .trim()
                  .toLowerCase();

          if (_partnerEmail.isNotEmpty) {
            var partnerQuery = await FirebaseFirestore.instance
                .collection('users')
                .where('emailLower', isEqualTo: _partnerEmail)
                .get();

            if (partnerQuery.docs.isEmpty) {
              partnerQuery = await FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: _partnerEmail)
                  .get();
            }

            if (partnerQuery.docs.isNotEmpty) {
              _partnerUid = partnerQuery.docs.first.id;
            }
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _handleGameRouting(PairDeck deck) async {
    if (_partnerUid.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      await _controller.startNewGame(
        myUid: _myUid,
        partnerUid: _partnerUid,
        deck: deck,
        isClassicMode: _isClassicMode,
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BetterTogetherGameScreen(
              myUid: _myUid,
              partnerUid: _partnerUid,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }

    if (_partnerUid.isEmpty) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                _partnerEmail.isEmpty
                    ? 'Link accounts with your partner in settings to start playing together!'
                    : 'Waiting for your partner to register an account with $_partnerEmail...',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 15,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Return to game options',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Sliding Pill Toggle
              _ModeToggle(
                cs: cs,
                isClassicMode: _isClassicMode,
                onChanged: (value) => setState(() => _isClassicMode = value),
              ),

              const SizedBox(height: 24),
              Text(
                'CHOOSE A THEMED DECK',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              ...PairDeck.values.map(
                (deck) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildDeckCard(context, deck, cs),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeckCard(BuildContext context, PairDeck deck, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _handleGameRouting(deck),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerLow : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cs.outlineVariant.withOpacity(0.9),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(deck.icon, color: cs.primary, size: 24),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deck.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isClassicMode
                        ? deck.pairs
                              .take(3)
                              .map((p) => '${p[0]}+${p[0]}')
                              .join('   ')
                        : deck.pairs
                              .take(3)
                              .map((p) => '${p[0]}+${p[1]}')
                              .join('   '),
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final ColorScheme cs;
  final bool isClassicMode;
  final ValueChanged<bool> onChanged;

  const _ModeToggle({
    required this.cs,
    required this.isClassicMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: cs.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: cs.onSurface.withOpacity(0.05)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = (constraints.maxWidth - 4) / 2;

          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 280),
                curve: Curves.fastOutSlowIn,
                alignment: isClassicMode
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: tabWidth,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFBF7),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.12),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _SlidingLabelButton(
                      active: !isClassicMode,
                      label: 'Perfect Pairs',
                      subtext: '🍿+🎬',
                      onTap: () => onChanged(false),
                      cs: cs,
                    ),
                  ),
                  Expanded(
                    child: _SlidingLabelButton(
                      active: isClassicMode,
                      label: 'Classic Pairs',
                      subtext: '🍿+🍿',
                      onTap: () => onChanged(true),
                      cs: cs,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SlidingLabelButton extends StatelessWidget {
  final bool active;
  final String label;
  final String subtext;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _SlidingLabelButton({
    required this.active,
    required this.label,
    required this.subtext,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 38,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w500 : FontWeight.w300,
                color: active
                    ? cs.onSurface
                    : cs.onSurfaceVariant.withOpacity(0.8),
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              subtext,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w500 : FontWeight.w300,
                color: cs.onSurfaceVariant.withOpacity(active ? 0.9 : 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
