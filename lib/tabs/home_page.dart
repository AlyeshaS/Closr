// lib/tabs/home_page.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../gemini_service.dart';
import '../widgets/sprite_animator.dart';
import '../models/room_theme.dart';
import '../models/furniture_meta.dart';

// How far up from the bottom of the screen the pet sits on the floor.
const double kPetFloorOffset = 16.0;

const Map<String, String> _kCompanionsImages = {
  '🐱': 'assets/images/cat.png',
  '🐶': 'assets/images/dog.png',
  '🐢': 'assets/images/turtle.png',
  '🐻': 'assets/images/bear.png',
  '🐦': 'assets/images/IdleBird.png',
  '🐰': 'assets/images/bunny.png',
  '🐨': 'assets/images/koala.png',
};

class _CompanionOption {
  final String emoji;
  final String defaultName;
  final String species;
  final String assetPath;
  final int totalFrames;
  final double frameWidth;
  final double frameHeight;
  const _CompanionOption(
    this.emoji,
    this.defaultName,
    this.species,
    this.assetPath,
    this.totalFrames,
    this.frameWidth,
    this.frameHeight,
  );
}

const _kCompanions = [
  _CompanionOption(
    '🐱',
    'Mochi',
    'Cat',
    'assets/images/cat.png',
    7,
    32.0,
    32.0,
  ),
  _CompanionOption(
    '🐶',
    'Biscuit',
    'Dog',
    'assets/images/dog.png',
    10,
    32.0,
    32.0,
  ),
  _CompanionOption(
    '🐢',
    'Shelly',
    'Turtle',
    'assets/images/turtle.png',
    8,
    32.0,
    32.0,
  ),
  _CompanionOption(
    '🐻',
    'Cosmo',
    'Bear',
    'assets/images/bear.png',
    6,
    32.0,
    32.0,
  ),
  _CompanionOption(
    '🐦',
    'Lilac',
    'Bird',
    'assets/images/IdleBird.png',
    6,
    16.0,
    16.0,
  ),
  _CompanionOption(
    '🐰',
    'Brownie',
    'Bunny',
    'assets/images/bunny.png',
    12,
    32.0,
    32.0,
  ),
  _CompanionOption(
    '🐨',
    'Kobi',
    'Koala',
    'assets/images/koala.png',
    7,
    32.0,
    32.0,
  ),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _entrance;
  late final AnimationController _flicker;
  late final AnimationController _floatController;
  final GeminiService _geminiService = GeminiService();
  bool _isEditingLayout = false;
  String _selectedRoomTheme = 'room_pink';
  bool _isLoadingRoom = true;
  bool _hasFurnitureSelection = false;
  bool _isFurnitureTrayOpen = false;
  final GlobalKey<_RoomFurnitureState> _roomFurnitureKey =
      GlobalKey<_RoomFurnitureState>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadEquippedRoom();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _flicker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  Future<void> _loadEquippedRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoadingRoom = false;
          _entrance.forward();
        });
      }
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('furniture')
          .where('isEquipped', isEqualTo: true)
          .get();
      final equippedRoom = snapshot.docs
          .map((doc) => doc.id)
          .where(kRoomThemes.containsKey)
          .firstOrNull;

      if (mounted) {
        setState(() {
          if (equippedRoom != null) {
            _selectedRoomTheme = equippedRoom;
          }
          _isLoadingRoom = false;
          _entrance.forward();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingRoom = false;
          _entrance.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _flicker.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Animation<double> _seg(double start, double end) {
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  void _showTipSheet(BuildContext context, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 28,
          ),
          child: _GlassCard(
            cs: cs,
            glowColor: cs.primary,
            gradientColors: [
              cs.primaryContainer.withValues(alpha: 0.92),
              cs.secondaryContainer.withValues(alpha: 0.7),
            ],
            child: FutureBuilder<String>(
              future: _geminiService.fetchQuoteOfTheDay(),
              builder: (context, snapshot) {
                final loading =
                    snapshot.connectionState == ConnectionState.waiting;
                final tipText = snapshot.hasError
                    ? 'Could not load tip.'
                    : (snapshot.data ?? '');

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SizeTransition(
                      sizeFactor: anim,
                      axisAlignment: -1,
                      child: child,
                    ),
                  ),
                  child: loading
                      ? _TipLoading(key: const ValueKey('tip-loading'), cs: cs)
                      : _TipLoaded(
                          key: const ValueKey('tip-loaded'),
                          cs: cs,
                          tipText: tipText,
                        ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showMatchesSheet(BuildContext context, ColorScheme cs, User? user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 28,
          ),
          child: _GlassCard(
            cs: cs,
            glowColor: cs.primary,
            gradientColors: [
              cs.primaryContainer.withValues(alpha: 0.92),
              cs.secondaryContainer.withValues(alpha: 0.7),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 18,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'MATCHED DATES',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).maybePop(),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surface.withValues(alpha: 0.5),
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: user == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Please log in to view matches.',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                        )
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('matched_suggestions')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final docs = snapshot.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                  horizontal: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.explore_outlined,
                                      color: cs.primary.withValues(alpha: 0.7),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        'No matched dates yet. Keep exploring suggestions together!',
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: docs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final data =
                                    docs[index].data() as Map<String, dynamic>?;
                                final title =
                                    data?['title'] ??
                                    data?['name'] ??
                                    'Date Idea';
                                final description =
                                    data?['description'] ??
                                    data?['subtitle'] ??
                                    data?['notes'] ??
                                    '';

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.surface.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: cs.outlineVariant.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Icon(
                                          Icons.bookmark_rounded,
                                          color: cs.primary,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: cs.onSurface,
                                              ),
                                            ),
                                            if (description.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                description,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: cs.onSurfaceVariant,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFurnitureInventory(BuildContext context, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      isScrollControlled: true,
      builder: (sheetContext) => _FurnitureInventorySheet(
        cs: cs,
        selectedRoomTheme: _selectedRoomTheme,
        onRoomThemeChanged: (themeKey) async {
          setState(() => _selectedRoomTheme = themeKey);
          await _equipRoomForCouple(themeKey);
        },
        onEditModeRequested: () {
          setState(() {
            _isEditingLayout = true;
            _isFurnitureTrayOpen = false;
          });
        },
      ),
    );
  }

  Future<void> _equipRoomForCouple(String themeKey) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !kRoomThemes.containsKey(themeKey)) return;

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final userSnapshot = await userRef.get();
    final userData = userSnapshot.data() ?? {};
    final partnerEmail =
        ((userData['partnerEmailLower'] as String?) ??
                (userData['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();
    final partnerQuery = partnerEmail.isNotEmpty
        ? await firestore
              .collection('users')
              .where('email', isEqualTo: partnerEmail)
              .get()
        : null;

    final userRefs = <DocumentReference>[userRef];
    if (partnerQuery != null) {
      userRefs.addAll(partnerQuery.docs.map((doc) => doc.reference));
    }

    final batch = firestore.batch();
    for (final ref in userRefs) {
      final furnitureRef = ref.collection('furniture');
      for (final roomKey in kRoomThemes.keys) {
        batch.set(furnitureRef.doc(roomKey), {
          'type': 'room',
          'name': kRoomThemes[roomKey]!.name,
          'themeKey': roomKey,
          'isEquipped': roomKey == themeKey,
        }, SetOptions(merge: true));
      }
    }
    await batch.commit();
  }

  List<Map<String, String>> get _editorFurnitureItems {
    final items = <Map<String, String>>[];

    kSofaAssets.forEach((key, path) {
      items.add({
        'itemKey': 'sofa_$key',
        'assetPath': path,
        'category': 'Sofas',
      });
    });
    kBedAssets.forEach((key, path) {
      items.add({'itemKey': 'bed_$key', 'assetPath': path, 'category': 'Beds'});
    });
    kDeskAssets.forEach((key, path) {
      items.add({
        'itemKey': 'desk_$key',
        'assetPath': path,
        'category': 'Desks',
      });
    });
    kRugAssets.forEach((key, path) {
      items.add({
        'itemKey': 'carpet_$key',
        'assetPath': path,
        'category': 'Rugs',
      });
    });
    kDecorAssets.forEach((key, path) {
      items.add({'itemKey': key, 'assetPath': path, 'category': 'Decor'});
    });

    return items;
  }

  String _editorFurnitureTitle(String itemKey) {
    var title = itemKey
        .replaceFirst(RegExp(r'^(sofa_|bed_|desk_|carpet_|rug_)'), '')
        .replaceAll('_', ' ')
        .trim();
    if (title.isEmpty) return 'Furniture';
    return title
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = FirebaseAuth.instance.currentUser;
    final cs = Theme.of(context).colorScheme;
    final firstName = user?.displayName?.split(' ').first ?? 'there';

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _RoomScene(
            isEditing: _isEditingLayout,
            colorScheme: cs,
            roomThemeKey: _selectedRoomTheme,
            furnitureKey: _roomFurnitureKey,
            onSelectionChanged: (hasSelection) {
              if (_hasFurnitureSelection != hasSelection && mounted) {
                setState(() => _hasFurnitureSelection = hasSelection);
              }
            },
          ),
        ),

        IgnorePointer(
          ignoring: !_isLoadingRoom,
          child: AnimatedOpacity(
            opacity: _isLoadingRoom ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            child: ColoredBox(
              color: cs.surfaceContainerHighest,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.1),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeInOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Icon(
                            Icons.chair_alt_rounded,
                            size: 48,
                            color: cs.primary,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Normal Header (When not editing)
        if (!_isEditingLayout)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Reveal(
                    animation: _seg(0.0, 0.45),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: cs.shadow.withValues(alpha: 0.07),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.1),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  cs.primaryContainer.withValues(alpha: 0.85),
                                  cs.secondaryContainer.withValues(alpha: 0.55),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: cs.primary.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: Theme.of(
                                            context,
                                          ).textTheme.headlineMedium,
                                          children: [
                                            const TextSpan(text: 'Hello, '),
                                            TextSpan(
                                              text: '$firstName.',
                                              style: TextStyle(
                                                fontStyle: FontStyle.italic,
                                                color: cs.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton.filledTonal(
                                      tooltip: 'Edit Room Layout',
                                      onPressed: () => setState(() {
                                        _isEditingLayout = true;
                                        _isFurnitureTrayOpen = false;
                                      }),
                                      icon: const Icon(
                                        Icons.edit_rounded,
                                        size: 20,
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor: cs.primary.withValues(
                                          alpha: 0.15,
                                        ),
                                        foregroundColor: cs.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Material(
                                  color: cs.surface.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    onTap: () => _showTipSheet(context, cs),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.auto_awesome_rounded,
                                            size: 16,
                                            color: cs.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Daily inspiration',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: cs.onSurface,
                                                ),
                                          ),
                                          const Spacer(),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            size: 16,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: StreamBuilder<QuerySnapshot>(
                                        stream: user != null
                                            ? FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(user.uid)
                                                  .collection(
                                                    'matched_suggestions',
                                                  )
                                                  .snapshots()
                                            : null,
                                        builder: (context, snapshot) {
                                          final count =
                                              snapshot.data?.docs.length ?? 0;
                                          return Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () => _showMatchesSheet(
                                                context,
                                                cs,
                                                user,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: _StatPill(
                                                cs: cs,
                                                icon: Icons.favorite_rounded,
                                                tint: cs.primary,
                                                label: '$count matches',
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: StreamBuilder<DocumentSnapshot>(
                                        stream: user != null
                                            ? FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(user.uid)
                                                  .snapshots()
                                            : null,
                                        builder: (context, snapshot) {
                                          final data =
                                              snapshot.data?.data()
                                                  as Map<String, dynamic>?;
                                          final streak =
                                              (data?['sharedStreakCurrent']
                                                  as int?) ??
                                              (data?['streakCurrent']
                                                  as int?) ??
                                              0;
                                          return _StatPill(
                                            cs: cs,
                                            icon: Icons
                                                .local_fire_department_rounded,
                                            tint: const Color(0xFFFF8A3D),
                                            label: '$streak day streak',
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (_isEditingLayout)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          cs.primaryContainer.withValues(alpha: 0.92),
                          cs.secondaryContainer.withValues(alpha: 0.72),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.shadow.withValues(alpha: 0.08),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Edit room',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.normal,
                                              fontSize: 19,
                                              color: cs.onSurface,
                                            ),
                                      ),
                                      const SizedBox(width: 0),
                                      Transform.translate(
                                        offset: const Offset(-3, 0),
                                        child: IconButton(
                                          tooltip: 'How room editing works',
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 34,
                                            minHeight: 34,
                                          ),
                                          onPressed: () {
                                            showModalBottomSheet<void>(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (sheetContext) {
                                                final sheetTheme = Theme.of(
                                                  sheetContext,
                                                );
                                                final sheetCs =
                                                    sheetTheme.colorScheme;
                                                final steps =
                                                    <
                                                      ({
                                                        IconData icon,
                                                        String title,
                                                        String body,
                                                      })
                                                    >[
                                                      (
                                                        icon: Icons
                                                            .touch_app_rounded,
                                                        title: 'Select',
                                                        body:
                                                            'Tap any unlocked furniture item to select it.',
                                                      ),
                                                      (
                                                        icon: Icons
                                                            .open_with_rounded,
                                                        title: 'Move',
                                                        body:
                                                            'Drag the selected item across the room grid to place it exactly where you want.',
                                                      ),
                                                      (
                                                        icon: Icons
                                                            .rotate_right_rounded,
                                                        title:
                                                            'Rotate & resize',
                                                        body:
                                                            'Use the Rotate and Size sliders for precise adjustments.',
                                                      ),
                                                      (
                                                        icon:
                                                            Icons.flip_rounded,
                                                        title: 'Flip',
                                                        body:
                                                            'Mirror the selected furniture with one tap.',
                                                      ),
                                                      (
                                                        icon:
                                                            Icons.lock_rounded,
                                                        title: 'Lock',
                                                        body:
                                                            'Double-tap an item to lock or unlock it. Locked furniture stays in place.',
                                                      ),
                                                      (
                                                        icon: Icons
                                                            .restart_alt_rounded,
                                                        title: 'Restart',
                                                        body:
                                                            'Return the selected item to the position, size, rotation and flip state it had when you selected it.',
                                                      ),
                                                      (
                                                        icon: Icons
                                                            .delete_outline_rounded,
                                                        title: 'Delete',
                                                        body:
                                                            'Delete the selected item. With nothing selected, Delete lets you remove all furniture after confirmation.',
                                                      ),
                                                      (
                                                        icon: Icons
                                                            .deselect_rounded,
                                                        title: 'Deselect',
                                                        body:
                                                            'Tap an empty part of the room to clear your selection.',
                                                      ),
                                                      (
                                                        icon:
                                                            Icons.check_rounded,
                                                        title: 'Finish',
                                                        body:
                                                            'Tap the checkmark when your room looks right.',
                                                      ),
                                                    ];

                                                return DraggableScrollableSheet(
                                                  initialChildSize: 0.72,
                                                  minChildSize: 0.48,
                                                  maxChildSize: 0.92,
                                                  expand: false,
                                                  builder: (context, scrollController) {
                                                    return Container(
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFF3E8D7,
                                                        ),
                                                        borderRadius:
                                                            const BorderRadius.vertical(
                                                              top:
                                                                  Radius.circular(
                                                                    32,
                                                                  ),
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: sheetCs
                                                                .shadow
                                                                .withValues(
                                                                  alpha: 0.16,
                                                                ),
                                                            blurRadius: 30,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  -8,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Column(
                                                        children: [
                                                          const SizedBox(
                                                            height: 10,
                                                          ),
                                                          Container(
                                                            width: 44,
                                                            height: 5,
                                                            decoration: BoxDecoration(
                                                              color: sheetCs
                                                                  .primary
                                                                  .withValues(
                                                                    alpha: 0.32,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    99,
                                                                  ),
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.fromLTRB(
                                                                  22,
                                                                  18,
                                                                  14,
                                                                  12,
                                                                ),
                                                            child: Row(
                                                              children: [
                                                                Container(
                                                                  width: 44,
                                                                  height: 44,
                                                                  decoration: BoxDecoration(
                                                                    color: sheetCs
                                                                        .primary
                                                                        .withValues(
                                                                          alpha:
                                                                              0.13,
                                                                        ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          14,
                                                                        ),
                                                                    border: Border.all(
                                                                      color: sheetCs
                                                                          .primary
                                                                          .withValues(
                                                                            alpha:
                                                                                0.18,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                  child: Icon(
                                                                    Icons
                                                                        .chair_alt_rounded,
                                                                    color: sheetCs
                                                                        .primary,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 12,
                                                                ),
                                                                Expanded(
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                        'How to edit your room',
                                                                        style: sheetTheme.textTheme.titleLarge?.copyWith(
                                                                          fontWeight:
                                                                              FontWeight.w700,
                                                                          color: const Color(
                                                                            0xFF3E342C,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            2,
                                                                      ),
                                                                      Text(
                                                                        'Scroll through the controls below',
                                                                        style: sheetTheme
                                                                            .textTheme
                                                                            .bodySmall
                                                                            ?.copyWith(
                                                                              color: const Color(
                                                                                0xFF786B60,
                                                                              ),
                                                                            ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                IconButton(
                                                                  tooltip:
                                                                      'Close',
                                                                  onPressed: () =>
                                                                      Navigator.of(
                                                                        sheetContext,
                                                                      ).pop(),
                                                                  icon: const Icon(
                                                                    Icons
                                                                        .close_rounded,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Divider(
                                                            height: 1,
                                                            color: sheetCs
                                                                .primary
                                                                .withValues(
                                                                  alpha: 0.12,
                                                                ),
                                                          ),
                                                          Expanded(
                                                            child: ListView.separated(
                                                              controller:
                                                                  scrollController,
                                                              padding:
                                                                  const EdgeInsets.fromLTRB(
                                                                    18,
                                                                    18,
                                                                    18,
                                                                    30,
                                                                  ),
                                                              itemCount:
                                                                  steps.length +
                                                                  1,
                                                              separatorBuilder:
                                                                  (_, __) =>
                                                                      const SizedBox(
                                                                        height:
                                                                            10,
                                                                      ),
                                                              itemBuilder: (context, index) {
                                                                if (index ==
                                                                    steps
                                                                        .length) {
                                                                  return Padding(
                                                                    padding:
                                                                        const EdgeInsets.only(
                                                                          top:
                                                                              6,
                                                                        ),
                                                                    child: Container(
                                                                      padding:
                                                                          const EdgeInsets.all(
                                                                            16,
                                                                          ),
                                                                      decoration: BoxDecoration(
                                                                        color: sheetCs
                                                                            .primary
                                                                            .withValues(
                                                                              alpha: 0.10,
                                                                            ),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              20,
                                                                            ),
                                                                        border: Border.all(
                                                                          color: sheetCs.primary.withValues(
                                                                            alpha:
                                                                                0.14,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      child: Row(
                                                                        children: [
                                                                          Icon(
                                                                            Icons.swipe_up_rounded,
                                                                            color:
                                                                                sheetCs.primary,
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                12,
                                                                          ),
                                                                          Expanded(
                                                                            child: Text(
                                                                              'Tip: drag this panel up for more room, or swipe it down when you are done.',
                                                                              style: sheetTheme.textTheme.bodyMedium?.copyWith(
                                                                                fontWeight: FontWeight.w600,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  );
                                                                }
                                                                final step =
                                                                    steps[index];
                                                                return TweenAnimationBuilder<
                                                                  double
                                                                >(
                                                                  duration: Duration(
                                                                    milliseconds:
                                                                        240 +
                                                                        (index *
                                                                            35),
                                                                  ),
                                                                  curve: Curves
                                                                      .easeOutCubic,
                                                                  tween: Tween(
                                                                    begin: 0,
                                                                    end: 1,
                                                                  ),
                                                                  builder:
                                                                      (
                                                                        context,
                                                                        value,
                                                                        child,
                                                                      ) => Transform.translate(
                                                                        offset: Offset(
                                                                          0,
                                                                          14 *
                                                                              (1 -
                                                                                  value),
                                                                        ),
                                                                        child: Opacity(
                                                                          opacity:
                                                                              value,
                                                                          child:
                                                                              child,
                                                                        ),
                                                                      ),
                                                                  child: Container(
                                                                    padding:
                                                                        const EdgeInsets.all(
                                                                          14,
                                                                        ),
                                                                    decoration: BoxDecoration(
                                                                      color: const Color(
                                                                        0xFFFFFBF5,
                                                                      ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            20,
                                                                          ),
                                                                      border: Border.all(
                                                                        color: sheetCs
                                                                            .primary
                                                                            .withValues(
                                                                              alpha: 0.12,
                                                                            ),
                                                                      ),
                                                                      boxShadow: [
                                                                        BoxShadow(
                                                                          color:
                                                                              const Color(
                                                                                0xFF5B4636,
                                                                              ).withValues(
                                                                                alpha: 0.06,
                                                                              ),
                                                                          blurRadius:
                                                                              12,
                                                                          offset: const Offset(
                                                                            0,
                                                                            4,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    child: Row(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Container(
                                                                          width:
                                                                              42,
                                                                          height:
                                                                              42,
                                                                          decoration: BoxDecoration(
                                                                            color: sheetCs.primary.withValues(
                                                                              alpha: 0.12,
                                                                            ),
                                                                            borderRadius: BorderRadius.circular(
                                                                              13,
                                                                            ),
                                                                          ),
                                                                          child: Icon(
                                                                            step.icon,
                                                                            size:
                                                                                21,
                                                                            color:
                                                                                sheetCs.primary,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              12,
                                                                        ),
                                                                        Expanded(
                                                                          child: Column(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            children: [
                                                                              Text(
                                                                                step.title,
                                                                                style: sheetTheme.textTheme.titleSmall?.copyWith(
                                                                                  fontWeight: FontWeight.w700,
                                                                                  color: const Color(
                                                                                    0xFF3E342C,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              const SizedBox(
                                                                                height: 3,
                                                                              ),
                                                                              Text(
                                                                                step.body,
                                                                                style: sheetTheme.textTheme.bodySmall?.copyWith(
                                                                                  color: const Color(
                                                                                    0xFF786B60,
                                                                                  ),
                                                                                  height: 1.35,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                );
                                                              },
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
                                          icon: Icon(
                                            Icons.info_outline_rounded,
                                            size: 25,
                                            color: cs.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Tap an item, then drag across grid',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            // Cancel Button (disregards changes)
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.shadow.withValues(alpha: 0.18),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton.filledTonal(
                                tooltip: 'Cancel',
                                onPressed: () {
                                  _roomFurnitureKey.currentState
                                      ?.cancelSelected();
                                  setState(() {
                                    _isEditingLayout = false;
                                    _isFurnitureTrayOpen = false;
                                  });
                                },
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 19,
                                  color: cs.onSurfaceVariant,
                                ),
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(7),
                                  backgroundColor: cs.surface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Done Button
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.primary.withValues(alpha: 0.28),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton.filled(
                                tooltip: 'Done',
                                onPressed: () {
                                  _roomFurnitureKey.currentState
                                      ?.saveSelected();
                                  setState(() {
                                    _isEditingLayout = false;
                                    _isFurnitureTrayOpen = false;
                                  });
                                },
                                icon: const Icon(Icons.check_rounded, size: 19),
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(7),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Dedicated row for Flip, Restart, Delete
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () => _roomFurnitureKey.currentState
                                    ?.toggleFlipSelected(),
                                icon: const Icon(Icons.flip_rounded, size: 16),
                                label: const Text(
                                  'Flip',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  minimumSize: const Size(0, 36),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () {
                                  _roomFurnitureKey.currentState
                                      ?.restartSelected();
                                  // Restart updates the furniture state internally.
                                  // Rebuild this parent too so the Rotate and Size
                                  // sliders immediately jump back to the restored values.
                                  setState(() {});
                                },
                                icon: const Icon(
                                  Icons.restart_alt_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Restart',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  minimumSize: const Size(0, 36),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () async {
                                  final roomState =
                                      _roomFurnitureKey.currentState;
                                  if (roomState == null) return;

                                  if (roomState.hasSelection) {
                                    await roomState.deleteSelected();
                                    return;
                                  }

                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text(
                                        'Delete all furniture?',
                                      ),
                                      content: const Text(
                                        'No item is selected. This will remove all furniture currently placed in the room.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(
                                            dialogContext,
                                          ).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () => Navigator.of(
                                            dialogContext,
                                          ).pop(true),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: cs.error,
                                            foregroundColor: cs.onError,
                                          ),
                                          child: const Text('Delete all'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    await roomState.deleteAllFurniture();
                                  }
                                },
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: cs.error,
                                ),
                                label: Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: cs.error,
                                    fontSize: 12,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  minimumSize: const Size(0, 36),
                                  backgroundColor: cs.errorContainer.withValues(
                                    alpha: 0.3,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Rotate slider
                        Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: Text(
                                'Rotate',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SizedBox(
                                height: 26,
                                child: Slider(
                                  value:
                                      _roomFurnitureKey
                                          .currentState
                                          ?._editingVisualRotation ??
                                      0.0,
                                  min: -math.pi,
                                  max: math.pi,
                                  onChanged: _hasFurnitureSelection
                                      ? (val) {
                                          setState(() {
                                            _roomFurnitureKey.currentState
                                                ?.setRotationSelected(val);
                                          });
                                        }
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Size slider
                        Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: Text(
                                'Size',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SizedBox(
                                height: 26,
                                child: Slider(
                                  value:
                                      _roomFurnitureKey
                                          .currentState
                                          ?._editingVisualScale ??
                                      1.0,
                                  min: 0.3,
                                  max: 2.0,
                                  onChanged: _hasFurnitureSelection
                                      ? (val) {
                                          setState(() {
                                            _roomFurnitureKey.currentState
                                                ?.setScaleSelected(val);
                                          });
                                        }
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        if (_isEditingLayout)
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 14,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _isFurnitureTrayOpen
                  ? Material(
                      key: const ValueKey('furniture-tray-open'),
                      elevation: 14,
                      color: cs.surface.withValues(alpha: 0.98),
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.chair_alt_rounded,
                                    color: cs.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Furniture',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      Text(
                                        'Tap an item to add it',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                              fontSize: 11,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton.filledTonal(
                                  tooltip: 'Close furniture',
                                  onPressed: () => setState(
                                    () => _isFurnitureTrayOpen = false,
                                  ),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  style: IconButton.styleFrom(
                                    padding: const EdgeInsets.all(4),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 110,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: _editorFurnitureItems.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final item = _editorFurnitureItems[index];
                                  final itemKey = item['itemKey']!;
                                  final assetPath = item['assetPath']!;
                                  final category = item['category']!;

                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: user == null
                                          ? null
                                          : () => _roomFurnitureKey.currentState
                                                ?.addFurnitureItem(
                                                  itemKey,
                                                  category,
                                                ),
                                      child: Container(
                                        width: 90,
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: cs.surfaceContainerHighest
                                              .withValues(alpha: 0.72),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: cs.outlineVariant.withValues(
                                              alpha: 0.45,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: Stack(
                                                children: [
                                                  Positioned.fill(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            2,
                                                          ),
                                                      child: Image.asset(
                                                        assetPath,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    right: 0,
                                                    top: 0,
                                                    child: Container(
                                                      width: 22,
                                                      height: 22,
                                                      decoration: BoxDecoration(
                                                        color: cs.primary,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: cs.surface,
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        Icons.add_rounded,
                                                        size: 14,
                                                        color: cs.onPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _editorFurnitureTitle(itemKey),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: cs.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

        if (_isEditingLayout && !_isFurnitureTrayOpen)
          Positioned(
            right: 24,
            bottom: kPetFloorOffset + 20,
            child: Material(
              key: const ValueKey('furniture-tray-closed-plus'),
              color: cs.surface.withValues(alpha: 0.9),
              shape: const CircleBorder(),
              elevation: 6,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _isFurnitureTrayOpen = true),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Icon(Icons.add_rounded, color: cs.primary, size: 28),
                ),
              ),
            ),
          ),

        if (!_isEditingLayout)
          Positioned(
            left: 0,
            right: 0,
            bottom: kPetFloorOffset,
            child: IgnorePointer(
              ignoring: _isEditingLayout,
              child: Center(
                child: _Reveal(
                  animation: _seg(0.15, 0.7),
                  beginOffset: const Offset(0, 0.08),
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: user != null
                        ? FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .snapshots()
                        : null,
                    builder: (context, snapshot) {
                      final data =
                          snapshot.data?.data() as Map<String, dynamic>?;

                      final companionEmoji =
                          (data?['companionEmoji'] as String?) ?? '🐱';
                      final companionSource =
                          (data?['companionAsset'] as String?) ??
                          (data?['companionLottie'] as String?) ??
                          _kCompanionsImages[companionEmoji] ??
                          'assets/images/cat.png';

                      final equipped = List<String>.from(
                        (data?['equippedAccessories'] as List?) ?? const [],
                      );

                      return _CharacterSprite(
                        source: companionSource,
                        fallbackEmoji: companionEmoji,
                        equippedAccessories: equipped,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        if (!_isEditingLayout)
          Positioned(
            right: 24,
            bottom: kPetFloorOffset + 20,
            child: IgnorePointer(
              ignoring: _isEditingLayout,
              child: _Reveal(
                animation: _seg(0.3, 0.8),
                child: Material(
                  color: cs.surface.withValues(alpha: 0.9),
                  shape: const CircleBorder(),
                  elevation: 6,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _showFurnitureInventory(context, cs),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Icon(
                        Icons.chair_alt_rounded,
                        color: cs.primary,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RoomCanvas {
  static double get furnitureSquarePixels =>
      size.width / _RoomGeometry.floorColumns;

  static const Size size = Size(853, 1844);
  static const double displayScale = 1.0;
  static const Alignment displayScaleAlignment = Alignment(0, 0.18);
}

class _RoomGeometry {
  static const double leftX = 0.0;
  static const double centerX = 0.5;
  static const double rightX = 1.0;

  static const double ceilingCenterY = 41 / 1844;
  static const double ceilingLeftEdgeY = 166 / 1844;
  static const double ceilingRightEdgeY = 166 / 1844;

  static const double floorCornerY = 1090 / 1844;
  static const double floorLeftEdgeY = 1223 / 1844;
  static const double floorRightEdgeY = 1221 / 1844;

  static const int wallColumns = 8;
  static const int wallRows = 14;
  static const int floorColumns = 8;
  static const int floorGridDepth = 24;
}

class _RoomScene extends StatelessWidget {
  final bool isEditing;
  final ColorScheme colorScheme;
  final String roomThemeKey;
  final GlobalKey<_RoomFurnitureState> furnitureKey;
  final ValueChanged<bool>? onSelectionChanged;

  const _RoomScene({
    required this.isEditing,
    required this.colorScheme,
    required this.roomThemeKey,
    required this.furnitureKey,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Transform.scale(
        scale: _RoomCanvas.displayScale,
        alignment: _RoomCanvas.displayScaleAlignment,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = math.max(
              constraints.maxWidth / _RoomCanvas.size.width,
              constraints.maxHeight / _RoomCanvas.size.height,
            );
            return FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              child: SizedBox(
                width: _RoomCanvas.size.width,
                height: _RoomCanvas.size.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _RoomBackgroundPainter(
                        theme:
                            kRoomThemes[roomThemeKey] ??
                            kRoomThemes['room_pink']!,
                      ),
                    ),
                    _RoomFurniture(
                      key: furnitureKey,
                      isEditing: isEditing,
                      colorScheme: colorScheme,
                      canvasScale: scale,
                      onSelectionChanged: onSelectionChanged,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoomBackgroundPainter extends CustomPainter {
  final RoomTheme theme;

  const _RoomBackgroundPainter({required this.theme});

  Rect _roomRect(Size size) => Offset.zero & size;

  Offset _p(Size size, double x, double y) {
    final r = _roomRect(size);
    return Offset(r.left + r.width * x, r.top + r.height * y);
  }

  Path _leftWallPath(Size size) {
    final r = _roomRect(size);
    final topCenter = Offset(r.left + r.width * _RoomGeometry.centerX, r.top);
    final topLeft = Offset(r.left + r.width * _RoomGeometry.leftX, r.top);
    final floorLeft = _p(
      size,
      _RoomGeometry.leftX,
      _RoomGeometry.floorLeftEdgeY,
    );
    final floorCorner = _p(
      size,
      _RoomGeometry.centerX,
      _RoomGeometry.floorCornerY,
    );

    return Path()
      ..moveTo(topCenter.dx, topCenter.dy)
      ..lineTo(topLeft.dx, topLeft.dy)
      ..lineTo(floorLeft.dx, floorLeft.dy)
      ..lineTo(floorCorner.dx, floorCorner.dy)
      ..close();
  }

  Path _rightWallPath(Size size) {
    final r = _roomRect(size);
    final topCenter = Offset(r.left + r.width * _RoomGeometry.centerX, r.top);
    final topRight = Offset(r.left + r.width * _RoomGeometry.rightX, r.top);
    final floorRight = _p(
      size,
      _RoomGeometry.rightX,
      _RoomGeometry.floorRightEdgeY,
    );
    final floorCorner = _p(
      size,
      _RoomGeometry.centerX,
      _RoomGeometry.floorCornerY,
    );

    return Path()
      ..moveTo(topCenter.dx, topCenter.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(floorRight.dx, floorRight.dy)
      ..lineTo(floorCorner.dx, floorCorner.dy)
      ..close();
  }

  Path _floorPath(Size size) {
    final r = _roomRect(size);
    final left = _p(size, _RoomGeometry.leftX, _RoomGeometry.floorLeftEdgeY);
    final corner = _p(size, _RoomGeometry.centerX, _RoomGeometry.floorCornerY);
    final right = _p(size, _RoomGeometry.rightX, _RoomGeometry.floorRightEdgeY);
    final bottomRight = Offset(
      r.left + r.width * _RoomGeometry.rightX,
      r.bottom,
    );
    final bottomLeft = Offset(r.left + r.width * _RoomGeometry.leftX, r.bottom);

    return Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(corner.dx, corner.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();
  }

  Path _baseboardLeftPath(Size size) {
    final wallCorner = _p(
      size,
      _RoomGeometry.centerX,
      _RoomGeometry.floorCornerY,
    );
    final wallLeft = _p(
      size,
      _RoomGeometry.leftX,
      _RoomGeometry.floorLeftEdgeY,
    );
    const thickness = 22.0;
    final topCorner = Offset(wallCorner.dx, wallCorner.dy - thickness);
    final topLeft = Offset(wallLeft.dx, wallLeft.dy - thickness);

    return Path()
      ..moveTo(topCorner.dx, topCorner.dy)
      ..lineTo(topLeft.dx, topLeft.dy)
      ..lineTo(wallLeft.dx, wallLeft.dy)
      ..lineTo(wallCorner.dx, wallCorner.dy)
      ..close();
  }

  Path _baseboardRightPath(Size size) {
    final wallCorner = _p(
      size,
      _RoomGeometry.centerX,
      _RoomGeometry.floorCornerY,
    );
    final wallRight = _p(
      size,
      _RoomGeometry.rightX,
      _RoomGeometry.floorRightEdgeY,
    );
    const thickness = 22.0;
    final topCorner = Offset(wallCorner.dx, wallCorner.dy - thickness);
    final topRight = Offset(wallRight.dx, wallRight.dy - thickness);

    return Path()
      ..moveTo(topCorner.dx, topCorner.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(wallRight.dx, wallRight.dy)
      ..lineTo(wallCorner.dx, wallCorner.dy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final room = _roomRect(size);
    canvas.drawRect(room, Paint()..color = theme.leftTop);

    final leftWallPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [theme.leftTop, theme.leftBottom],
      ).createShader(room);

    final rightWallPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [theme.rightTop, theme.rightBottom],
      ).createShader(room);

    final floorPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.floorTop, theme.floorBottom],
      ).createShader(room);

    canvas.drawPath(_leftWallPath(size), leftWallPaint);
    canvas.drawPath(_rightWallPath(size), rightWallPaint);
    canvas.drawPath(_floorPath(size), floorPaint);

    final baseboardPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.baseboardLight, theme.baseboardDark],
      ).createShader(room);

    canvas.drawPath(_baseboardLeftPath(size), baseboardPaint);
    canvas.drawPath(_baseboardRightPath(size), baseboardPaint);

    final topCenter = Offset(
      room.left + room.width * _RoomGeometry.centerX,
      room.top,
    );
    final floorCorner = _p(
      size,
      _RoomGeometry.centerX,
      _RoomGeometry.floorCornerY,
    );

    canvas.drawLine(
      topCenter,
      floorCorner,
      Paint()
        ..color = theme.seam.withValues(alpha: 0.45)
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant _RoomBackgroundPainter oldDelegate) =>
      oldDelegate.theme != theme;
}

class _RoomPoint {
  final Offset anchor;
  final double scale;
  const _RoomPoint(this.anchor, this.scale);
}

class _RoomPerspective {
  const _RoomPerspective(this.size);
  final Size size;

  static const double kMinDepthScale = 0.55;
  static const double kPerspectiveGamma = 1.5;

  Rect get roomRect => Offset.zero & size;

  double get leftX => roomRect.left + roomRect.width * _RoomGeometry.leftX;
  double get centerX => roomRect.left + roomRect.width * _RoomGeometry.centerX;
  double get rightX => roomRect.left + roomRect.width * _RoomGeometry.rightX;
  double get cornerVertexY =>
      roomRect.top + roomRect.height * _RoomGeometry.floorCornerY;
  double get _leftSeamEdgeY =>
      roomRect.top + roomRect.height * _RoomGeometry.floorLeftEdgeY;
  double get _rightSeamEdgeY =>
      roomRect.top + roomRect.height * _RoomGeometry.floorRightEdgeY;

  double _ease(double t) =>
      math.pow(t.clamp(0.0, 1.0), kPerspectiveGamma).toDouble();

  double seamYAtCanvasX(double x) {
    if (x <= centerX) {
      final denom = centerX - leftX;
      final t = denom.abs() < 0.0001
          ? 0.0
          : ((centerX - x) / denom).clamp(0.0, 1.0);
      return lerpDouble(cornerVertexY, _leftSeamEdgeY, t)!;
    }
    final denom = rightX - centerX;
    final t = denom.abs() < 0.0001
        ? 0.0
        : ((x - centerX) / denom).clamp(0.0, 1.0);
    return lerpDouble(cornerVertexY, _rightSeamEdgeY, t)!;
  }

  Offset floorGridIntersection(double gridX, double gridY) {
    final corner = Offset(
      roomRect.left + roomRect.width * _RoomGeometry.centerX,
      roomRect.top + roomRect.height * _RoomGeometry.floorCornerY,
    );
    final leftEdge = Offset(
      roomRect.left + roomRect.width * _RoomGeometry.leftX,
      roomRect.top + roomRect.height * _RoomGeometry.floorLeftEdgeY,
    );
    final rightEdge = Offset(
      roomRect.left + roomRect.width * _RoomGeometry.rightX,
      roomRect.top + roomRect.height * _RoomGeometry.floorRightEdgeY,
    );

    final n = _RoomGeometry.floorColumns.toDouble();
    final startLeft = Offset.lerp(corner, leftEdge, gridX / n)!;
    final startRight = Offset.lerp(corner, rightEdge, gridY / n)!;

    final leftSlope = (leftEdge.dy - corner.dy) / (leftEdge.dx - corner.dx);
    final rightSlope = (rightEdge.dy - corner.dy) / (rightEdge.dx - corner.dx);

    final m1 = rightSlope;
    final m2 = leftSlope;
    final b1 = startLeft.dy - m1 * startLeft.dx;
    final b2 = startRight.dy - m2 * startRight.dx;

    final x = (b2 - b1) / (m1 - m2);
    final y = m1 * x + b1;
    return Offset(x, y);
  }

  Path floorPath() {
    final left = Offset(
      roomRect.left + roomRect.width * _RoomGeometry.leftX - 1.0,
      roomRect.top + roomRect.height * _RoomGeometry.floorLeftEdgeY,
    );
    final corner = Offset(
      roomRect.left + roomRect.width * _RoomGeometry.centerX,
      roomRect.top + roomRect.height * _RoomGeometry.floorCornerY,
    );
    final right = Offset(
      roomRect.left + roomRect.width * _RoomGeometry.rightX + 1.0,
      roomRect.top + roomRect.height * _RoomGeometry.floorRightEdgeY,
    );

    return Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(corner.dx, corner.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(roomRect.right, roomRect.bottom)
      ..lineTo(roomRect.left, roomRect.bottom)
      ..close();
  }

  bool floorFootprintFits({
    required int gridX,
    required int gridY,
    required int widthSquares,
    required int lengthSquares,
    double visualScale = 1.0,
  }) {
    final path = floorPath();

    // Validate the grid anchor itself instead of the centre of the furniture.
    // Using width/length to offset this point was still pushing wide items
    // outside the floor polygon near the right wall, leaving the last visible
    // grid strip unreachable. Every visible floor grid anchor should remain
    // usable regardless of the furniture PNG dimensions.
    final placementAnchor = floorGridIntersection(
      gridX.toDouble(),
      gridY.toDouble(),
    );

    if (path.contains(placementAnchor)) return true;

    // Let the visual item reach the wall-side cells. The furniture is drawn
    // around a multi-square footprint, so validating only the exact anchor
    // makes the sprite appear one strip too far inward near the walls. Allow
    // roughly one grid-cell of horizontal edge tolerance while still requiring
    // the placement to remain adjacent to the floor polygon.
    final edgeTolerance = (size.width / _RoomGeometry.floorColumns) * 0.72;
    return path.contains(placementAnchor + Offset(-edgeTolerance, 0)) ||
        path.contains(placementAnchor + Offset(edgeTolerance, 0));
  }

  List<Offset> floorFootprint({
    required int gridX,
    required int gridY,
    required int widthSquares,
    required int lengthSquares,
  }) {
    return [
      floorGridIntersection(gridX.toDouble(), gridY.toDouble()),
      floorGridIntersection(
        (gridX + widthSquares).toDouble(),
        gridY.toDouble(),
      ),
      floorGridIntersection(
        (gridX + widthSquares).toDouble(),
        (gridY + lengthSquares).toDouble(),
      ),
      floorGridIntersection(
        gridX.toDouble(),
        (gridY + lengthSquares).toDouble(),
      ),
    ];
  }

  Rect floorFootprintBounds({
    required int gridX,
    required int gridY,
    required int widthSquares,
    required int lengthSquares,
  }) {
    final points = floorFootprint(
      gridX: gridX,
      gridY: gridY,
      widthSquares: widthSquares,
      lengthSquares: lengthSquares,
    );
    final xs = points.map((p) => p.dx).toList();
    final ys = points.map((p) => p.dy).toList();
    return Rect.fromLTRB(
      xs.reduce((a, b) => a < b ? a : b),
      ys.reduce((a, b) => a < b ? a : b),
      xs.reduce((a, b) => a > b ? a : b),
      ys.reduce((a, b) => a > b ? a : b),
    );
  }

  _RoomPoint floorPoint(double col, double row) {
    final c = col.clamp(0.0, 1.0);
    final x = lerpDouble(leftX, rightX, c)!;
    final seamY = seamYAtCanvasX(x);
    final t = _ease(row);
    final y = lerpDouble(seamY, roomRect.bottom, t)!;
    final scale = lerpDouble(kMinDepthScale, 1.0, t)!;
    return _RoomPoint(Offset(x, y), scale);
  }

  _RoomPoint wallPoint(RoomSurface side, double col, double row) {
    final outerX = side == RoomSurface.leftWall ? leftX : rightX;
    final dt = _ease(col);
    final x = lerpDouble(centerX, outerX, dt)!;
    final floorY = seamYAtCanvasX(x);
    final ceilingY = side == RoomSurface.leftWall
        ? lerpDouble(
            roomRect.top + roomRect.height * _RoomGeometry.ceilingCenterY,
            roomRect.top + roomRect.height * _RoomGeometry.ceilingLeftEdgeY,
            dt,
          )!
        : lerpDouble(
            roomRect.top + roomRect.height * _RoomGeometry.ceilingCenterY,
            roomRect.top + roomRect.height * _RoomGeometry.ceilingRightEdgeY,
            dt,
          )!;
    final y = lerpDouble(floorY, ceilingY, row.clamp(0.0, 1.0))!;
    final scale = lerpDouble(kMinDepthScale, 1.0, dt)!;
    return _RoomPoint(Offset(x, y), scale);
  }

  _RoomPoint pointFor(RoomSurface surface, double col, double row) {
    if (surface == RoomSurface.floor) {
      return floorPoint(col, row);
    }
    return wallPoint(surface, col, row);
  }
}

class _RoomFurniture extends StatefulWidget {
  final bool isEditing;
  final ColorScheme colorScheme;
  final double canvasScale;
  final ValueChanged<bool>? onSelectionChanged;

  const _RoomFurniture({
    super.key,
    required this.isEditing,
    required this.colorScheme,
    required this.canvasScale,
    this.onSelectionChanged,
  });

  @override
  State<_RoomFurniture> createState() => _RoomFurnitureState();
}

class _FurnitureSessionSnapshot {
  final Map<String, Map<String, dynamic>> documents;
  final String? selectedDocId;
  final String? selectedItemKey;
  final double? col;
  final double? row;
  final double? visualScale;
  final double? visualRotation;
  final bool flipX;
  final bool flipY;
  final bool locked;

  const _FurnitureSessionSnapshot({
    required this.documents,
    required this.selectedDocId,
    required this.selectedItemKey,
    required this.col,
    required this.row,
    required this.visualScale,
    required this.visualRotation,
    required this.flipX,
    required this.flipY,
    required this.locked,
  });
}

class _RoomFurnitureState extends State<_RoomFurniture> {
  double? _editingCol;
  double? _editingRow;
  String? _editingDocId;
  String? _editingItemKey;
  bool _wasEditing = false;
  double _accumulatedDragX = 0.0;
  double _accumulatedDragY = 0.0;
  Offset? _lastDragGlobalPosition;
  double? _editingVisualScale;
  double? _editingVisualRotation;
  bool _editingFlipX = false;
  bool _editingFlipY = false;
  bool _editingLocked = false;

  // Session-only undo history. It is cleared when Edit Room ends.
  final List<_FurnitureSessionSnapshot> _undoHistory = [];
  Map<String, Map<String, dynamic>> _latestFurnitureData = {};
  String? _lastUndoMergeKey;
  DateTime? _lastUndoRecordAt;
  bool _isRestoringUndo = false;

  // Initial state snapshots for Restart & Cancel
  double? _initialCol;
  double? _initialRow;
  double? _initialVisualScale;
  double? _initialVisualRotation;
  bool _initialFlipX = false;
  bool _initialFlipY = false;
  bool _initialLocked = false;

  void _notifySelectionChanged(bool hasSelection) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSelectionChanged?.call(hasSelection);
    });
  }

  Map<String, dynamic> _docData(QueryDocumentSnapshot doc) =>
      (doc.data() as Map<String, dynamic>?) ?? const {};

  String _itemKeyForDoc(QueryDocumentSnapshot doc) {
    final data = _docData(doc);
    return (data['itemKey'] as String?) ?? doc.id;
  }

  double _visualRotationForFurniture(String itemKey) {
    if (itemKey == 'aquarium') return 0.0;
    if (itemKey.startsWith('sofa_') || kSofaAssets.containsKey(itemKey)) {
      return 0.055;
    }
    if (itemKey.startsWith('bed_') || kBedAssets.containsKey(itemKey)) {
      return 0.038;
    }
    if (itemKey.startsWith('desk_') || kDeskAssets.containsKey(itemKey)) {
      return 0.032;
    }
    return 0.0;
  }

  double _visualScaleForFurniture(String itemKey) {
    if (itemKey == 'aquarium') return 1.0;
    if (itemKey.startsWith('sofa_') || kSofaAssets.containsKey(itemKey)) {
      return 0.68;
    }
    if (itemKey.startsWith('bed_') || kBedAssets.containsKey(itemKey)) {
      return 0.58;
    }
    if (itemKey.startsWith('desk_') || kDeskAssets.containsKey(itemKey)) {
      return 0.68;
    }
    if (itemKey.startsWith('carpet_') ||
        itemKey.startsWith('rug_') ||
        kRugAssets.containsKey(itemKey)) {
      return 0.52;
    }
    switch (itemKey) {
      case 'bookcase':
        return 1.18;
      case 'candle':
        return 0.82;
      case 'dog':
        return 0.95;
      case 'television':
        return 1.10;
      case 'plant':
        return 1.02;
      default:
        return 1.0;
    }
  }

  void _clearSelection() {
    _editingCol = null;
    _editingRow = null;
    _editingDocId = null;
    _editingItemKey = null;
    _editingVisualScale = null;
    _editingVisualRotation = null;
    _editingFlipX = false;
    _editingFlipY = false;
    _editingLocked = false;
    _initialCol = null;
    _initialRow = null;
    _initialVisualScale = null;
    _initialVisualRotation = null;
    _initialFlipX = false;
    _initialFlipY = false;
    _initialLocked = false;
    _notifySelectionChanged(false);
  }

  void _selectItem(QueryDocumentSnapshot doc, User? user) {
    if (_editingDocId == doc.id) return;
    if (user != null && _editingDocId != null) {
      _saveCurrentSelection(user);
    }

    final data = _docData(doc);
    final itemKey = _itemKeyForDoc(doc);
    final meta = getFurnitureMeta(itemKey);
    final location = data['location'] as Map<String, dynamic>?;
    final defaultRow = meta.surface == RoomSurface.floor ? 0.35 : 0.5;

    final col = (location?['col'] as num?)?.toDouble() ?? 0.5;
    final row = (location?['row'] as num?)?.toDouble() ?? defaultRow;
    final scale =
        (data['visualScale'] as num?)?.toDouble() ??
        _visualScaleForFurniture(itemKey);
    final rotation =
        (data['visualRotation'] as num?)?.toDouble() ??
        _visualRotationForFurniture(itemKey);
    final flipX = (data['flipX'] as bool?) ?? false;
    final flipY = (data['flipY'] as bool?) ?? false;
    final isLocked = (data['isLocked'] as bool?) ?? false;

    if (isLocked) return;

    setState(() {
      _editingDocId = doc.id;
      _editingItemKey = itemKey;
      _editingCol = col;
      _editingRow = row;
      _editingVisualScale = scale;
      _editingVisualRotation = rotation;
      _editingFlipX = flipX;
      _editingFlipY = flipY;
      _editingLocked = false;

      _initialCol = col;
      _initialRow = row;
      _initialVisualScale = scale;
      _initialVisualRotation = rotation;
      _initialFlipX = flipX;
      _initialFlipY = flipY;
      _initialLocked = false;
    });
    _notifySelectionChanged(true);
  }

  bool get hasSelection => _editingDocId != null;

  Future<void> saveSelected() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _saveCurrentSelection(user);
  }

  void cancelSelected() {
    if (_editingDocId != null && _initialCol != null) {
      setState(() {
        _editingCol = _initialCol;
        _editingRow = _initialRow;
        _editingVisualScale = _initialVisualScale;
        _editingVisualRotation = _initialVisualRotation;
        _editingFlipX = _initialFlipX;
        _editingFlipY = _initialFlipY;
        _editingLocked = _initialLocked;
      });
    }
    _clearSelection();
  }

  Future<void> addFurnitureItem(String itemKey, String category) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _addItem(user, itemKey, category);
  }

  void flipSelected() {
    if (_editingDocId == null) return;
    setState(() => _editingFlipX = !_editingFlipX);
  }

  void toggleFlipSelected() {
    if (_editingDocId == null) return;
    setState(() => _editingFlipX = !_editingFlipX);
  }

  void setScaleSelected(double scale) {
    if (_editingDocId == null) return;
    setState(() => _editingVisualScale = scale);
  }

  void setRotationSelected(double rotation) {
    if (_editingDocId == null) return;
    setState(() => _editingVisualRotation = rotation);
  }

  void rotateSelected() {
    if (_editingDocId == null) return;
    setState(() {
      _editingVisualRotation =
          (_editingVisualRotation ?? 0.0) + (15 * math.pi / 180);
    });
  }

  void restartSelected() {
    if (_editingDocId == null || _initialCol == null || _initialRow == null)
      return;

    setState(() {
      _editingCol = _initialCol;
      _editingRow = _initialRow;
      _editingVisualScale = _initialVisualScale;
      _editingVisualRotation = _initialVisualRotation;
      _editingFlipX = _initialFlipX;
      _editingFlipY = _initialFlipY;
      _editingLocked = _initialLocked;
      _accumulatedDragX = 0.0;
      _accumulatedDragY = 0.0;
      _lastDragGlobalPosition = null;
    });
  }

  Future<void> undoLastAction() async {
    if (_undoHistory.isEmpty || _isRestoringUndo) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = _undoHistory.removeLast();
    _lastUndoMergeKey = null;
    _lastUndoRecordAt = null;
    _isRestoringUndo = true;

    try {
      await _restoreSessionSnapshot(user, snapshot);
    } finally {
      _isRestoringUndo = false;
    }
  }

  Future<void> deleteSelected() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _editingDocId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('furniture')
        .get();

    await _removeSelectedItem(user, snapshot.docs);
  }

  Future<void> deleteAllFurniture() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final snapshot = await userRef.collection('furniture').get();
    if (snapshot.docs.isEmpty) return;

    final userData = (await userRef.get()).data() ?? {};
    final partnerEmail =
        ((userData['partnerEmailLower'] as String?) ??
                (userData['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();

    DocumentReference? partnerRef;
    if (partnerEmail.isNotEmpty) {
      final partnerQuery = await firestore
          .collection('users')
          .where('email', isEqualTo: partnerEmail)
          .limit(1)
          .get();
      if (partnerQuery.docs.isNotEmpty) {
        partnerRef = partnerQuery.docs.first.reference;
      }
    }

    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      final data = _docData(doc);
      final isInstance =
          data['type'] == 'furnitureInstance' || data.containsKey('itemKey');

      final targets = <DocumentReference>[
        userRef.collection('furniture').doc(doc.id),
        if (partnerRef != null) partnerRef.collection('furniture').doc(doc.id),
      ];

      for (final ref in targets) {
        if (isInstance) {
          batch.delete(ref);
        } else {
          batch.set(ref, {'isEquipped': false}, SetOptions(merge: true));
        }
      }
    }

    await batch.commit();

    if (!mounted) return;
    setState(_clearSelection);
  }

  Map<String, dynamic> _cloneMap(Map<String, dynamic> source) {
    dynamic cloneValue(dynamic value) {
      if (value is Map) {
        return value.map(
          (key, val) => MapEntry(key.toString(), cloneValue(val)),
        );
      }
      if (value is List) return value.map(cloneValue).toList();
      return value;
    }

    return source.map((key, value) => MapEntry(key, cloneValue(value)));
  }

  void _recordUndoSnapshot({String? mergeKey}) {
    if (!widget.isEditing || _isRestoringUndo) return;

    final now = DateTime.now();
    final shouldMerge =
        mergeKey != null &&
        _lastUndoMergeKey == mergeKey &&
        _lastUndoRecordAt != null &&
        now.difference(_lastUndoRecordAt!) < const Duration(milliseconds: 450);

    if (shouldMerge) {
      _lastUndoRecordAt = now;
      return;
    }

    final docs = <String, Map<String, dynamic>>{};
    for (final entry in _latestFurnitureData.entries) {
      docs[entry.key] = _cloneMap(entry.value);
    }

    // Firestore can lag behind the item currently being edited, so make the
    // snapshot reflect exactly what the user sees on screen right now.
    if (_editingDocId != null &&
        _editingCol != null &&
        _editingRow != null &&
        docs.containsKey(_editingDocId)) {
      final live = _cloneMap(docs[_editingDocId]!);
      live['location'] = {'col': _editingCol, 'row': _editingRow};
      if (_editingVisualScale != null)
        live['visualScale'] = _editingVisualScale;
      if (_editingVisualRotation != null) {
        live['visualRotation'] = _editingVisualRotation;
      }
      live['flipX'] = _editingFlipX;
      live['flipY'] = _editingFlipY;
      live['isLocked'] = _editingLocked;
      docs[_editingDocId!] = live;
    }

    _undoHistory.add(
      _FurnitureSessionSnapshot(
        documents: docs,
        selectedDocId: _editingDocId,
        selectedItemKey: _editingItemKey,
        col: _editingCol,
        row: _editingRow,
        visualScale: _editingVisualScale,
        visualRotation: _editingVisualRotation,
        flipX: _editingFlipX,
        flipY: _editingFlipY,
        locked: _editingLocked,
      ),
    );

    _lastUndoMergeKey = mergeKey;
    _lastUndoRecordAt = now;
  }

  Future<void> _restoreSessionSnapshot(
    User user,
    _FurnitureSessionSnapshot snapshot,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final current = await userRef.collection('furniture').get();
    final userData = (await userRef.get()).data() ?? {};
    final partnerEmail =
        ((userData['partnerEmailLower'] as String?) ??
                (userData['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();

    final partnerRefs = <DocumentReference>[];
    if (partnerEmail.isNotEmpty) {
      final partnerQuery = await firestore
          .collection('users')
          .where('email', isEqualTo: partnerEmail)
          .get();
      partnerRefs.addAll(partnerQuery.docs.map((doc) => doc.reference));
    }

    final batch = firestore.batch();
    final currentFurnitureDocs = current.docs.where(
      (doc) => !kRoomThemes.containsKey(doc.id),
    );

    // Anything created after this snapshot did not exist yet, so remove it.
    for (final doc in currentFurnitureDocs) {
      if (!snapshot.documents.containsKey(doc.id)) {
        batch.delete(userRef.collection('furniture').doc(doc.id));
        for (final partnerRef in partnerRefs) {
          batch.delete(partnerRef.collection('furniture').doc(doc.id));
        }
      }
    }

    // Restore every furniture document exactly as it was before the action.
    for (final entry in snapshot.documents.entries) {
      batch.set(userRef.collection('furniture').doc(entry.key), entry.value);
      for (final partnerRef in partnerRefs) {
        batch.set(
          partnerRef.collection('furniture').doc(entry.key),
          entry.value,
        );
      }
    }

    await batch.commit();

    if (!mounted) return;
    setState(() {
      _latestFurnitureData = snapshot.documents.map(
        (key, value) => MapEntry(key, _cloneMap(value)),
      );

      final canReselect =
          snapshot.selectedDocId != null &&
          snapshot.documents.containsKey(snapshot.selectedDocId) &&
          !snapshot.locked;

      if (canReselect) {
        _editingDocId = snapshot.selectedDocId;
        _editingItemKey = snapshot.selectedItemKey;
        _editingCol = snapshot.col;
        _editingRow = snapshot.row;
        _editingVisualScale = snapshot.visualScale;
        _editingVisualRotation = snapshot.visualRotation;
        _editingFlipX = snapshot.flipX;
        _editingFlipY = snapshot.flipY;
        _editingLocked = snapshot.locked;
      } else {
        _clearSelection();
      }
    });

    _notifySelectionChanged(_editingDocId != null);
  }

  Future<void> _saveCurrentSelection(User user) async {
    if (_editingDocId == null || _editingCol == null || _editingRow == null) {
      return;
    }
    await _saveItemPosition(
      user,
      _editingDocId!,
      _editingCol!,
      _editingRow!,
      visualScale: _editingVisualScale,
      visualRotation: _editingVisualRotation,
      flipX: _editingFlipX,
      flipY: _editingFlipY,
      isLocked: _editingLocked,
    );
  }

  Future<void> _toggleItemLock(QueryDocumentSnapshot doc, User? user) async {
    if (user == null) return;

    final data = _docData(doc);
    final isSelected = _editingDocId == doc.id;
    final currentLocked = isSelected
        ? _editingLocked
        : ((data['isLocked'] as bool?) ?? false);
    final nextLocked = !currentLocked;

    // If this is the item currently being edited, save its LIVE edit state
    // together with the new lock state. This prevents a moved item from
    // snapping back to the last Firestore position when it is locked.
    if (isSelected && _editingCol != null && _editingRow != null) {
      await _saveItemPosition(
        user,
        doc.id,
        _editingCol!,
        _editingRow!,
        visualScale: _editingVisualScale,
        visualRotation: _editingVisualRotation,
        flipX: _editingFlipX,
        flipY: _editingFlipY,
        isLocked: nextLocked,
      );

      if (!mounted) return;
      if (nextLocked) {
        setState(_clearSelection);
      } else {
        setState(() => _editingLocked = false);
      }
      return;
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final userData = (await userRef.get()).data() ?? {};
    final partnerEmail =
        ((userData['partnerEmailLower'] as String?) ??
                (userData['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();
    final batch = FirebaseFirestore.instance.batch();
    final update = {'isLocked': nextLocked};

    batch.set(
      userRef.collection('furniture').doc(doc.id),
      update,
      SetOptions(merge: true),
    );

    if (partnerEmail.isNotEmpty) {
      final partnerQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: partnerEmail)
          .get();
      for (final partnerDoc in partnerQuery.docs) {
        batch.set(
          partnerDoc.reference.collection('furniture').doc(doc.id),
          update,
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final cs = widget.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final roomSize = Size(constraints.maxWidth, constraints.maxHeight);
        final perspective = _RoomPerspective(roomSize);

        return StreamBuilder<QuerySnapshot>(
          stream: user != null
              ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('furniture')
                    .snapshots()
              : null,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();

            final allDocs = snapshot.data!.docs;

            _latestFurnitureData = {
              for (final doc in allDocs)
                if (!kRoomThemes.containsKey(doc.id))
                  doc.id: _cloneMap(_docData(doc)),
            };

            final equippedDocs = allDocs.where((doc) {
              final data = _docData(doc);
              return data['isEquipped'] == true &&
                  !kRoomThemes.containsKey(doc.id);
            }).toList();

            equippedDocs.sort((a, b) {
              final aLoc = _docData(a)['location'] as Map<String, dynamic>?;
              final bLoc = _docData(b)['location'] as Map<String, dynamic>?;
              final aRow = (aLoc?['row'] as num?)?.toDouble() ?? 0.0;
              final bRow = (bLoc?['row'] as num?)?.toDouble() ?? 0.0;
              return aRow.compareTo(bRow);
            });

            if (!_wasEditing && widget.isEditing) {
              _undoHistory.clear();
              _lastUndoMergeKey = null;
              _lastUndoRecordAt = null;
            }

            if (_wasEditing && !widget.isEditing) {
              if (user != null) _saveCurrentSelection(user);
              _clearSelection();
              _undoHistory.clear();
              _lastUndoMergeKey = null;
              _lastUndoRecordAt = null;
            }
            _wasEditing = widget.isEditing;

            if (widget.isEditing &&
                _editingDocId != null &&
                !equippedDocs.any((doc) => doc.id == _editingDocId)) {
              _clearSelection();
            }

            final selectedDoc = _editingDocId == null
                ? null
                : equippedDocs
                      .where((doc) => doc.id == _editingDocId)
                      .firstOrNull;
            final activeSurface = selectedDoc == null
                ? RoomSurface.floor
                : getFurnitureMeta(_itemKeyForDoc(selectedDoc)).surface;

            return Stack(
              children: [
                if (widget.isEditing)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RoomGridPainter(activeSurface: activeSurface),
                    ),
                  ),

                if (widget.isEditing)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_editingDocId == null) return;
                        if (user != null) _saveCurrentSelection(user);
                        setState(_clearSelection);
                      },
                    ),
                  ),

                ...equippedDocs.map(
                  (doc) => _buildPlacedFurniture(
                    doc: doc,
                    user: user,
                    perspective: perspective,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPlacedFurniture({
    required QueryDocumentSnapshot doc,
    required User? user,
    required _RoomPerspective perspective,
  }) {
    final data = _docData(doc);
    final itemKey = _itemKeyForDoc(doc);
    final meta = getFurnitureMeta(itemKey);
    final surface = meta.surface;
    final locationMap = data['location'] as Map<String, dynamic>?;
    final defaultRow = surface == RoomSurface.floor ? 0.35 : 0.5;
    final savedCol = (locationMap?['col'] as num?)?.toDouble() ?? 0.5;
    final savedRow = (locationMap?['row'] as num?)?.toDouble() ?? defaultRow;
    final savedVisualScale =
        (data['visualScale'] as num?)?.toDouble() ??
        _visualScaleForFurniture(itemKey);
    final savedVisualRotation =
        (data['visualRotation'] as num?)?.toDouble() ??
        _visualRotationForFurniture(itemKey);
    final savedFlipX = (data['flipX'] as bool?) ?? false;
    final savedFlipY = (data['flipY'] as bool?) ?? false;
    final isLocked = (data['isLocked'] as bool?) ?? false;
    final isSelected = widget.isEditing && _editingDocId == doc.id;

    final rawCol = isSelected ? (_editingCol ?? savedCol) : savedCol;
    final rawRow = isSelected ? (_editingRow ?? savedRow) : savedRow;
    final col = surface == RoomSurface.floor
        ? rawCol
        : _clampFurnitureCol(itemKey, rawCol);
    final row = surface == RoomSurface.floor
        ? rawRow
        : _clampFurnitureRow(itemKey, rawRow);
    final visualScale = isSelected
        ? (_editingVisualScale ?? savedVisualScale)
        : savedVisualScale;
    final visualRotation = isSelected
        ? (_editingVisualRotation ?? savedVisualRotation)
        : savedVisualRotation;
    final flipX = isSelected ? _editingFlipX : savedFlipX;
    final flipY = isSelected ? _editingFlipY : savedFlipY;

    final squarePixels = _RoomCanvas.furnitureSquarePixels;
    final itemWidth = squarePixels * meta.widthSquares * visualScale;
    final itemHeight = squarePixels * meta.lengthSquares * visualScale;
    final isFloor = surface == RoomSurface.floor;

    late final _RoomPoint point;
    if (isFloor) {
      final gridX = _normalizedToGrid(col);
      final gridY = _normalizedToGrid(row);
      final footprint = perspective.floorFootprintBounds(
        gridX: gridX,
        gridY: gridY,
        widthSquares: meta.widthSquares,
        lengthSquares: meta.lengthSquares,
      );
      point = _RoomPoint(Offset(footprint.center.dx, footprint.bottom), 1.0);
    } else {
      point = perspective.pointFor(surface, col, row);
    }

    final left = point.anchor.dx - itemWidth / 2;
    final top = isFloor
        ? point.anchor.dy - itemHeight
        : point.anchor.dy - itemHeight / 2;

    return Positioned(
      key: ValueKey(doc.id),
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.isEditing && !isLocked
            ? () => _selectItem(doc, user)
            : null,
        onDoubleTap: widget.isEditing ? () => _toggleItemLock(doc, user) : null,
        onPanStart: widget.isEditing && !isLocked
            ? (details) {
                if (_editingDocId != doc.id) {
                  _selectItem(doc, user);
                }
                _accumulatedDragX = 0.0;
                _accumulatedDragY = 0.0;
                _lastDragGlobalPosition = details.globalPosition;
              }
            : null,
        onPanUpdate: widget.isEditing && !isLocked
            ? (details) {
                if (_editingDocId != doc.id) return;
                final previousPosition = _lastDragGlobalPosition;
                _lastDragGlobalPosition = details.globalPosition;
                if (previousPosition == null) return;
                _handleFurnitureDrag(
                  itemKey,
                  details.globalPosition - previousPosition,
                  perspective,
                );
              }
            : null,
        onPanEnd: widget.isEditing && !isLocked
            ? (_) {
                _accumulatedDragX = 0.0;
                _accumulatedDragY = 0.0;
                _lastDragGlobalPosition = null;
              }
            : null,
        child: SizedBox(
          width: itemWidth,
          height: itemHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scale(flipX ? -1.0 : 1.0, flipY ? -1.0 : 1.0),
                  child: Transform.rotate(
                    angle: visualRotation,
                    alignment: Alignment.bottomCenter,
                    child: Image.asset(meta.assetPath, fit: BoxFit.contain),
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  top: -14,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: widget.colorScheme.primary,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: widget.colorScheme.surface,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: widget.colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Selected',
                              style: TextStyle(
                                color: widget.colorScheme.onPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.isEditing && isLocked)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: widget.colorScheme.primary.withValues(
                            alpha: 0.94,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.colorScheme.surface,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 22,
                          color: widget.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addItem(User user, String itemKey, String category) async {
    await _saveCurrentSelection(user);

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    final userData = userDoc.data() ?? {};
    final partnerEmail =
        ((userData['partnerEmailLower'] as String?) ??
                (userData['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();

    final meta = getFurnitureMeta(itemKey);
    final instanceId =
        'placed_${DateTime.now().microsecondsSinceEpoch}_${itemKey.replaceAll('/', '_')}';
    final defaultLocation = {
      'col': 0.5,
      'row': meta.surface == RoomSurface.floor ? 0.35 : 0.5,
    };
    final itemData = <String, dynamic>{
      'type': 'furnitureInstance',
      'itemKey': itemKey,
      'isEquipped': true,
      'category': category,
      'location': defaultLocation,
      'visualScale': _visualScaleForFurniture(itemKey),
      'visualRotation': _visualRotationForFurniture(itemKey),
      'flipX': false,
      'flipY': false,
      'isLocked': false,
    };

    final batch = firestore.batch();
    batch.set(userRef.collection('furniture').doc(instanceId), itemData);

    if (partnerEmail.isNotEmpty) {
      final partnerQuery = await firestore
          .collection('users')
          .where('email', isEqualTo: partnerEmail)
          .get();
      for (final pDoc in partnerQuery.docs) {
        batch.set(
          pDoc.reference.collection('furniture').doc(instanceId),
          itemData,
        );
      }
    }

    await batch.commit();

    if (!mounted) return;
    final scale = _visualScaleForFurniture(itemKey);
    final rotation = _visualRotationForFurniture(itemKey);
    final col = 0.5;
    final row = meta.surface == RoomSurface.floor ? 0.35 : 0.5;

    setState(() {
      _editingDocId = instanceId;
      _editingItemKey = itemKey;
      _editingCol = col;
      _editingRow = row;
      _editingVisualScale = scale;
      _editingVisualRotation = rotation;
      _editingFlipX = false;
      _editingFlipY = false;

      _initialCol = col;
      _initialRow = row;
      _initialVisualScale = scale;
      _initialVisualRotation = rotation;
      _initialFlipX = false;
      _initialFlipY = false;
    });
    _notifySelectionChanged(true);
  }

  Future<void> _removeSelectedItem(
    User user,
    List<QueryDocumentSnapshot> allDocs,
  ) async {
    final selectedId = _editingDocId;
    if (selectedId == null) return;

    QueryDocumentSnapshot? selectedDoc;
    for (final doc in allDocs) {
      if (doc.id == selectedId) {
        selectedDoc = doc;
        break;
      }
    }
    if (selectedDoc == null) return;

    final selectedData = _docData(selectedDoc);
    final isInstance =
        selectedData['type'] == 'furnitureInstance' ||
        selectedData.containsKey('itemKey');

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    final userData = userDoc.data() ?? {};
    final partnerEmail =
        ((userData['partnerEmailLower'] as String?) ??
                (userData['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();

    final targets = <DocumentReference>[
      userRef.collection('furniture').doc(selectedId),
    ];
    if (partnerEmail.isNotEmpty) {
      final partnerQuery = await firestore
          .collection('users')
          .where('email', isEqualTo: partnerEmail)
          .get();
      targets.addAll(
        partnerQuery.docs.map(
          (doc) => doc.reference.collection('furniture').doc(selectedId),
        ),
      );
    }

    final batch = firestore.batch();
    for (final ref in targets) {
      if (isInstance) {
        batch.delete(ref);
      } else {
        batch.set(ref, {'isEquipped': false}, SetOptions(merge: true));
      }
    }
    await batch.commit();

    if (!mounted) return;
    setState(_clearSelection);
  }

  double _clampFurnitureCol(String itemKey, double col) {
    final meta = getFurnitureMeta(itemKey);
    final maxGridX = (_RoomGeometry.floorColumns - meta.widthSquares).clamp(
      0,
      _RoomGeometry.floorColumns,
    );
    return _gridToNormalized(_normalizedToGrid(col).clamp(0, maxGridX));
  }

  double _clampFurnitureRow(String itemKey, double row) {
    final meta = getFurnitureMeta(itemKey);
    final maxGridY = (_RoomGeometry.floorColumns - meta.lengthSquares).clamp(
      0,
      _RoomGeometry.floorColumns,
    );
    return _gridToNormalized(_normalizedToGrid(row).clamp(0, maxGridY));
  }

  int _normalizedToGrid(double value) {
    return (value * _RoomGeometry.floorColumns).round();
  }

  double _gridToNormalized(int value) {
    return value / _RoomGeometry.floorColumns;
  }

  void _handleFurnitureDrag(
    String itemKey,
    Offset delta,
    _RoomPerspective perspective,
  ) {
    if (_editingCol == null || _editingRow == null) return;

    final meta = getFurnitureMeta(itemKey);
    final currentGridX = _normalizedToGrid(_editingCol!);
    final currentGridY = _normalizedToGrid(_editingRow!);

    // Evaluate screen-space span of a full grid step across perspective space
    final p0 = perspective.floorGridIntersection(
      currentGridX.toDouble(),
      currentGridY.toDouble(),
    );
    final px = perspective.floorGridIntersection(
      (currentGridX + 1.0).toDouble(),
      currentGridY.toDouble(),
    );
    final py = perspective.floorGridIntersection(
      currentGridX.toDouble(),
      (currentGridY + 1.0).toDouble(),
    );

    final stepX = (px - p0);
    final stepY = (py - p0);

    final det = stepX.dx * stepY.dy - stepX.dy * stepY.dx;
    if (det.abs() < 0.0001) return;

    final canvasDelta = delta / widget.canvasScale;
    _accumulatedDragX += canvasDelta.dx;
    _accumulatedDragY += canvasDelta.dy;

    final dGridX =
        (_accumulatedDragX * stepY.dy - _accumulatedDragY * stepY.dx) / det;
    final dGridY =
        (stepX.dx * _accumulatedDragY - stepX.dy * _accumulatedDragX) / det;

    if (dGridX.abs() >= 0.5 || dGridY.abs() >= 0.5) {
      final stepMoveX = dGridX.sign * dGridX.abs().floor();
      final stepMoveY = dGridY.sign * dGridY.abs().floor();

      if (stepMoveX != 0 || stepMoveY != 0) {
        final isFloor = meta.surface == RoomSurface.floor;
        final gridLimit = isFloor
            ? _RoomGeometry.floorGridDepth
            : _RoomGeometry.floorColumns;

        final maxGridX = isFloor
            ? gridLimit
            : (gridLimit - meta.widthSquares).clamp(0, gridLimit);
        final maxGridY = isFloor
            ? gridLimit
            : (gridLimit - meta.lengthSquares).clamp(0, gridLimit);

        final targetGridX = (currentGridX + stepMoveX)
            .clamp(0, maxGridX)
            .toInt();
        final targetGridY = (currentGridY + stepMoveY)
            .clamp(0, maxGridY)
            .toInt();

        final targetFits =
            !isFloor ||
            perspective.floorFootprintFits(
              gridX: targetGridX,
              gridY: targetGridY,
              widthSquares: meta.widthSquares,
              lengthSquares: meta.lengthSquares,
              visualScale: _editingVisualScale ?? 1.0,
            );

        if (targetFits &&
            (targetGridX != currentGridX || targetGridY != currentGridY)) {
          setState(() {
            _editingCol = _gridToNormalized(targetGridX);
            _editingRow = _gridToNormalized(targetGridY);
            _accumulatedDragX = 0.0;
            _accumulatedDragY = 0.0;
          });
        }
      }
    }
  }

  Future<void> _saveItemPosition(
    User user,
    String instanceDocId,
    double col,
    double row, {
    double? visualScale,
    double? visualRotation,
    bool? flipX,
    bool? flipY,
    bool? isLocked,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    final data = userDoc.data() ?? {};
    final partnerEmail =
        ((data['partnerEmailLower'] as String?) ??
                (data['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();

    final updateData = <String, dynamic>{
      'location': {'col': col, 'row': row},
      if (visualScale != null) 'visualScale': visualScale,
      if (visualRotation != null) 'visualRotation': visualRotation,
      if (flipX != null) 'flipX': flipX,
      if (flipY != null) 'flipY': flipY,
      if (isLocked != null) 'isLocked': isLocked,
    };

    final batch = firestore.batch();
    batch.set(
      userRef.collection('furniture').doc(instanceDocId),
      updateData,
      SetOptions(merge: true),
    );

    if (partnerEmail.isNotEmpty) {
      final partnerQuery = await firestore
          .collection('users')
          .where('email', isEqualTo: partnerEmail)
          .get();
      for (final doc in partnerQuery.docs) {
        batch.set(
          doc.reference.collection('furniture').doc(instanceDocId),
          updateData,
          SetOptions(merge: true),
        );
      }
    }

    await batch.commit();
  }
}

class _RoomGridPainter extends CustomPainter {
  final RoomSurface activeSurface;

  const _RoomGridPainter({required this.activeSurface});

  @override
  void paint(Canvas canvas, Size size) {
    _paintLeftWall(canvas, size, activeSurface == RoomSurface.leftWall);
    _paintRightWall(canvas, size, activeSurface == RoomSurface.rightWall);
    _paintFloor(canvas, size, activeSurface == RoomSurface.floor);
  }

  Paint _gridPaint(bool active) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = active ? 2.30 : 1.70
    ..color = Colors.black.withValues(alpha: active ? 0.34 : 0.20);

  Rect _roomRect(Size size) => Offset.zero & size;

  Offset _p(Size size, double x, double y) {
    final r = _roomRect(size);
    return Offset(r.left + r.width * x, r.top + r.height * y);
  }

  Path _leftWallPath(Size size) {
    final a = _p(size, _RoomGeometry.centerX, _RoomGeometry.ceilingCenterY);
    final b = _p(size, _RoomGeometry.leftX, _RoomGeometry.ceilingLeftEdgeY);
    final c = _p(size, _RoomGeometry.leftX, _RoomGeometry.floorLeftEdgeY);
    final d = _p(size, _RoomGeometry.centerX, _RoomGeometry.floorCornerY);

    return Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..lineTo(d.dx, d.dy)
      ..close();
  }

  Path _rightWallPath(Size size) {
    final a = _p(size, _RoomGeometry.centerX, _RoomGeometry.ceilingCenterY);
    final b = _p(size, _RoomGeometry.rightX, _RoomGeometry.ceilingRightEdgeY);
    final c = _p(size, _RoomGeometry.rightX, _RoomGeometry.floorRightEdgeY);
    final d = _p(size, _RoomGeometry.centerX, _RoomGeometry.floorCornerY);

    return Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..lineTo(d.dx, d.dy)
      ..close();
  }

  Path _floorPath(Size size) {
    final r = _roomRect(size);
    final left = _p(size, _RoomGeometry.leftX, _RoomGeometry.floorLeftEdgeY);
    final corner = _p(size, _RoomGeometry.centerX, _RoomGeometry.floorCornerY);
    final right = _p(size, _RoomGeometry.rightX, _RoomGeometry.floorRightEdgeY);
    final bottomRight = Offset(
      r.left + r.width * _RoomGeometry.rightX,
      r.bottom,
    );
    final bottomLeft = Offset(r.left + r.width * _RoomGeometry.leftX, r.bottom);

    return Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(corner.dx, corner.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();
  }

  void _paintLeftWall(Canvas canvas, Size size, bool active) {
    final paint = _gridPaint(active);
    canvas.save();
    canvas.clipPath(_leftWallPath(size));

    for (int i = 1; i < _RoomGeometry.wallColumns; i++) {
      final t = i / _RoomGeometry.wallColumns;
      final top = Offset.lerp(
        _p(size, _RoomGeometry.centerX, _RoomGeometry.ceilingCenterY),
        _p(size, _RoomGeometry.leftX, _RoomGeometry.ceilingLeftEdgeY),
        t,
      )!;
      final bottom = Offset.lerp(
        _p(size, _RoomGeometry.centerX, _RoomGeometry.floorCornerY),
        _p(size, _RoomGeometry.leftX, _RoomGeometry.floorLeftEdgeY),
        t,
      )!;
      canvas.drawLine(top, bottom, paint);
    }

    for (int j = 1; j < _RoomGeometry.wallRows; j++) {
      final t = j / _RoomGeometry.wallRows;
      final inner = Offset.lerp(
        _p(size, _RoomGeometry.centerX, _RoomGeometry.ceilingCenterY),
        _p(size, _RoomGeometry.centerX, _RoomGeometry.floorCornerY),
        t,
      )!;
      final outer = Offset.lerp(
        _p(size, _RoomGeometry.leftX, _RoomGeometry.ceilingLeftEdgeY),
        _p(size, _RoomGeometry.leftX, _RoomGeometry.floorLeftEdgeY),
        t,
      )!;
      canvas.drawLine(inner, outer, paint);
    }
    canvas.restore();
  }

  void _paintRightWall(Canvas canvas, Size size, bool active) {
    final paint = _gridPaint(active);
    canvas.save();
    canvas.clipPath(_rightWallPath(size));

    for (int i = 1; i < _RoomGeometry.wallColumns; i++) {
      final t = i / _RoomGeometry.wallColumns;
      final top = Offset.lerp(
        _p(size, _RoomGeometry.centerX, _RoomGeometry.ceilingCenterY),
        _p(size, _RoomGeometry.rightX, _RoomGeometry.ceilingRightEdgeY),
        t,
      )!;
      final bottom = Offset.lerp(
        _p(size, _RoomGeometry.centerX, _RoomGeometry.floorCornerY),
        _p(size, _RoomGeometry.rightX, _RoomGeometry.floorRightEdgeY),
        t,
      )!;
      canvas.drawLine(top, bottom, paint);
    }

    for (int j = 1; j < _RoomGeometry.wallRows; j++) {
      final t = j / _RoomGeometry.wallRows;
      final inner = Offset.lerp(
        _p(size, _RoomGeometry.centerX, _RoomGeometry.ceilingCenterY),
        _p(size, _RoomGeometry.centerX, _RoomGeometry.floorCornerY),
        t,
      )!;
      final outer = Offset.lerp(
        _p(size, _RoomGeometry.rightX, _RoomGeometry.ceilingRightEdgeY),
        _p(size, _RoomGeometry.rightX, _RoomGeometry.floorRightEdgeY),
        t,
      )!;
      canvas.drawLine(inner, outer, paint);
    }
    canvas.restore();
  }

  void _paintFloor(Canvas canvas, Size size, bool active) {
    final paint = _gridPaint(active);
    final room = _roomRect(size);
    canvas.save();
    canvas.clipPath(_floorPath(size));

    final corner = _p(size, _RoomGeometry.centerX, _RoomGeometry.floorCornerY);
    final leftEdge = _p(
      size,
      _RoomGeometry.leftX,
      _RoomGeometry.floorLeftEdgeY,
    );
    final rightEdge = _p(
      size,
      _RoomGeometry.rightX,
      _RoomGeometry.floorRightEdgeY,
    );

    final leftSeamSlope = (leftEdge.dy - corner.dy) / (leftEdge.dx - corner.dx);
    final rightSeamSlope =
        (rightEdge.dy - corner.dy) / (rightEdge.dx - corner.dx);

    const int floorOverflowLines = 24;

    for (
      int i = -floorOverflowLines;
      i <= _RoomGeometry.floorColumns + floorOverflowLines;
      i++
    ) {
      final t = i / _RoomGeometry.floorColumns;
      final start = Offset.lerp(corner, leftEdge, t)!;
      final remainingY = room.bottom - start.dy;
      final dx = rightSeamSlope.abs() < 0.0001
          ? room.width
          : remainingY / rightSeamSlope.abs();
      canvas.drawLine(start, Offset(start.dx + dx, room.bottom), paint);
    }

    for (
      int i = -floorOverflowLines;
      i <= _RoomGeometry.floorColumns + floorOverflowLines;
      i++
    ) {
      final t = i / _RoomGeometry.floorColumns;
      final start = Offset.lerp(corner, rightEdge, t)!;
      final remainingY = room.bottom - start.dy;
      final dx = leftSeamSlope.abs() < 0.0001
          ? room.width
          : remainingY / leftSeamSlope.abs();
      canvas.drawLine(start, Offset(start.dx - dx, room.bottom), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RoomGridPainter oldDelegate) {
    return oldDelegate.activeSurface != activeSurface;
  }
}

class _StatPill extends StatelessWidget {
  final ColorScheme cs;
  final IconData icon;
  final Color tint;
  final String label;

  const _StatPill({
    required this.cs,
    required this.icon,
    required this.tint,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _FurnitureInventorySheet extends StatefulWidget {
  final ColorScheme cs;
  final VoidCallback? onEditModeRequested;
  final String selectedRoomTheme;
  final ValueChanged<String>? onRoomThemeChanged;

  const _FurnitureInventorySheet({
    required this.cs,
    required this.selectedRoomTheme,
    this.onRoomThemeChanged,
    this.onEditModeRequested,
  });

  @override
  State<_FurnitureInventorySheet> createState() =>
      _FurnitureInventorySheetState();
}

class _FurnitureInventorySheetState extends State<_FurnitureInventorySheet> {
  String _selectedCategory = 'Rooms';

  final List<String> _categories = [
    'Rooms',
    'Sofas',
    'Beds',
    'Desks',
    'Rugs',
    'Decor',
  ];

  String _getItemTitle(String category, String variantKey) {
    final formatted = variantKey.replaceAll('_', ' ');
    final capitalized = formatted.isEmpty
        ? ''
        : formatted[0].toUpperCase() + formatted.substring(1);

    switch (category.toLowerCase()) {
      case 'sofas':
        switch (variantKey) {
          case 'green':
            return 'Fern Sofa';
          case 'blue':
            return 'Sky Sofa';
          case 'brown':
            return 'Sand Sofa';
          case 'grey':
            return 'Slate Sofa';
          default:
            return '$capitalized Sofa';
        }
      case 'beds':
        return '$capitalized Bed';
      case 'desks':
        return '$capitalized Desk';
      case 'rugs':
        return '$capitalized Rug';
      case 'decor':
        return capitalized;
      default:
        return capitalized;
    }
  }

  Map<String, String> _getAssetsForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'sofas':
        return kSofaAssets;
      case 'beds':
        return kBedAssets;
      case 'desks':
        return kDeskAssets;
      case 'rugs':
        return kRugAssets;
      case 'decor':
        return kDecorAssets;
      default:
        return {};
    }
  }

  Future<void> _addPlacedItem(
    User user,
    String itemKey,
    String category,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    final userData = userDoc.data() ?? {};
    final partnerEmail =
        ((userData['partnerEmailLower'] as String?) ??
                (userData['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();

    final meta = getFurnitureMeta(itemKey);
    final instanceId =
        'placed_${DateTime.now().microsecondsSinceEpoch}_${itemKey.replaceAll('/', '_')}';
    final itemData = <String, dynamic>{
      'type': 'furnitureInstance',
      'itemKey': itemKey,
      'isEquipped': true,
      'category': category,
      'location': {
        'col': 0.5,
        'row': meta.surface == RoomSurface.floor ? 0.35 : 0.5,
      },
      'flipX': false,
      'flipY': false,
    };

    final batch = firestore.batch();
    batch.set(userRef.collection('furniture').doc(instanceId), itemData);

    if (partnerEmail.isNotEmpty) {
      final partnerQuery = await firestore
          .collection('users')
          .where('email', isEqualTo: partnerEmail)
          .get();
      for (final pDoc in partnerQuery.docs) {
        batch.set(
          pDoc.reference.collection('furniture').doc(instanceId),
          itemData,
        );
      }
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final cs = widget.cs;
    final cardBackgroundColor = cs.surfaceContainerHighest;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.fromLTRB(
        12,
        16,
        12,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.chair_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 10),
                Text(
                  'Furniture Inventory',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.edit_rounded, color: cs.primary, size: 22),
                  tooltip: 'Edit Layout',
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onEditModeRequested?.call();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: cs.onSurface.withValues(alpha: 0.05)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final activeIndex = _categories.indexOf(_selectedCategory);
                  final tabWidth =
                      (constraints.maxWidth - 4) / _categories.length;

                  return Stack(
                    children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.fastOutSlowIn,
                        alignment: Alignment(
                          -1.0 + (2.0 / (_categories.length - 1)) * activeIndex,
                          0,
                        ),
                        child: Container(
                          width: tabWidth,
                          height: 38,
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.15),
                                blurRadius: 10,
                                spreadRadius: 1,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: _categories.map((category) {
                          final active = category == _selectedCategory;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCategory = category),
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                height: 38,
                                child: Center(
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: active
                                          ? FontWeight.w500
                                          : FontWeight.w300,
                                      color: active
                                          ? cs.onSurface
                                          : cs.onSurfaceVariant.withValues(
                                              alpha: 0.8,
                                            ),
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: user == null
                  ? const SizedBox()
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('furniture')
                          .snapshots(),
                      builder: (context, furnitureSnapshot) {
                        if (!furnitureSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = furnitureSnapshot.data!.docs;
                        final isRoomCategory =
                            _selectedCategory.toLowerCase() == 'rooms';

                        if (isRoomCategory) {
                          final roomEntries = kRoomThemes.entries.toList();

                          return GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1.15,
                                ),
                            itemCount: roomEntries.length,
                            itemBuilder: (context, index) {
                              final entry = roomEntries[index];
                              final key = entry.key;
                              final theme = entry.value;
                              final roomDoc = docs
                                  .where((doc) => doc.id == key)
                                  .firstOrNull;
                              final roomData =
                                  roomDoc?.data() as Map<String, dynamic>?;
                              final selected =
                                  roomData?['isEquipped'] == true ||
                                  (roomDoc == null &&
                                      widget.selectedRoomTheme == key);

                              return GestureDetector(
                                onTap: () {
                                  widget.onRoomThemeChanged?.call(key);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: selected
                                          ? cs.primary
                                          : cs.outlineVariant,
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: CustomPaint(
                                            painter: _RoomBackgroundPainter(
                                              theme: theme,
                                            ),
                                            child: const SizedBox.expand(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              theme.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          if (selected)
                                            Icon(
                                              Icons.check_circle_rounded,
                                              size: 17,
                                              color: cs.primary,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }

                        final categoryAssets = _getAssetsForCategory(
                          _selectedCategory,
                        );
                        final prefix =
                            _selectedCategory.toLowerCase() == 'sofas'
                            ? 'sofa_'
                            : (_selectedCategory.toLowerCase() == 'beds'
                                  ? 'bed_'
                                  : (_selectedCategory.toLowerCase() == 'desks'
                                        ? 'desk_'
                                        : (_selectedCategory.toLowerCase() ==
                                                  'rugs'
                                              ? 'carpet_'
                                              : '')));

                        List<Map<String, dynamic>> catalogItems = [];

                        categoryAssets.forEach((variantKey, assetPath) {
                          final itemKey = prefix.isNotEmpty
                              ? '$prefix$variantKey'
                              : variantKey;

                          int placedCount = 0;
                          for (final doc in docs) {
                            if (kRoomThemes.containsKey(doc.id)) continue;
                            final data =
                                (doc.data() as Map<String, dynamic>?) ??
                                const {};
                            final storedItemKey =
                                (data['itemKey'] as String?) ?? doc.id;
                            if (storedItemKey == itemKey &&
                                data['isEquipped'] == true) {
                              placedCount++;
                            }
                          }

                          catalogItems.add({
                            'itemKey': itemKey,
                            'variantKey': variantKey,
                            'assetPath': assetPath,
                            'placedCount': placedCount,
                          });
                        });

                        if (catalogItems.isEmpty) {
                          return Center(
                            child: Text(
                              'No items available in $_selectedCategory.',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }

                        return GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.0,
                              ),
                          itemCount: catalogItems.length,
                          itemBuilder: (context, index) {
                            final itemInfo = catalogItems[index];
                            final itemKey = itemInfo['itemKey'] as String;
                            final variantKey = itemInfo['variantKey'] as String;
                            final assetPath = itemInfo['assetPath'] as String;
                            final placedCount = itemInfo['placedCount'] as int;
                            final itemTitle = _getItemTitle(
                              _selectedCategory,
                              variantKey,
                            );

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: user == null
                                    ? null
                                    : () => _addPlacedItem(
                                        user,
                                        itemKey,
                                        _selectedCategory,
                                      ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: placedCount > 0
                                          ? cs.primary.withValues(alpha: 0.7)
                                          : cs.outlineVariant,
                                      width: placedCount > 0 ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Container(
                                                color: cs
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.3),
                                                child: const SizedBox.expand(),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  6.0,
                                                ),
                                                child: Image.asset(
                                                  assetPath,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                              Positioned(
                                                right: 6,
                                                top: 6,
                                                child: Container(
                                                  width: 28,
                                                  height: 28,
                                                  decoration: BoxDecoration(
                                                    color: cs.primary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.add_rounded,
                                                    size: 19,
                                                    color: cs.onPrimary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              itemTitle,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (placedCount > 0)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: cs.primary.withValues(
                                                  alpha: 0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                              ),
                                              child: Text(
                                                '×$placedCount',
                                                style: TextStyle(
                                                  color: cs.primary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
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
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final ColorScheme cs;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final List<Color>? gradientColors;
  final Color? glowColor;

  const _GlassCard({
    required this.child,
    required this.cs,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.gradientColors,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final glow = glowColor ?? cs.primary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.07),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: glow.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    gradientColors ??
                    [
                      cs.surface.withValues(alpha: 0.55),
                      cs.primaryContainer.withValues(alpha: 0.35),
                    ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TipLoading extends StatelessWidget {
  final ColorScheme cs;
  const _TipLoading({super.key, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 10),
            Text(
              'Daily inspiration',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.0,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Fetching your tip...',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

class _TipLoaded extends StatelessWidget {
  final ColorScheme cs;
  final String tipText;
  const _TipLoaded({super.key, required this.cs, required this.tipText});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 10),
            Text(
              'Daily inspiration',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.0,
                color: cs.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              splashRadius: 18,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '\u201C',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                height: 0.8,
                color: cs.primary,
                fontFamily: 'CormorantGaramond',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tipText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  fontFamily: 'CormorantGaramond',
                  fontSize: 18,
                  height: 1.65,
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '\u201D',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              height: 0.8,
              color: cs.primary,
              fontFamily: 'CormorantGaramond',
            ),
          ),
        ),
      ],
    );
  }
}

class _Reveal extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final Offset beginOffset;
  final double beginScale;

  const _Reveal({
    required this.animation,
    required this.child,
    this.beginOffset = const Offset(0, 0.06),
    this.beginScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(
              beginOffset.dx * 60 * (1 - t),
              beginOffset.dy * 60 * (1 - t),
            ),
            child: Transform.scale(
              scale: beginScale + (1 - beginScale) * t,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _CharacterSprite extends StatelessWidget {
  final String source;
  final String fallbackEmoji;
  final List<String> equippedAccessories;

  const _CharacterSprite({
    super.key,
    required this.source,
    this.fallbackEmoji = '🐱',
    this.equippedAccessories = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isSpriteSheet = source.endsWith('.png');

    final matchingOption =
        _kCompanions.cast<_CompanionOption?>().firstWhere(
          (c) => c?.assetPath == source,
          orElse: () => _kCompanions.first,
        ) ??
        _kCompanions.first;

    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: isSpriteSheet
                ? Center(
                    child: Transform.scale(
                      scale: matchingOption.frameWidth == 64.0
                          ? 1.8
                          : (matchingOption.frameWidth == 16.0 ? 4.5 : 3.0),
                      child: SpriteAnimator(
                        imagePath: source,
                        totalFrames: matchingOption.totalFrames,
                        displayWidth: matchingOption.frameWidth,
                        displayHeight: matchingOption.frameHeight,
                        duration: const Duration(milliseconds: 800),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      fallbackEmoji,
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
          ),
          if (equippedAccessories.contains('cloud_blanket'))
            Positioned(
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text('☁️', style: TextStyle(fontSize: 12)),
              ),
            ),
          if (equippedAccessories.contains('moon_halo'))
            Positioned(
              top: 10,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                child: const Text('🌙', style: TextStyle(fontSize: 14)),
              ),
            ),
          if (equippedAccessories.contains('star_collar'))
            const Positioned(
              bottom: 18,
              child: Text('✨', style: TextStyle(fontSize: 13)),
            ),
          if (equippedAccessories.contains('heart_tag'))
            const Positioned(
              bottom: 8,
              child: Text('💗', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
