// preferences_screen.dart
import 'package:flutter/material.dart';
import 'preferences_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../welcome_transition_screen.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final PreferencesService _preferencesService = PreferencesService();
  final Map<String, List<String>> _selected = {
    'food': [],
    'outing': [],
    'interests': [],
    'location': [],
  };
  final Map<String, TextEditingController> _customControllers = {
    'food': TextEditingController(),
    'outing': TextEditingController(),
    'interests': TextEditingController(),
    'location': TextEditingController(),
  };

  final Map<String, List<String>> _options = {
    'food': [
      'Sushi',
      'Pizza',
      'Brunch',
      'BBQ',
      'Vegan',
      'Desserts',
      'Seafood',
      'Tapas',
      'Steakhouse',
      'Street Food',
    ],
    'outing': [
      'Hiking',
      'Board Games',
      'Art Gallery',
      'Live Music',
      'Escape Room',
      'Picnic',
      'Movie Night',
      'Cooking Class',
      'Bowling',
      'Mini Golf',
    ],
    'interests': [
      'Travel',
      'Photography',
      'Dancing',
      'Reading',
      'Sports',
      'Crafting',
      'Tech',
      'Gardening',
      'Yoga',
      'Comedy',
    ],
    'location': [
      'Downtown',
      'Nature',
      'Beach',
      'Mountains',
      'Suburbs',
      'Historic Sites',
      'Theme Park',
      'Local Cafe',
      'Rooftop',
      'Park',
    ],
  };

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'outing':
        return Icons.explore_rounded;
      case 'interests':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  String _categoryTitle(String category) {
    switch (category) {
      case 'food':
        return 'Favorite foods';
      case 'outing':
        return 'Perfect outings';
      case 'interests':
        return 'Things you love';
      default:
        return 'Favorite places';
    }
  }

  String _categorySubtitle(String category) {
    switch (category) {
      case 'food':
        return 'For date ideas and little treats';
      case 'outing':
        return 'How you like to spend time together';
      case 'interests':
        return 'The things that spark your curiosity';
      default:
        return 'The places that feel like you';
    }
  }

  Widget _buildChips(String category) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 4,
      runSpacing: 5,
      children: [
        ..._options[category]!.map(
          (option) => FilterChip(
            label: Text(option),
            selected: _selected[category]!.contains(option),
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selected[category]!.add(option);
                } else {
                  _selected[category]!.remove(option);
                }
              });
            },
            selectedColor: cs.primary,
            showCheckmark: false, // Removed checkmark when selected
            labelStyle: TextStyle(
              color: _selected[category]!.contains(option)
                  ? cs.onPrimary
                  : cs.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            side: BorderSide(
              color: _selected[category]!.contains(option)
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            selectedShadowColor: Colors.transparent,
            shadowColor: Colors.transparent,
          ),
        ),
        ActionChip(
          label: const Text('Add custom'),
          avatar: Icon(Icons.add_rounded, color: cs.primary, size: 15),
          labelStyle: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          backgroundColor: cs.primaryContainer.withValues(alpha: 0.4),
          side: BorderSide(color: cs.primary.withValues(alpha: 0.25)),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                  ), // Made wider/bigger
                  child: AlertDialog(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF231519)
                        : Colors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 16,
                    shadowColor: cs.scrim.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        16,
                      ), // Less rounded popup
                      side: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.8),
                      ),
                    ),
                    titlePadding: const EdgeInsets.fromLTRB(28, 32, 28, 14),
                    contentPadding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                    actionsPadding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                    title: Text(
                      'Add custom ${_categoryTitle(category).toLowerCase()}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    content: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _customControllers[category],
                        autofocus: true,
                        style: TextStyle(color: cs.onSurface, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Type your custom option...',
                          filled: true,
                          fillColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2A1A1F)
                              : cs.surfaceContainerHighest.withValues(
                                  alpha: 0.8,
                                ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: cs.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF2E1D22)
                                      : cs.surfaceContainerHighest.withValues(
                                          alpha: 0.4,
                                        ),
                                  foregroundColor: cs.onSurfaceVariant,
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.primary.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.primary,
                                  foregroundColor: cs.onPrimary,
                                  elevation: 0,
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  final value = _customControllers[category]!
                                      .text
                                      .trim();
                                  if (value.isNotEmpty) {
                                    setState(() {
                                      _selected[category]!.add(value);
                                      _options[category]!.add(value);
                                    });
                                    _customControllers[category]!.clear();
                                  }
                                  Navigator.pop(context);
                                },
                                child: const Text('Add'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    for (final controller in _customControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const categories = ['food', 'outing', 'interests', 'location'];

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'CLOSR',
          style: textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.0,
            color: cs.primary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        children: [
          Text(
            'Make it feel like you.',
            style: textTheme.displayMedium?.copyWith(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a few favorites so your shared moments and ideas stay personal. You can always update these later.',
            style: textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ...categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF231519)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _categoryIcon(category),
                            size: 17,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _categoryTitle(category),
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                _categorySubtitle(category),
                                style: textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildChips(category),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                minimumSize: const Size.fromHeight(52),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                shadowColor: Colors.transparent,
              ),
              onPressed: () async {
                final prefs = {
                  'food': _selected['food'],
                  'outing': _selected['outing'],
                  'interests': _selected['interests'],
                  'location': _selected['location'],
                  'onboarded': true,
                };
                await _preferencesService.savePreferences(prefs);

                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({'onboarded': true}, SetOptions(merge: true));
                }

                if (context.mounted) {
                  final rawName = user?.displayName?.trim() ?? '';
                  final name = rawName.isEmpty
                      ? 'there'
                      : rawName.split(RegExp(r'\s+')).first;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WelcomeTransitionScreen(name: name),
                    ),
                  );
                }
              },
              child: const Text(
                'Save & continue',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
