import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/love_letter_service.dart';
import '../../models/love_letter.dart';
import 'compose_love_letter.dart';
import 'love_letter_detail.dart';

class LoveLettersTab extends StatefulWidget {
  const LoveLettersTab({super.key});

  @override
  State<LoveLettersTab> createState() => _LoveLettersTabState();
}

class _LoveLettersTabState extends State<LoveLettersTab>
    with SingleTickerProviderStateMixin {
  bool _showSent = false;
  late final AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // 1. Full-screen drifting background hearts canvas[cite: 3]
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              color: cs.surface, // Clean theme background[cite: 3]
              child: Stack(
                children: [
                  for (int i = 0; i < 40; i++)
                    _buildBackgroundHeart(i, cs, _bgAnimationController),
                ],
              ),
            ),
          ),
        ),

        // 2. Main content layer[cite: 3]
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: StreamBuilder<List<LoveLetter>>(
              initialData: const <LoveLetter>[],
              stream: LoveLetterService().streamForCurrentUser(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final letters = snapshot.data ?? [];
                final user = FirebaseAuth.instance.currentUser;
                final uid = user?.uid ?? '';
                final received = letters
                    .where((l) => l.recipientId == uid)
                    .toList();
                final sent = letters.where((l) => l.senderId == uid).toList();
                final listToShow = _showSent ? sent : received;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LettersToggle(
                      cs: cs,
                      showSent: _showSent,
                      sentCount: sent.length,
                      receivedCount: received.length,
                      onChanged: (value) => setState(() => _showSent = value),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: listToShow.isEmpty
                            ? _buildEmptyState(context, cs, isSent: _showSent)
                            : ListView.separated(
                                key: ValueKey<bool>(_showSent),
                                padding: const EdgeInsets.only(bottom: 100),
                                itemCount: listToShow.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 14),
                                itemBuilder: (context, idx) {
                                  final letter = listToShow[idx];
                                  if (_showSent) {
                                    return LoveLetterTile(
                                      letter: letter,
                                      isSent: true,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ComposeLoveLetterPage(
                                            editingLetter: letter,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  return LoveLetterTile(
                                    letter: letter,
                                    isSent: false,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LoveLetterDetailPage(
                                          letter: letter,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // 3. Floating Action Button[cite: 3]
        Positioned(
          right: 20,
          bottom: 24,
          child: FloatingActionButton.extended(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            elevation: 3,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComposeLoveLetterPage()),
            ),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text(
              'Write',
              style: TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundHeart(
    int i,
    ColorScheme cs,
    AnimationController controller,
  ) {
    final rand = math.Random(i * 4231);
    final x = (rand.nextDouble() * 2) - 1;
    final y = (rand.nextDouble() * 2) - 1;
    final size = 12.0 + rand.nextDouble() * 26;
    final opacity = 0.03 + rand.nextDouble() * 0.05;

    final hSpeed = 0.8 + rand.nextDouble() * 0.7;
    final vSpeed = 0.8 + rand.nextDouble() * 0.7;
    final phase = rand.nextDouble() * math.pi * 2;

    return Align(
      alignment: Alignment(x, y),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final t = controller.value * math.pi * 2 + phase;
          final dx = math.sin(t * hSpeed) * 16.0;
          final dy = math.cos(t * vSpeed) * 14.0;
          final rot = math.sin(t * 0.4) * 0.2;

          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: rot,
              child: Opacity(
                opacity: opacity,
                child: Icon(
                  Icons.favorite_rounded,
                  size: size,
                  color: cs.primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme cs, {
    required bool isSent,
  }) {
    final title = isSent ? 'No sent letters yet' : 'No received letters yet';
    final message = isSent
        ? 'Letters you send will appear here, ready to reopen later.'
        : 'Letters from your partner will land here like little keepsakes.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSent ? Icons.send_rounded : Icons.mail_outline_rounded,
              size: 36,
              color: cs.primary.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant.withOpacity(0.6),
                fontWeight: FontWeight.w300,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LettersToggle extends StatelessWidget {
  final ColorScheme cs;
  final bool showSent;
  final int sentCount;
  final int receivedCount;
  final ValueChanged<bool> onChanged;

  const _LettersToggle({
    required this.cs,
    required this.showSent,
    required this.sentCount,
    required this.receivedCount,
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
                alignment: showSent
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: tabWidth,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _SlidingLabelButton(
                      active: showSent,
                      icon: Icons.outbox_rounded,
                      label: 'Sent',
                      count: sentCount,
                      onTap: () => onChanged(true),
                      cs: cs,
                    ),
                  ),
                  Expanded(
                    child: _SlidingLabelButton(
                      active: !showSent,
                      icon: Icons.all_inbox_rounded,
                      label: 'Received',
                      count: receivedCount,
                      onTap: () => onChanged(false),
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
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _SlidingLabelButton({
    required this.active,
    required this.icon,
    required this.label,
    required this.count,
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
            Icon(
              icon,
              size: 15,
              color: active ? cs.primary : cs.onSurfaceVariant.withOpacity(0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w400 : FontWeight.w300,
                color: active
                    ? cs.onSurface
                    : cs.onSurfaceVariant.withOpacity(0.8),
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? cs.primaryContainer.withOpacity(0.6)
                    : cs.onSurface.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w300,
                  color: active
                      ? cs.primary
                      : cs.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Redesigned: Cards featuring rich shadows and primary colored borders
class LoveLetterTile extends StatelessWidget {
  final LoveLetter letter;
  final bool isSent;
  final VoidCallback onTap;

  const LoveLetterTile({
    required this.letter,
    required this.isSent,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        // Softened home page primary border color
        border: Border.all(color: cs.primary.withOpacity(0.2), width: 1.0),
        boxShadow: [
          // Single, incredibly soft ambient drop shadow
          BoxShadow(
            color: cs.shadow.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.06),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSent
                                  ? Icons.outbox_rounded
                                  : Icons.all_inbox_rounded,
                              size: 13,
                              color: cs.primary.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(letter.createdAt),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: cs.onSurface.withOpacity(0.55),
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.2,
                                ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: cs.primary.withOpacity(0.35),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    letter.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withOpacity(0.85),
                      fontWeight: FontWeight.w300,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
