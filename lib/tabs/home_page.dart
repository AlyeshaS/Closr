import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../gemini_service.dart';
import '../_expandable_match_tile.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final cs = Theme.of(context).colorScheme;
    final firstName = user?.displayName?.split(' ').first ?? 'there';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Greeting ──────────────────────────────────────────────
            RichText(
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
            const SizedBox(height: 6),
            Text(
              'Here\'s your day at a glance',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 28),

            // ── Character orb ─────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  _CharacterOrb(cs: cs),
                  const SizedBox(height: 10),
                  Text(
                    'YOUR COMPANION',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Stat row ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 176,
                    child: _StatCard(
                      label: 'MATCHED DATES',
                      cs: cs,
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
                    child: _StreakCard(user: user, cs: cs),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Tip of the day ────────────────────────────────────────
            _SectionLabel(text: 'Tip of the day', cs: cs),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.surfaceContainerHighest,
                    cs.primaryContainer.withValues(alpha: 0.45),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.7),
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FutureBuilder<String>(
                future: GeminiService().fetchQuoteOfTheDay(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cs.surface.withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Daily inspiration',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
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
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                  final tipText = snapshot.hasError
                      ? 'Could not load tip.'
                      : (snapshot.data ?? '');

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Daily inspiration',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  letterSpacing: 1.0,
                                  color: cs.onSurfaceVariant,
                                ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: cs.outlineVariant.withValues(alpha: 0.7),
                              ),
                            ),
                            child: Text(
                              'Tip',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '“',
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(
                                  height: 0.8,
                                  color: cs.primary,
                                  fontFamily: 'CormorantGaramond',
                                ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              tipText,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
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
                          '”',
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(
                                height: 0.8,
                                color: cs.primary,
                                fontFamily: 'CormorantGaramond',
                              ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            // ── Recent Matches ────────────────────────────────────────
            _RecentMatchesSection(user: user, cs: cs),
          ],
        ),
      ),
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
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final cs = widget.cs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'Recent matches', cs: cs),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.surfaceContainerHighest,
                cs.primaryContainer.withValues(alpha: 0.35),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
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
                final visibleDocs = _expanded ? docs : docs.take(2).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Row(
                        children: [
                          Icon(Icons.favorite_rounded, color: cs.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your latest matches',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (docs.length > 2)
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _expanded = !_expanded;
                                });
                              },
                              icon: AnimatedRotation(
                                turns: _expanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: cs.outlineVariant.withValues(alpha: 0.7),
                              ),
                            ),
                            child: Text(
                              '${docs.length}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visibleDocs.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: cs.outlineVariant.withValues(alpha: 0.55),
                          indent: 16,
                          endIndent: 16,
                        ),
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
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
// ── Private widgets ─────────────────────────────────────────────────────────

class _CharacterOrb extends StatelessWidget {
  final ColorScheme cs;
  const _CharacterOrb({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.primaryContainer,
        border: Border.all(color: cs.primary.withOpacity(0.25), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Icon(Icons.pets_rounded, size: 46, color: cs.primary),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  final Stream<dynamic>? stream;
  final String? staticValue;
  final String? staticSub;

  const _StatCard({
    required this.label,
    required this.cs,
    this.stream,
    this.staticValue,
    this.staticSub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withValues(alpha: 0.95),
            cs.secondaryContainer.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.1,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 16,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stream != null)
            StreamBuilder<dynamic>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.data is QuerySnapshot) {
                  final count = (snapshot.data as QuerySnapshot).docs.length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        count == 1
                            ? 'match waiting to be opened'
                            : 'matches waiting to be opened',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                }
                if (snapshot.data is DocumentSnapshot) {
                  final doc = snapshot.data as DocumentSnapshot;
                  final val = doc.data() is Map<String, dynamic>
                      ? ((doc.data()
                                as Map<
                                  String,
                                  dynamic
                                >)['sharedStreakCurrent'] ??
                            (doc.data()
                                as Map<String, dynamic>)['streakCurrent'])
                      : null;
                  final textVal = val != null ? '$val' : '—';
                  return Text(
                    textVal,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }
                return Text(
                  staticValue ?? '—',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            )
          else
            Text(
              staticValue ?? '—',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (staticSub != null) ...[
            const SizedBox(height: 4),
            Text(
              staticSub!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _SectionLabel({required this.text, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 0.1,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final User? user;
  final ColorScheme cs;
  const _StreakCard({required this.user, required this.cs});

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return _streakContainer(context, '—', 'days in a row', 'Best: —');
    }

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

        return _streakContainer(
          context,
          '$current',
          'days in a row',
          'Best: $best days',
        );
      },
    );
  }

  Widget _streakContainer(
    BuildContext context,
    String value,
    String subtitle,
    String bestLabel,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withValues(alpha: 0.95),
            cs.tertiaryContainer.withValues(alpha: 0.62),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'STREAK',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.1,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 16,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.85),
                ),
              ),
              child: Text(
                bestLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
