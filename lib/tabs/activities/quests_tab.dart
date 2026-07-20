// lib/play/quests_tab.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/streaks_service.dart';
import '../../services/quests_manager.dart';

class QuestsTab extends StatefulWidget {
  const QuestsTab({super.key});

  @override
  State<QuestsTab> createState() => _QuestsTabState();
}

class _QuestsTabState extends State<QuestsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_myUid.isEmpty) {
      return const Center(child: Text("Please log in."));
    }

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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 48,
                    color: cs.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Please pair with a partner in settings first!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('users')
              .where('emailLower', isEqualTo: partnerEmailLower)
              .snapshots(),
          builder: (context, partnerLookup) {
            if (!partnerLookup.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (partnerLookup.data!.docs.isEmpty) {
              return const Center(
                child: Text("Waiting for partner to register..."),
              );
            }

            final partnerUid = partnerLookup.data!.docs.first.id;
            final coupleDocId = _getCoupleDocId(_myUid, partnerUid);

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('couples')
                  .doc(coupleDocId)
                  .snapshots(),
              builder: (context, questSnapshot) {
                List<dynamic> quests = [];
                Timestamp? lastUpdated;

                if (questSnapshot.hasData && questSnapshot.data!.exists) {
                  final data = questSnapshot.data!.data();
                  quests = data?['quests'] as List<dynamic>? ?? [];
                  lastUpdated = data?['week_start_date'] as Timestamp?;
                }

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
                      // REDESIGNED TOP CARD WIDGET
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    cs.surfaceContainerHigh,
                                    cs.surfaceContainerLowest,
                                  ]
                                : [
                                    cs.primaryContainer.withOpacity(0.9),
                                    cs.primaryContainer.withOpacity(0.4),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: cs.primary.withOpacity(0.15),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withOpacity(
                                isDark ? 0.12 : 0.08,
                              ),
                              blurRadius: 24,
                              spreadRadius: -4,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "THIS WEEK'S QUESTS",
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          letterSpacing: 1.3,
                                          fontWeight: FontWeight.bold,
                                          color: cs.primary,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$completedCount of ${quests.length} Completed',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: cs.onPrimaryContainer,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 18),

                                  // Rounded capsule progress bar track
                                  Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: cs.primary.withOpacity(0.15),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: progressValue,
                                        backgroundColor: isDark
                                            ? cs.surfaceContainerHighest
                                            : cs.primary.withOpacity(0.1),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              cs.primary,
                                            ),
                                        minHeight: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 68,
                                  height: 68,
                                  child: CircularProgressIndicator(
                                    value: progressValue,
                                    strokeWidth: 5,
                                    backgroundColor: cs.primary.withOpacity(
                                      0.1,
                                    ),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      cs.primary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(progressValue * 100).round()}%',
                                  style: TextStyle(
                                    fontFamily: 'CormorantGaramond',
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'TODAY\'S QUESTS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Interactive Modern Item List
                      ...List.generate(quests.length, (i) {
                        final quest = quests[i] as Map<String, dynamic>;
                        final done = quest['done'] as bool? ?? false;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              bool nextState = !done;
                              quests[i]['done'] = nextState;

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
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: done
                                    ? (isDark
                                          ? const Color(0xFF1E2B24)
                                          : cs.primaryContainer.withOpacity(
                                              0.35,
                                            ))
                                    : (isDark
                                          ? const Color(0xFF1C1B1F)
                                          : Colors.white),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: done
                                      ? cs.primary.withOpacity(0.4)
                                      : cs.outlineVariant.withOpacity(0.6),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: done
                                        ? Colors.transparent
                                        : (isDark
                                              ? Colors.black.withOpacity(0.3)
                                              : Colors.black.withOpacity(0.04)),
                                    blurRadius: 10,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: done
                                          ? cs.primaryContainer
                                          : cs.surfaceContainerHighest
                                                .withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        quest['emoji'] ?? '✨',
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      quest['title'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: done
                                                ? FontWeight.normal
                                                : FontWeight.w600,
                                            color: done
                                                ? cs.onSurfaceVariant
                                                      .withOpacity(0.7)
                                                : cs.onSurface,
                                            decoration: done
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: done
                                          ? cs.primary
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: done
                                            ? cs.primary
                                            : cs.outline.withOpacity(0.5),
                                        width: 2,
                                      ),
                                    ),
                                    child: done
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 16,
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
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'More challenges coming soon',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: cs.onSurfaceVariant.withOpacity(0.4),
                                fontSize: 12,
                                letterSpacing: 0.5,
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
