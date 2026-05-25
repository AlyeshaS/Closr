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
                const SizedBox(width: 12),
                Expanded(
                  child: _StreakCard(user: user, cs: cs),
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
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border(left: BorderSide(color: cs.primary, width: 3)),
              ),
              child: FutureBuilder<String>(
                future: GeminiService().fetchQuoteOfTheDay(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Row(
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
                    );
                  }
                  return Text(
                    snapshot.hasError
                        ? 'Could not load tip.'
                        : (snapshot.data ?? ''),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontFamily: 'CormorantGaramond',
                      fontSize: 17,
                      height: 1.6,
                      color: cs.onSurface,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            // ── Recent Matches ────────────────────────────────────────
            _SectionLabel(text: 'Recent matches', cs: cs),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF231519)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: user == null
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Sign in to see your matches.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('matched_suggestions')
                          .limit(5)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.primary,
                              ),
                            ),
                          );
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.favorite_border_rounded,
                                  size: 36,
                                  color: cs.outline,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No matches yet — try the Connect tab!',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: cs.outlineVariant,
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) {
                            final data =
                                docs[index].data() as Map<String, dynamic>;
                            return ExpandableMatchTile(
                              title: data['title'] ?? 'No Title',
                              description: data['desc'] ?? '',
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
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
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          if (stream != null)
            StreamBuilder<dynamic>(
              stream: stream,
              builder: (context, snapshot) {
                // If this is a QuerySnapshot (collection), show docs length
                if (snapshot.data is QuerySnapshot) {
                  final count = (snapshot.data as QuerySnapshot).docs.length;
                  return Text(
                    '$count',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontSize: 28,
                    ),
                  );
                }
                // If this is a DocumentSnapshot (single user doc), show a numeric field
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontSize: 28,
                    ),
                  );
                }
                // Fallback
                return Text(
                  staticValue ?? '—',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontSize: 28,
                  ),
                );
              },
            )
          else
            Text(
              staticValue ?? '—',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: cs.onPrimaryContainer,
                fontSize: 28,
              ),
            ),
          if (staticSub != null) ...[
            const SizedBox(height: 2),
            Text(
              staticSub!,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
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
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('STREAK', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            Text(
              '—',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: cs.onPrimaryContainer,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'days in a row',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
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

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('STREAK', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              Text(
                '$current',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'days in a row',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Text(
                      'Best: $best',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
