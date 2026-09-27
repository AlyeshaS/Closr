import 'package:flutter/material.dart';
import 'tabs/home_page.dart';
import 'tabs/connect/connect_screen.dart';
import 'tabs/activities/activities_screen.dart';
import 'tabs/memories/memories_screen.dart';
import 'tabs/settings_page.dart';
import 'widgets/closr_loading_view.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  bool _homeReady = false;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      HomePage(onReady: _handleHomeReady),
      const ConnectScreen(),
      const ActivitiesScreen(),
      const MemoriesScreen(),
      const SettingsPage(),
    ];
  }

  void _handleHomeReady() {
    if (!mounted || _homeReady) return;
    setState(() => _homeReady = true);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(
              key: ValueKey<int>(_selectedIndex),
              child: _pages[_selectedIndex],
            ),
          ),
          if (!_homeReady && _selectedIndex == 0)
            Positioned.fill(
              child: ColoredBox(
                color: cs.surface,
                child: const SafeArea(child: ClosrLoadingView()),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _homeReady
          ? Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: cs.outline.withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      splashColor: cs.primary.withValues(alpha: 0.16),
                      highlightColor: cs.primary.withValues(alpha: 0.08),
                    ),
                    child: BottomNavigationBar(
                      currentIndex: _selectedIndex,
                      onTap: _onItemTapped,
                      type: BottomNavigationBarType.fixed,
                      backgroundColor: Colors.transparent,
                      selectedItemColor: cs.primary,
                      unselectedItemColor: cs.onSurfaceVariant.withOpacity(0.6),
                      selectedIconTheme: IconThemeData(color: cs.primary),
                      unselectedIconTheme: IconThemeData(
                        color: cs.onSurfaceVariant.withOpacity(0.6),
                      ),
                      selectedLabelStyle: TextStyle(
                        color: cs.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      unselectedLabelStyle: TextStyle(
                        color: cs.onSurfaceVariant.withOpacity(0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                      elevation: 0,
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.home_outlined),
                          activeIcon: Icon(Icons.home_rounded),
                          label: 'Home',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.favorite_outline_rounded),
                          activeIcon: Icon(Icons.favorite_rounded),
                          label: 'Connect',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.local_activity_outlined),
                          activeIcon: Icon(Icons.local_activity_rounded),
                          label: 'Activities',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.auto_stories_outlined),
                          activeIcon: Icon(Icons.auto_stories_rounded),
                          label: 'Memories',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.person_outline_rounded),
                          activeIcon: Icon(Icons.person_rounded),
                          label: 'You',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
