// lib/play/quests_tab.dart
import 'dart:ui';
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

class _QuestsTabState extends State<QuestsTab>
    with AutomaticKeepAliveClientMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  double _animatedProgressStart = 0.0;
  double _currentProgressValue = 0.0;

  bool _questsVerifiedThisSession = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _verifyWeeklyQuestsOnce({
    required String myUid,
    required String partnerUid,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> currentQuestDocs,
    required Timestamp? lastUpdated,
  }) async {
    if (_questsVerifiedThisSession || myUid.isEmpty || partnerUid.isEmpty)
      return;
    _questsVerifiedThisSession = true;

    final targetSunday = QuestsManager.getMostRecentSundayMidnight();

    bool needsNewQuests =
        currentQuestDocs.isEmpty ||
        lastUpdated == null ||
        lastUpdated.toDate().isBefore(targetSunday);

    if (needsNewQuests) {
      List<String> oldIds = currentQuestDocs
          .map((doc) => (doc.data()['id'] ?? '').toString())
          .toList();
      final freshQuests = QuestsManager.generateWeeklyQuests(
        lastWeekIds: oldIds,
      );

      WriteBatch batch = _firestore.batch();

      // 1. Update the tracking timestamp on the root user profiles
      final timestampData = {
        'quests_last_updated': Timestamp.fromDate(targetSunday),
      };
      batch.set(
        _firestore.collection('users').doc(myUid),
        timestampData,
        SetOptions(merge: true),
      );
      batch.set(
        _firestore.collection('users').doc(partnerUid),
        timestampData,
        SetOptions(merge: true),
      );

      // 2. Clear out the expired documents from previous weeks from the subcollections
      for (var doc in currentQuestDocs) {
        batch.delete(
          _firestore
              .collection('users')
              .doc(myUid)
              .collection('quests')
              .doc(doc.id),
        );
        batch.delete(
          _firestore
              .collection('users')
              .doc(partnerUid)
              .collection('quests')
              .doc(doc.id),
        );
      }

      // 3. Write each new quest as a separate document inside the subcollection for both users
      for (var quest in freshQuests) {
        final questId =
            quest['id']?.toString() ?? _firestore.collection('users').doc().id;

        final myQuestRef = _firestore
            .collection('users')
            .doc(myUid)
            .collection('quests')
            .doc(questId);
        final partnerQuestRef = _firestore
            .collection('users')
            .doc(partnerUid)
            .collection('quests')
            .doc(questId);

        batch.set(myQuestRef, quest);
        batch.set(partnerQuestRef, quest);
      }

      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_myUid.isEmpty) {
      return const Center(child: Text("Please log in."));
    }

    // Stream 1: Listens to the core user profile document for partner pairing emails
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(_myUid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text("No profile data found."));
        }

        final myData = snapshot.data!.data();
        final String partnerEmailLower =
            ((myData?['partnerEmailLower'] ?? myData?['partnerEmail'] ?? ''))
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

        // Stream 2: Resolves the partner email into their unique user ID
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
            Timestamp? lastUpdated =
                myData?['quests_last_updated'] as Timestamp?;

            // Stream 3: Real-time listener for separate documents within the subcollection folder structure
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('users')
                  .doc(_myUid)
                  .collection('quests')
                  .snapshots(),
              builder: (context, subcollectionSnapshot) {
                if (subcollectionSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final questDocs = subcollectionSnapshot.data?.docs ?? [];

                // Safe handoff for background verification check frames
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _verifyWeeklyQuestsOnce(
                    myUid: _myUid,
                    partnerUid: partnerUid,
                    currentQuestDocs: questDocs,
                    lastUpdated: lastUpdated,
                  );
                });

                if (questDocs.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                int completedCount = questDocs
                    .where((doc) => doc.data()['done'] == true)
                    .length;
                double targetProgress = (completedCount / questDocs.length);

                if (targetProgress != _currentProgressValue) {
                  _animatedProgressStart = _currentProgressValue;
                  _currentProgressValue = targetProgress;
                }

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Frosted Glass Top Progress Summary Card
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: cs.shadow.withOpacity(0.07),
                              blurRadius: 26,
                              offset: const Offset(0, 14),
                            ),
                            BoxShadow(
                              color: cs.primary.withOpacity(0.12),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    cs.primaryContainer.withOpacity(0.85),
                                    cs.secondaryContainer.withOpacity(0.55),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: cs.primary.withOpacity(0.35),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          '$completedCount of ${questDocs.length} Completed',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                color: cs.onSurface,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 18),

                                        TweenAnimationBuilder<double>(
                                          tween: Tween<double>(
                                            begin: _animatedProgressStart,
                                            end: _currentProgressValue,
                                          ),
                                          duration: const Duration(
                                            milliseconds: 350,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          builder: (context, animatedValue, child) {
                                            return Container(
                                              height: 10,
                                              decoration: BoxDecoration(
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: cs.primary
                                                        .withOpacity(0.05),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: LinearProgressIndicator(
                                                  value: animatedValue,
                                                  backgroundColor: isDark
                                                      ? cs.surfaceContainerHighest
                                                      : cs.primary.withOpacity(
                                                          0.1,
                                                        ),
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(cs.primary),
                                                  minHeight: 10,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: _animatedProgressStart,
                                      end: _currentProgressValue,
                                    ),
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, animatedValue, child) {
                                      return Text(
                                        '${(animatedValue * 100).round()}%',
                                        style: TextStyle(
                                          fontFamily: 'CormorantGaramond',
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: cs.primary,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
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

                      // Interactive list built dynamically from separate collection records
                      ...List.generate(questDocs.length, (i) {
                        final doc = questDocs[i];
                        final quest = doc.data();
                        final done = quest['done'] as bool? ?? false;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              bool nextState = !done;

                              // 🌟 Updates the matching individual document ID in both subcollections simultaneously
                              WriteBatch updateBatch = _firestore.batch();

                              final myDocRef = _firestore
                                  .collection('users')
                                  .doc(_myUid)
                                  .collection('quests')
                                  .doc(doc.id);
                              final partnerDocRef = _firestore
                                  .collection('users')
                                  .doc(partnerUid)
                                  .collection('quests')
                                  .doc(doc.id);

                              updateBatch.update(myDocRef, {'done': nextState});
                              updateBatch.update(partnerDocRef, {
                                'done': nextState,
                              });

                              await updateBatch.commit();

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
                                      ? cs.primary.withOpacity(0.6)
                                      : cs.outlineVariant.withOpacity(0.9),
                                  width: 2.0,
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

                                  // Square Custom Checkbox Container
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: done
                                          ? cs.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: done
                                            ? cs.primary
                                            : cs.outline.withOpacity(0.6),
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
