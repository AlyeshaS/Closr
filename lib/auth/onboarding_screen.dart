import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../tabs/preferences/preferences_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _prefsService = PreferencesService();

  final Set<String> _selectedFood = {};
  final Set<String> _selectedOuting = {};
  final Set<String> _selectedInterests = {};

  int _step = 0;

  static const _foodOptions = [
    'Coffee',
    'Sushi',
    'Pizza',
    'Brunch',
    'Wine',
    'Ramen',
    'Tacos',
    'Desserts',
  ];
  static const _outingOptions = [
    'Hiking',
    'Concerts',
    'Museums',
    'Beach',
    'Camping',
    'Parks',
    'Drives',
  ];
  static const _interestOptions = [
    'Movies',
    'Gaming',
    'Books',
    'Fitness',
    'Cooking',
    'Travel',
    'Music',
  ];

  Future<void> _completeOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _prefsService.updatePreference('food', _selectedFood.toList());
      await _prefsService.updatePreference('outing', _selectedOuting.toList());
      await _prefsService.updatePreference(
        'interests',
        _selectedInterests.toList(),
      );

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'onboarded': true,
        'email': user.email,
        'displayName': user.displayName,
      }, SetOptions(merge: true));
    }

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    List<String> currentOptions;
    Set<String> currentSelected;
    String title;
    String subtitle;

    if (_step == 0) {
      title = 'What are your favorite foods?';
      subtitle = 'Help us curate better date and meal ideas for you.';
      currentOptions = _foodOptions;
      currentSelected = _selectedFood;
    } else if (_step == 1) {
      title = 'What kind of outings do you love?';
      subtitle = 'Select activities you and your partner enjoy doing together.';
      currentOptions = _outingOptions;
      currentSelected = _selectedOuting;
    } else {
      title = 'What are your core interests?';
      subtitle = 'Almost done! Tell us what keeps you busy.';
      currentOptions = _interestOptions;
      currentSelected = _selectedInterests;
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                      decoration: BoxDecoration(
                        color: index <= _step ? cs.primary : cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 36),
              Text(
                title,
                style: textTheme.displayMedium?.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: currentOptions.map((opt) {
                        final isSelected = currentSelected.contains(opt);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                currentSelected.remove(opt);
                              } else {
                                currentSelected.add(opt);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? cs.primary
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: isSelected
                                    ? cs.primary
                                    : cs.outlineVariant,
                              ),
                            ),
                            child: Text(
                              opt,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isSelected ? cs.onPrimary : cs.onSurface,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_step < 2) {
                    setState(() => _step++);
                  } else {
                    _completeOnboarding();
                  }
                },
                child: Text(_step < 2 ? 'Continue' : 'Get Started'),
              ),
              if (_step > 0) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _step--),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Back'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
