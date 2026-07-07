// lib/play/activities_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../suggestions/suggestions_screen.dart';
import '../../services/streaks_service.dart';
import '../../services/quests_manager.dart'; // Import the manager
import 'games_dashboard_tab.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                color: Colors.transparent,
                child: TabBar(
                  controller: _tabController,
                  dividerColor: cs.outlineVariant,
                  indicatorColor: cs.primary,
                  indicatorWeight: 2,
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  tabs: const [
                    Tab(text: 'Quests'),
                    Tab(text: 'Games'),
                    Tab(text: 'Date Generator'),
                    Tab(text: 'Date Ideas'),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const _QuestsTab(),
                const GamesDashboardTab(),
                _ComingSoonTab(
                  icon: Icons.explore_outlined,
                  title: 'Date Generator',
                  subtitle:
                      'Tell us your mood, time, and budget — we\'ll plan the perfect date.',
                  cs: cs,
                ),
                const SuggestionsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quests Tab (Connected to Firestore using Email Matching) ─────────────────
class _QuestsTab extends StatefulWidget {
  const _QuestsTab();

  @override
  State<_QuestsTab> createState() => _QuestsTabState();
}

class _QuestsTabState extends State<_QuestsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Generates a shared predictable ID string unique to this couple match
  String _getCoupleDocId(String uidA, String uidB) {
    List<String> ids = [uidA, uidB];
    ids.sort();
    return ids.join('_');
  }

  /// Verifies and rotates quests precisely at Sunday 12:00 AM
  Future<void> _verifyWeeklyQuests(
    String coupleDocId,
    List<dynamic> currentQuests,
    Timestamp? lastUpdated,
  ) async {
    final targetSunday = QuestsManager.getMostRecentSundayMidnight();

    bool needsNewQuests =
        currentQuests.isEmpty ||
        lastUpdated == null ||
        lastUpdated.toDate().isBefore(targetSunday);

    if (needsNewQuests) {
      List<String> oldIds = currentQuests
          .map((q) => (q['id'] ?? '').toString())
          .toList();
      final freshQuests = QuestsManager.generateWeeklyQuests(
        lastWeekIds: oldIds,
      );

      // Using a standard update or set structure without loop triggers
      await _firestore.collection('couples').doc(coupleDocId).set({
        'week_start_date': Timestamp.fromDate(
          targetSunday,
        ), // Lock it exactly to Sunday 12am
        'quests': freshQuests,
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_myUid.isEmpty) {
      return const Center(child: Text("Please log in."));
    }

    // 1. Fetch current user context to retrieve partner's lookup details
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(_myUid).snapshots(),
      builder: (context, mySnapshot) {
        if (!mySnapshot.hasData || !mySnapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        final myData = mySnapshot.data!.data();
        final String partnerEmailLower =
            (myData?['partnerEmailLower'] ?? myData?['partnerEmail'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (partnerEmailLower.isEmpty) {
          return const Center(
            child: Text("Please pair with a partner in settings first!"),
          );
        }

        // 2. Fetch Partner's Document to extract their UID
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('users')
              .where('emailLower', isEqualTo: partnerEmailLower)
              .snapshots(),
          builder: (context, partnerLookup) {
            if (!partnerLookup.hasData)
              return const Center(child: CircularProgressIndicator());
            if (partnerLookup.data!.docs.isEmpty) {
              return const Center(
                child: Text("Waiting for partner to register..."),
              );
            }

            final partnerUid = partnerLookup.data!.docs.first.id;
            final coupleDocId = _getCoupleDocId(_myUid, partnerUid);

            // 3. Listen to the shared dynamic couple collection
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('couples')
                  .doc(coupleDocId)
                  .snapshots(),
              builder: (context, questSnapshot) {
                // If it doesn't exist yet, run checking configuration
                List<dynamic> quests = [];
                Timestamp? lastUpdated;

                if (questSnapshot.hasData && questSnapshot.data!.exists) {
                  final data = questSnapshot.data!.data();
                  quests = data?['quests'] as List<dynamic>? ?? [];
                  lastUpdated = data?['week_start_date'] as Timestamp?;
                }

                // Fire off asynchronous generation if required
                _verifyWeeklyQuests(coupleDocId, quests, lastUpdated);

                if (quests.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                int completedCount = quests
                    .where((q) => q['done'] == true)
                    .length;
                double progressValue = quests.isEmpty
                    ? 0
                    : (completedCount / quests.length);

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Weekly Summary Progress Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'This week\'s quest',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$completedCount / ${quests.length} completed',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: cs.onPrimaryContainer,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progressValue,
                                      backgroundColor: cs.primary.withOpacity(
                                        0.15,
                                      ),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        cs.primary,
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '${(progressValue * 100).round()}%',
                              style: TextStyle(
                                fontFamily: 'CormorantGaramond',
                                fontSize: 36,
                                fontWeight: FontWeight.w500,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'ACTIVITIES',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 12),

                      // Interactive List
                      ...List.generate(quests.length, (i) {
                        final quest = quests[i] as Map<String, dynamic>;
                        final done = quest['done'] as bool? ?? false;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: () async {
                              bool nextState = !done;
                              quests[i]['done'] = nextState;

                              // Optimistically update cloud record
                              await _firestore
                                  .collection('couples')
                                  .doc(coupleDocId)
                                  .update({'quests': quests});

                              try {
                                if (nextState) {
                                  await StreaksService().recordActivity(
                                    'quest_completed',
                                  );
                                }
                              } catch (_) {}
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: done
                                    ? cs.primaryContainer.withOpacity(0.5)
                                    : (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFF231519)
                                          : Colors.white),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: done
                                      ? cs.primary.withOpacity(0.3)
                                      : cs.outlineVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: done
                                          ? cs.primaryContainer
                                          : cs.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        quest['emoji'] ?? '✨',
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      quest['title'] ?? '',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: done
                                                ? cs.onSurfaceVariant
                                                : cs.onSurface,
                                            decoration: done
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                          ),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: done
                                          ? cs.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                        color: done ? cs.primary : cs.outline,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: done
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 14,
                                            color: cs.onPrimary,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'More quests & bingo challenges coming soon',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: cs.onSurfaceVariant.withOpacity(0.6),
                                fontSize: 12,
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
      },
    );
  }
}

// ── Shared Coming Soon widget ─────────────────────────────────────────────────
class _ComingSoonTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme cs;
  const _ComingSoonTab({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primaryContainer,
              ),
              child: Icon(icon, size: 32, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Coming soon',
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
