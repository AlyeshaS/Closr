// lib/memories/memories_screen.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/scrapbook_entry.dart';
import '../../models/achievement_badge_reward.dart';
import '../../models/timeline_event.dart';
import '../../models/badge_model.dart';
import '../../services/badge_service.dart';
import '../../services/companion_rewards_service.dart';
import '../../services/scrapbook_service.dart';
import '../../services/timeline_service.dart';
import './watch_tab.dart';

part 'memories_milestones_tab.dart';
part 'memories_scrapbook_tab.dart';
part 'memories_timeline_tab.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BadgeService _badgeService = BadgeService();
  String? _partnerUid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchPartnerUid();
  }

  Future<void> _fetchPartnerUid() async {
    final user = FirebaseAuth.instance.currentUser;
    final currentUid = user?.uid;
    if (currentUid == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();

      if (mounted && userDoc.exists) {
        final data = userDoc.data() ?? {};
        final partnerEmail =
            (data['partnerEmailLower'] ?? data['partnerEmail'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (partnerEmail.isNotEmpty) {
          final partnerQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('emailLower', isEqualTo: partnerEmail)
              .get();

          if (partnerQuery.docs.isNotEmpty) {
            setState(() {
              _partnerUid = partnerQuery.docs.first.id;
            });
            return;
          }

          final fallbackQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: partnerEmail)
              .get();

          if (fallbackQuery.docs.isNotEmpty) {
            setState(() {
              _partnerUid = fallbackQuery.docs.first.id;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching partner UID: $e');
    }
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
                    Tab(text: 'Timeline'),
                    Tab(text: 'Achievements'),
                    Tab(text: 'Watch'),
                    Tab(text: 'Scrapbook'),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const MemoriesTimelineTab(),
                _buildMilestonesTab(),
                const WatchTab(),
                const MemoriesScrapbookTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonesTab() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      final defaultBadges = allBadges
          .map(
            (badgeDef) => {
              'id': badgeDef.id,
              'title': badgeDef.title,
              'description': badgeDef.description,
              'progress': 0,
              'target': badgeDef.target,
              'points': badgeDef.points,
              'isUnlocked': false,
              'icon': badgeDef.icon,
              'category': badgeDef.category.name,
            },
          )
          .toList();

      return MemoriesMilestonesTab(achievements: defaultBadges);
    }

    final achievementsDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .collection('achievements')
        .doc('data');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: achievementsDocRef.snapshots(),
      builder: (context, achSnapshot) {
        final achData = achSnapshot.data?.data() ?? {};
        final totalPoints = (achData['totalPoints'] as num? ?? 0).toInt();
        final nextRewardTarget =
            (achData['nextRewardTarget'] as num? ?? 300).toInt();
        final nextAccessoryName =
            achData['nextAccessoryName'] as String? ?? 'Party Hat';

        final rawNudges = (achData['customNudges'] as List?) ?? [];
        final customNudges = rawNudges.map((n) {
          final map = Map<String, dynamic>.from(n as Map);
          return {
            'label': map['label'] ?? 'Nudge',
            'iconCodePoint': map['iconCodePoint'] ?? Icons.favorite_rounded.codePoint,
          };
        }).toList();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: achievementsDocRef.collection('goals').snapshots(),
          builder: (context, goalsSnapshot) {
            final goalDocs = goalsSnapshot.data?.docs ?? [];
            final coupleGoals = <Map<String, dynamic>>[];
            final personalGoals = <Map<String, dynamic>>[];

            for (final doc in goalDocs) {
              final data = doc.data();
              final goalMap = {
                'id': doc.id,
                'title': data['title'] ?? '',
                'category': data['category'] ?? 'General',
                'points': (data['points'] as num? ?? 0).toInt(),
                'isCompleted': data['isCompleted'] == true,
                'isCouple': data['isCouple'] == true,
                'iconCodePoint': data['iconCodePoint'] ?? Icons.star_rounded.codePoint,
              };

              if (goalMap['isCouple'] == true) {
                coupleGoals.add(goalMap);
              } else {
                personalGoals.add(goalMap);
              }
            }

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _badgeService.streamBadges(currentUid),
              builder: (context, badgeSnapshot) {
                final liveBadges =
                    badgeSnapshot.data ??
                    allBadges
                        .map(
                          (b) => {
                            'id': b.id,
                            'title': b.title,
                            'description': b.description,
                            'progress': 0,
                            'target': b.target * 2,
                            'points': b.points,
                            'isUnlocked': false,
                            'icon': b.icon,
                            'category': b.category.name,
                          },
                        )
                        .toList();

                return MemoriesMilestonesTab(
                  userCoins: totalPoints,
                  nextRewardTarget: nextRewardTarget,
                  nextAccessoryName: nextAccessoryName,
                  customNudges: customNudges.isNotEmpty ? customNudges : null,
                  coupleGoals: coupleGoals,
                  personalGoals: personalGoals,
                  achievements: liveBadges,
                  onNudgeSent: (title, icon) {
                    _badgeService.incrementStat(
                      statKey: 'nudges_sent',
                      by: 1,
                    );
                  },
                  onNudgeAdded: (nudge) async {
                    await achievementsDocRef.set({
                      'customNudges': FieldValue.arrayUnion([
                        {
                          'label': nudge['label'],
                          'iconCodePoint': nudge['iconCodePoint'] ??
                              (nudge['icon'] as IconData?)?.codePoint ??
                              Icons.favorite_rounded.codePoint,
                        }
                      ]),
                    }, SetOptions(merge: true));
                  },
                  onNudgeRemoved: (nudge) async {
                    await achievementsDocRef.set({
                      'customNudges': FieldValue.arrayRemove([
                        {
                          'label': nudge['label'],
                          'iconCodePoint': nudge['iconCodePoint'] ??
                              (nudge['icon'] as IconData?)?.codePoint ??
                              Icons.favorite_rounded.codePoint,
                        }
                      ]),
                    }, SetOptions(merge: true));
                  },
                  onGoalAdded: (goal) async {
                    final goalId = goal['id'] as String;
                    final isCouple = goal['isCouple'] == true;
                    final iconCodePoint = goal['iconCodePoint'] ??
                        (goal['icon'] as IconData?)?.codePoint ??
                        Icons.star_rounded.codePoint;

                    final goalData = {
                      'title': goal['title'],
                      'category': goal['category'],
                      'points': goal['points'],
                      'isCouple': isCouple,
                      'isCompleted': false,
                      'iconCodePoint': iconCodePoint,
                      'createdAt': FieldValue.serverTimestamp(),
                    };

                    final batch = FirebaseFirestore.instance.batch();
                    batch.set(
                      achievementsDocRef.collection('goals').doc(goalId),
                      goalData,
                    );

                    if (isCouple && _partnerUid != null && _partnerUid!.isNotEmpty) {
                      final partnerGoalDoc = FirebaseFirestore.instance
                          .collection('users')
                          .doc(_partnerUid)
                          .collection('achievements')
                          .doc('data')
                          .collection('goals')
                          .doc(goalId);
                      batch.set(partnerGoalDoc, goalData);
                    }

                    await batch.commit();
                  },
                  onGoalToggled: (goal) async {
                    final goalId = goal['id'] as String;
                    final points = (goal['points'] as num?)?.toInt() ?? 0;
                    final isCompleted = goal['isCompleted'] == true;
                    final isCouple = goal['isCouple'] == true;

                    final batch = FirebaseFirestore.instance.batch();

                    // Update current user's goal and totalPoints
                    batch.update(
                      achievementsDocRef.collection('goals').doc(goalId),
                      {'isCompleted': isCompleted},
                    );
                    batch.set(
                      achievementsDocRef,
                      {
                        'totalPoints': FieldValue.increment(
                          isCompleted ? points : -points,
                        ),
                      },
                      SetOptions(merge: true),
                    );

                    // Dual write couple goal status to partner
                    if (isCouple && _partnerUid != null && _partnerUid!.isNotEmpty) {
                      final partnerDocRef = FirebaseFirestore.instance
                          .collection('users')
                          .doc(_partnerUid)
                          .collection('achievements')
                          .doc('data');

                      batch.update(
                        partnerDocRef.collection('goals').doc(goalId),
                        {'isCompleted': isCompleted},
                      );
                      batch.set(
                        partnerDocRef,
                        {
                          'totalPoints': FieldValue.increment(
                            isCompleted ? points : -points,
                          ),
                        },
                        SetOptions(merge: true),
                      );
                    }

                    await batch.commit();

                    if (isCompleted && isCouple) {
                      await _badgeService.incrementStat(
                        statKey: 'couple_goals_completed',
                        by: 1,
                      );
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}