import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/love_letter_service.dart';
import '../../widgets/love_letter_tile.dart';
import '../../models/love_letter.dart';
import 'compose_love_letter.dart';

class LoveLettersTab extends StatefulWidget {
  const LoveLettersTab({super.key});

  @override
  State<LoveLettersTab> createState() => _LoveLettersTabState();
}

class _LoveLettersTabState extends State<LoveLettersTab> {
  bool _showSent = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(child: Container(color: cs.surface)),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 106),
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
                    Expanded(
                      child: _SectionShell(
                        cs: cs,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                              child: _LettersToggle(
                                cs: cs,
                                showSent: _showSent,
                                sentCount: sent.length,
                                receivedCount: received.length,
                                onChanged: (value) =>
                                    setState(() => _showSent = value),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 240),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                                child: listToShow.isEmpty
                                    ? _buildEmptyState(
                                        context,
                                        cs,
                                        isSent: _showSent,
                                      )
                                    : ListView.separated(
                                        key: ValueKey<bool>(_showSent),
                                        padding: const EdgeInsets.fromLTRB(
                                          14,
                                          0,
                                          14,
                                          14,
                                        ),
                                        itemCount: listToShow.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 12),
                                        itemBuilder: (context, idx) {
                                          final letter = listToShow[idx];
                                          if (_showSent) {
                                            return LoveLetterTile(
                                              letter: letter,
                                              isSent: true,
                                              onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ComposeLoveLetterPage(
                                                        editingLetter: letter,
                                                      ),
                                                ),
                                              ),
                                            );
                                          }

                                          return LoveLetterTile(
                                            letter: letter,
                                            isSent: false,
                                          );
                                        },
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 24,
          child: FloatingActionButton.extended(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ComposeLoveLetterPage()),
            ),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Write'),
          ),
        ),
      ],
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
    final chipText = isSent ? 'Send your first one' : 'Wait for a reply';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primaryContainer,
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Icon(
                isSent ? Icons.send_rounded : Icons.mail_outline_rounded,
                size: 34,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Text(
                chipText,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.primary,
                ),
              ),
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              active: showSent,
              icon: Icons.send_rounded,
              label: 'Sent ($sentCount)',
              onTap: () => onChanged(true),
              cs: cs,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ToggleButton(
              active: !showSent,
              icon: Icons.inbox_rounded,
              label: 'Received ($receivedCount)',
              onTap: () => onChanged(false),
              cs: cs,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _ToggleButton({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          scale: active ? 1.0 : 0.985,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: active ? cs.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: cs.outlineVariant.withOpacity(0.14),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: active ? cs.onSurface : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  final ColorScheme cs;
  final Widget child;

  const _SectionShell({super.key, required this.cs, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: cs.outlineVariant.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Generate many floating hearts for a soft background pattern
          for (int i = 0; i < 50; i++) _buildHeart(i, cs),
          // Main content
          child,
        ],
      ),
    );
  }

  Widget _buildHeart(int i, ColorScheme cs) {
    // Evenly distribute hearts in a grid, add tiny jitter for natural look
    const total = 50;
    final cols = (math.sqrt(total)).ceil();
    final rows = (total / cols).ceil();
    final col = i % cols;
    final row = i ~/ cols;

    final rand = math.Random(i * 7919);
    final jitterX = (rand.nextDouble() - 0.5) * 0.18; // small horizontal jitter
    final jitterY = (rand.nextDouble() - 0.5) * 0.14; // small vertical jitter

    double x;
    if (cols == 1) {
      x = 0.0;
    } else {
      x = (col / (cols - 1)) * 2 - 1; // -1..1
    }

    double y;
    if (rows == 1) {
      y = 0.0;
    } else {
      y = (row / (rows - 1)) * 2 - 1; // -1..1
    }

    x = (x + jitterX).clamp(-1.0, 1.0);
    y = (y + jitterY).clamp(-1.0, 1.0);

    final size = 10 + rand.nextDouble() * 36; // 10..46
    final opacity = 0.03 + rand.nextDouble() * 0.06; // 0.03..0.09
    final durationSeconds = 4 + rand.nextInt(5); // 4..8
    final hRange = 0.6 + rand.nextDouble() * 1.4; // small movement
    final vRange = 0.6 + rand.nextDouble() * 1.0; // small movement
    final rotation = (rand.nextDouble() - 0.5) * 0.4; // subtle tilt
    final delayMs = rand.nextInt(900);

    return Align(
      alignment: Alignment(x as double, y as double),
      child: _FloatingHeart(
        size: size,
        color: cs.primary.withOpacity(opacity),
        duration: Duration(seconds: durationSeconds),
        horizontalRange: hRange,
        verticalRange: vRange,
        rotation: rotation,
        delay: Duration(milliseconds: delayMs),
      ),
    );
  }
}

class _FloatingHeart extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;
  final double horizontalRange;
  final double verticalRange;
  final double rotation;
  final Duration delay;

  const _FloatingHeart({
    super.key,
    required this.size,
    required this.color,
    required this.duration,
    this.horizontalRange = 6,
    this.verticalRange = 6,
    this.rotation = 0.0,
    this.delay = Duration.zero,
  });

  @override
  State<_FloatingHeart> createState() => _FloatingHeartState();
}

class _FloatingHeartState extends State<_FloatingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    if (widget.delay > Duration.zero) {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.repeat(reverse: true);
      });
    } else {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value * math.pi * 2;
        final dx = math.sin(t) * widget.horizontalRange;
        final dy = math.cos(t) * widget.verticalRange * 0.6;
        final rot = widget.rotation * math.sin(t * 0.5);

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(angle: rot, child: child),
        );
      },
      child: Icon(
        Icons.favorite_rounded,
        size: widget.size,
        color: widget.color,
      ),
    );
  }
}
