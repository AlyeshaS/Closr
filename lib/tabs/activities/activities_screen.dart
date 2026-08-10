import 'package:flutter/material.dart';
import '../suggestions/suggestions_screen.dart';
import 'games_dashboard_tab.dart' hide QuestsTab;
import 'quests_tab.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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
                  tabs: const [
                    Tab(text: 'Quests'),
                    Tab(text: 'Games'),
                    Tab(text: 'Date Generator'),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                QuestsTab(),
                GamesDashboardTab(),
                SuggestionsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
