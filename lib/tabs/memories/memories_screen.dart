// lib/memories/memories_screen.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/scrapbook_entry.dart';
import '../../models/achievement_badge_reward.dart';
import '../../models/timeline_event.dart';
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
              children: const [
                MemoriesTimelineTab(),
                MemoriesMilestonesTab(),
                WatchTab(),
                MemoriesScrapbookTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
