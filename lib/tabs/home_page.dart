// lib/tabs/home_page.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../gemini_service.dart';
import '../_expandable_match_tile.dart';
import '../widgets/sprite_animator.dart';

// Companion option helper to support dynamic frame counts per sprite sheet
class _CompanionOption {
  final String emoji;
  final String defaultName;
  final String species;
  final String assetPath;
  final int totalFrames;
  final double frameWidth;
  final double frameHeight;
  const _CompanionOption(
    this.emoji,
    this.defaultName,
    this.species,
    this.assetPath,
    this.totalFrames,
    this.frameWidth,
    this.frameHeight,
  );
}

const _kCompanions = [
  _CompanionOption(
    '🐱',
    'Mochi',
    'Cat',
    'assets/images/cat.png',
    7,
    32.0,
    32.0,
  ),
  _CompanionOption(
    '🐶',
    'Biscuit',
    'Dog',
    'assets/images/dog.png',
    10,
    32.0,
    32.0,
  ),
  _CompanionOption(
    '🐢',
    'Shelly',
    'Turtle',
    'assets/images/turtle.png',
    8,
    32.0,
    32.0,
  ),
  // _CompanionOption(
  //   '🐼',
  //   'Bao',
  //   'Panda',
  //   'assets/images/panda.png',
  //   4,
  //   64.0,
  //   64.0,
  // ),
  _CompanionOption(
    '🐻',
    'Cosmo',
    'Bear',
    'assets/images/bear.png',
    7,
    32.0,
    32.0,
  ),
  _CompanionOption(
    '🐦',
    'Lilac',
    'Bird',
    'assets/images/IdleBird.png',
    6,
    16.0,
    16.0,
  ),
  _CompanionOption(
    '🐰',
    'Brownie',
    'Bunny',
    'assets/images/bunny.png',
    12,
    32.0,
    32.0,
  ),
  _CompanionOption(
    '🐨',
    'Kobi',
    'Koala',
    'assets/images/koala.png',
    7,
    32.0,
    32.0,
  ),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _entrance;
  late final AnimationController _pulse;
  late final AnimationController _flicker;
  final GeminiService _geminiService = GeminiService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _flicker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    _flicker.dispose();
    super.dispose();
  }

  Animation<double> _seg(double start, double end) {
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = FirebaseAuth.instance.currentUser;
    final cs = Theme.of(context).colorScheme;
    final firstName = user?.displayName?.split(' ').first ?? 'there';

    return Stack(
      children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting ──────────────────────────────────────────────
                _Reveal(
                  animation: _seg(0.0, 0.45),
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.displayMedium,
                      children: [
                        const TextSpan(text: 'Hello, '),
                        TextSpan(
                          text: '$firstName.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _Reveal(
                  animation: _seg(0.06, 0.5),
                  child: Text(
                    'Here\'s your day at a glance',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // ── Companion Orb (Syncs with Settings & Equipped Accessories) ──
                Center(
                  child: Column(
                    children: [
                      _Reveal(
                        animation: _seg(0.1, 0.65),
                        beginOffset: const Offset(0, 0.06),
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: user != null
                              ? FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .snapshots()
                              : null,
                          builder: (context, snapshot) {
                            final data =
                                snapshot.data?.data() as Map<String, dynamic>?;

                            final companionSource =
                                (data?['companionAsset'] as String?) ??
                                (data?['companionLottie'] as String?) ??
                                'assets/images/IdleCattt.png';

                            final companionEmoji =
                                (data?['companionEmoji'] as String?) ?? '🐱';

                            final equipped = List<String>.from(
                              (data?['equippedAccessories'] as List?) ??
                                  const [],
                            );

                            return _CharacterOrb(
                              cs: cs,
                              pulse: _pulse,
                              source: companionSource,
                              fallbackEmoji: companionEmoji,
                              equippedAccessories: equipped,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Reveal(
                        animation: _seg(0.18, 0.65),
                        beginOffset: const Offset(0, 0.06),
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: user != null
                              ? FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .snapshots()
                              : null,
                          builder: (context, snapshot) {
                            final data =
                                snapshot.data?.data() as Map<String, dynamic>?;
                            final name =
                                (data?['companionName'] as String?) ??
                                'YOUR COMPANION';

                            return Text(
                              name.toUpperCase(),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    letterSpacing: 1.2,
                                    color: cs.onSurfaceVariant,
                                  ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // ── Stat Row ──────────────────────────────────────────────
                _Reveal(
                  animation: _seg(0.2, 0.7),
                  beginOffset: const Offset(0, 0.08),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 176,
                          child: _MatchedDatesCard(
                            cs: cs,
                            pulse: _pulse,
                            stream: user != null
                                ? FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('matched_suggestions')
                                      .snapshots()
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 176,
                          child: _StreakCard(
                            user: user,
                            cs: cs,
                            pulse: _pulse,
                            flicker: _flicker,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // ── Tip of the Day ────────────────────────────────────────
                _Reveal(
                  animation: _seg(0.32, 0.8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel(text: 'Tip of the day', cs: cs),
                      const SizedBox(height: 10),
                      _GlassCard(
                        cs: cs,
                        glowColor: cs.primary,
                        gradientColors: [
                          cs.primaryContainer.withOpacity(0.85),
                          cs.secondaryContainer.withOpacity(0.55),
                        ],
                        child: FutureBuilder<String>(
                          future: _geminiService.fetchQuoteOfTheDay(),
                          builder: (context, snapshot) {
                            final loading =
                                snapshot.connectionState ==
                                ConnectionState.waiting;
                            final tipText = snapshot.hasError
                                ? 'Could not load tip.'
                                : (snapshot.data ?? '');

                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(
                                    opacity: anim,
                                    child: SizeTransition(
                                      sizeFactor: anim,
                                      axisAlignment: -1,
                                      child: child,
                                    ),
                                  ),
                              child: loading
                                  ? _TipLoading(
                                      key: const ValueKey('tip-loading'),
                                      cs: cs,
                                    )
                                  : _TipLoaded(
                                      key: const ValueKey('tip-loaded'),
                                      cs: cs,
                                      tipText: tipText,
                                    ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // ── Recent Matches ────────────────────────────────────────
                _Reveal(
                  animation: _seg(0.45, 0.95),
                  child: _RecentMatchesSection(user: user, cs: cs),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Original Entrance & Design Components ─────────────────────────────────

class _Reveal extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final Offset beginOffset;
  final double beginScale;

  const _Reveal({
    required this.animation,
    required this.child,
    this.beginOffset = const Offset(0, 0.06),
    this.beginScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(
              beginOffset.dx * 60 * (1 - t),
              beginOffset.dy * 60 * (1 - t),
            ),
            child: Transform.scale(
              scale: beginScale + (1 - beginScale) * t,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final ColorScheme cs;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final List<Color>? gradientColors;
  final Color? glowColor;

  const _GlassCard({
    required this.child,
    required this.cs,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.gradientColors,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final glow = glowColor ?? cs.primary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.07),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: glow.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    gradientColors ??
                    [
                      cs.surface.withOpacity(0.55),
                      cs.primaryContainer.withOpacity(0.35),
                    ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: cs.primary.withOpacity(0.35), width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _Pill({required this.text, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final ColorScheme cs;
  final double size;
  const _IconBadge({required this.icon, required this.cs, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.7),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: size, color: cs.primary),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _SectionLabel({required this.text, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
        ),
        Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.1,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ── Companion Orb with Sprite Sheet Support ─────────────────────────────────

class _CharacterOrb extends StatelessWidget {
  final ColorScheme cs;
  final Animation<double> pulse;
  final String source;
  final String fallbackEmoji;
  final List<String> equippedAccessories;

  const _CharacterOrb({
    super.key,
    required this.cs,
    required this.pulse,
    required this.source,
    this.fallbackEmoji = '🐱',
    this.equippedAccessories = const [],
  });

  @override
  Widget build(BuildContext context) {
    const orbSize = 108.0;
    final isSpriteSheet = source.endsWith('.png');

    final matchingOption = _kCompanions.firstWhere(
      (c) => c.assetPath == source,
      orElse: () => _kCompanions.first,
    );

    return SizedBox(
      width: orbSize + 24,
      height: orbSize + 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: pulse,
              builder: (context, _) {
                final t = pulse.value;
                final scale = 1.0 + (t * 0.05);
                final glowAlpha = 0.12 + (t * 0.16);

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: orbSize,
                    height: orbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(glowAlpha),
                          blurRadius: 26,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            width: orbSize,
            height: orbSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primaryContainer,
              gradient: RadialGradient(
                colors: [
                  cs.primaryContainer,
                  cs.primaryContainer.withOpacity(0.65),
                ],
              ),
              border: Border.all(
                color: cs.primary.withOpacity(0.35),
                width: 2.2,
              ),
            ),
          ),

          ClipOval(
            child: SizedBox(
              width: orbSize - 16,
              height: orbSize - 16,
              child: isSpriteSheet
                  ? Center(
                      child: Transform.scale(
                        scale: matchingOption.frameWidth == 64.0
                            ? 1.2
                            : (matchingOption.frameWidth == 16.0 ? 3.5 : 2.2),
                        child: SpriteAnimator(
                          imagePath: source,
                          totalFrames: matchingOption.totalFrames,
                          displayWidth: matchingOption.frameWidth,
                          displayHeight: matchingOption.frameHeight,
                          duration: const Duration(milliseconds: 800),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        fallbackEmoji,
                        style: const TextStyle(fontSize: 34),
                      ),
                    ),
            ),
          ),
          if (equippedAccessories.contains('cloud_blanket'))
            Positioned(
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text('☁️', style: TextStyle(fontSize: 12)),
              ),
            ),
          if (equippedAccessories.contains('moon_halo'))
            Positioned(
              top: 10,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.4),
                ),
                child: const Text('🌙', style: TextStyle(fontSize: 14)),
              ),
            ),
          if (equippedAccessories.contains('star_collar'))
            const Positioned(
              bottom: 18,
              child: Text('✨', style: TextStyle(fontSize: 13)),
            ),
          if (equippedAccessories.contains('heart_tag'))
            const Positioned(
              bottom: 8,
              child: Text('💗', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

// ── Tip of the Day & Remaining Components ─────────────────────────────────

class _TipLoading extends StatelessWidget {
  final ColorScheme cs;
  const _TipLoading({super.key, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _IconBadge(icon: Icons.auto_awesome_rounded, cs: cs),
            const SizedBox(width: 10),
            Text(
              'Daily inspiration',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.0,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Fetching your tip...',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

class _TipLoaded extends StatelessWidget {
  final ColorScheme cs;
  final String tipText;
  const _TipLoaded({super.key, required this.cs, required this.tipText});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _IconBadge(icon: Icons.auto_awesome_rounded, cs: cs),
            const SizedBox(width: 10),
            Text(
              'Daily inspiration',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.0,
                color: cs.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            _Pill(text: 'Tip', cs: cs),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '\u201C',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                height: 0.8,
                color: cs.primary,
                fontFamily: 'CormorantGaramond',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tipText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  fontFamily: 'CormorantGaramond',
                  fontSize: 18,
                  height: 1.65,
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '\u201D',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              height: 0.8,
              color: cs.primary,
              fontFamily: 'CormorantGaramond',
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentMatchesSection extends StatefulWidget {
  final User? user;
  final ColorScheme cs;

  const _RecentMatchesSection({required this.user, required this.cs});

  @override
  State<_RecentMatchesSection> createState() => _RecentMatchesSectionState();
}

class _RecentMatchesSectionState extends State<_RecentMatchesSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final cs = widget.cs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'Recent matches', cs: cs),
        const SizedBox(height: 10),
        _GlassCard(
          cs: cs,
          gradientColors: [
            cs.primaryContainer.withOpacity(0.85),
            cs.secondaryContainer.withOpacity(0.55),
          ],
          child: StreamBuilder<QuerySnapshot>(
            stream: user == null
                ? null
                : FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('matched_suggestions')
                      .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final visibleDocs = _showAll ? docs : docs.take(2).toList();

              if (docs.isEmpty) {
                return Row(
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      color: cs.primary.withOpacity(0.5),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'No matches found yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant.withOpacity(0.8),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _IconBadge(icon: Icons.favorite_rounded, cs: cs),
                      const SizedBox(width: 10),
                      Text(
                        'Your latest matches',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.0,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visibleDocs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final data =
                            visibleDocs[index].data() as Map<String, dynamic>;

                        return ExpandableMatchTile(
                          title: data['title'] ?? 'No Title',
                          description: data['desc'] ?? '',
                        );
                      },
                    ),
                  ),
                  if (docs.length > 2) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Colors.white24),
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: cs.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 4,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _showAll = !_showAll;
                          });
                        },
                        icon: Icon(
                          _showAll
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _showAll ? 'Show Less' : 'View All Matches',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MatchedDatesCard extends StatelessWidget {
  final ColorScheme cs;
  final Stream<QuerySnapshot>? stream;
  final Animation<double> pulse;

  const _MatchedDatesCard({
    required this.cs,
    required this.stream,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      cs: cs,
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      gradientColors: [
        cs.primaryContainer.withOpacity(0.85),
        cs.secondaryContainer.withOpacity(0.55),
      ],
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'MATCHED DATES',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.1,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: pulse,
                    builder: (context, _) {
                      final t = pulse.value;
                      final floatOffset = -t * 6.0;

                      return Transform.translate(
                        offset: Offset(0, floatOffset),
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: 62,
                              child: Column(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: cs.primary.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Container(
                                    width: 1.5,
                                    height: 24,
                                    color: cs.primary.withOpacity(0.3),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.favorite_rounded,
                              size: 78,
                              color: cs.primary,
                            ),
                            Positioned(
                              top: 14,
                              left: 14,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.45),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: _MirrorCount(
                                count: count,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: cs.onPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22,
                                    ),
                              ),
                            ),
                          ],
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
    );
  }
}

class _MirrorCount extends ImplicitlyAnimatedWidget {
  final int count;
  final TextStyle? style;

  const _MirrorCount({required this.count, this.style})
    : super(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );

  @override
  ImplicitlyAnimatedWidgetState<_MirrorCount> createState() =>
      _MirrorCountState();
}

class _MirrorCountState extends ImplicitlyAnimatedWidgetState<_MirrorCount> {
  IntTween? _tween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _tween =
        visitor(
              _tween,
              widget.count,
              (dynamic value) => IntTween(begin: value as int),
            )
            as IntTween;
  }

  @override
  Widget build(BuildContext context) {
    final value = _tween?.evaluate(animation) ?? widget.count;
    return Text('$value', style: widget.style);
  }
}

class _StreakCard extends StatelessWidget {
  final User? user;
  final ColorScheme cs;
  final Animation<double> pulse;
  final Animation<double> flicker;

  const _StreakCard({
    required this.user,
    required this.cs,
    required this.pulse,
    required this.flicker,
  });

  @override
  Widget build(BuildContext context) {
    if (user == null) return _streakCard(context, 0, 0);

    final docStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .snapshots();

    return StreamBuilder<DocumentSnapshot>(
      stream: docStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final current = data != null
            ? ((data['sharedStreakCurrent'] as int?) ??
                  (data['streakCurrent'] as int?) ??
                  0)
            : 0;
        final best = data != null
            ? ((data['sharedStreakBest'] as int?) ??
                  (data['streakBest'] as int?) ??
                  0)
            : 0;

        return _streakCard(context, current, best);
      },
    );
  }

  Widget _streakCard(BuildContext context, int current, int best) {
    return _GlassCard(
      cs: cs,
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      gradientColors: [
        cs.primaryContainer.withOpacity(0.85),
        cs.secondaryContainer.withOpacity(0.55),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'STREAK',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Center(
              child: _FlameBadge(
                cs: cs,
                count: current,
                pulse: pulse,
                flicker: flicker,
              ),
            ),
          ),
          Text(
            best == 0
                ? 'No streak yet'
                : best == 1
                ? 'Best: 1 day'
                : 'Best: $best days',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _FlameBadge extends StatelessWidget {
  final ColorScheme cs;
  final int count;
  final Animation<double> pulse;
  final Animation<double> flicker;

  const _FlameBadge({
    required this.cs,
    required this.count,
    required this.pulse,
    required this.flicker,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, flicker]),
      builder: (context, _) {
        final t1 = pulse.value;
        final t2 = flicker.value;

        return SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: 2,
                child: Container(
                  width: 52,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8D5B4C).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(6),
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
              Positioned(
                bottom: 6,
                child: Transform.scale(
                  scale: 1.05 + (t1 * 0.06),
                  alignment: Alignment.bottomCenter,
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (rect) {
                      final shift = (t2 - 0.5) * 0.6;
                      return LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment(0, -1 + shift),
                        colors: [cs.primary, const Color(0xFFFFB74D)],
                      ).createShader(rect);
                    },
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      size: 76,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                child: _MirrorCount(
                  count: count,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: cs.shadow.withOpacity(0.45),
                        blurRadius: 6,
                        offset: const Offset(0, 1.5),
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
  }
}
