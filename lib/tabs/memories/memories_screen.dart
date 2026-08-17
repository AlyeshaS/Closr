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
  final String? coupleId;

  const MemoriesScreen({super.key, this.coupleId});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BadgeService _badgeService = BadgeService();
  String? _resolvedCoupleId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _resolvedCoupleId = widget.coupleId;
    if (_resolvedCoupleId == null) {
      _fetchUserCoupleId();
    }
  }

  Future<void> _fetchUserCoupleId() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();

      if (mounted && userDoc.exists) {
        setState(() {
          _resolvedCoupleId =
              userDoc.data()?['couple_id'] as String? ??
              userDoc.data()?['coupleId'] as String?;
        });
      }
    } catch (_) {}
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
    final coupleId = _resolvedCoupleId;

    if (coupleId == null || coupleId.isEmpty) {
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

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('couples')
          .doc(coupleId)
          .snapshots(),
      builder: (context, coupleSnapshot) {
        final coupleData = coupleSnapshot.data?.data() ?? {};
        final stats = Map<String, dynamic>.from(coupleData['stats'] ?? {});
        final sharedCoins = (stats['total_shared_coins'] as num? ?? 0).toInt();
        final nextRewardTarget =
            (coupleData['next_reward_target'] as num? ?? 300).toInt();
        final nextAccessoryName =
            coupleData['next_accessory_name'] as String? ?? 'Party Hat';

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _badgeService.streamCoupleBadges(coupleId),
          builder: (context, badgeSnapshot) {
            final liveBadges =
                badgeSnapshot.data ??
                allBadges.map((badgeDef) {
                  final progress = (stats[badgeDef.statKey] as num? ?? 0)
                      .toInt();
                  return {
                    'id': badgeDef.id,
                    'title': badgeDef.title,
                    'description': badgeDef.description,
                    'progress': progress.clamp(0, badgeDef.target),
                    'target': badgeDef.target,
                    'points': badgeDef.points,
                    'isUnlocked': progress >= badgeDef.target,
                    'icon': badgeDef.icon,
                    'category': badgeDef.category.name,
                  };
                }).toList();

            return MemoriesMilestonesTab(
              userCoins: sharedCoins,
              nextRewardTarget: nextRewardTarget,
              nextAccessoryName: nextAccessoryName,
              achievements: liveBadges,
              onNudgeSent: (title, icon) {
                _badgeService.incrementCoupleStat(
                  coupleId: coupleId,
                  statKey: 'nudges_sent',
                  by: 1,
                );
              },
              onGoalToggled: (goal) {
                if (goal['isCompleted'] == true && goal['isCouple'] == true) {
                  _badgeService.incrementCoupleStat(
                    coupleId: coupleId,
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
  }
}
