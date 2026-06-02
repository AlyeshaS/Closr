import 'package:flutter/material.dart';
import 'tabs/home_page.dart';
import 'tabs/connect/connect_screen.dart';
import 'tabs/play/activities_screen.dart';
import 'tabs/memories/memories_screen.dart';
import 'tabs/settings_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const HomePage(),
    const ConnectScreen(),
    const ActivitiesScreen(),
    const MemoriesScreen(),
    const SettingsPage(),
  ];

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
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: KeyedSubtree(
            key: ValueKey<int>(_selectedIndex),
            child: _pages[_selectedIndex],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: cs.outline.withOpacity(0.3), width: 0.5),
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
      ),
    );
  }
}
