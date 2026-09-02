// lib/tabs/home_page.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../gemini_service.dart';
import '../widgets/sprite_animator.dart';

// ─────────────────────────────────────────────────────────────────────────
// Room background asset.
// ─────────────────────────────────────────────────────────────────────────
const String kRoomBackgroundAsset = 'assets/images/room_bg.png';

// How far up from the bottom of the screen the pet sits on the floor.
const double kPetFloorOffset = 16.0;

const Map<String, String> _kRoomBackgrounds = {
  'room_bg': 'assets/images/room_bg.png',
  'room_bg2': 'assets/images/room_bg2.png',
};

// Sofa asset variant map
const Map<String, String> _kSofaAssets = {
  'brown': 'assets/images/furniture/sofa_brown.png',
  'green': 'assets/images/furniture/sofa_green.png',
  'grey': 'assets/images/furniture/sofa_grey.png',
  'blue': 'assets/images/furniture/sofa_blue.png',
};

// Companion option helper to support dynamic frame counts per sprite sheet
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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _flicker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
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

  void _showFurnitureInventory(BuildContext context, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      isScrollControlled: true,
      builder: (sheetContext) => _FurnitureInventorySheet(cs: cs),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = FirebaseAuth.instance.currentUser;
    final cs = Theme.of(context).colorScheme;
    final firstName = user?.displayName?.split(' ').first ?? 'there';
    final cardBackgroundColor = cs.surfaceContainerHighest;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Room background ────────────────────────────────────────────
        Positioned.fill(
          child: StreamBuilder<QuerySnapshot>(
            stream: user != null
                ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('furniture')
                      .where('isEquipped', isEqualTo: true)
                      .snapshots()
                : null,
            builder: (context, snapshot) {
              var roomAsset = kRoomBackgroundAsset;
              if (snapshot.hasData) {
                for (final doc in snapshot.data!.docs) {
                  if (_kRoomBackgrounds.containsKey(doc.id)) {
                    roomAsset = _kRoomBackgrounds[doc.id]!;
                    break;
                  }
                }
              }

              return Transform.scale(
                scale: 1.18,
                alignment: const Alignment(0, 0.18),
                child: Image.asset(
                  roomAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            cs.primaryContainer.withValues(alpha: 0.6),
                            cs.surface,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),

        // ── Room Furniture (Sofa) ─────────────────────────────────────
        Positioned(
          left: 50,
          bottom: kPetFloorOffset + 75,
          child: const _RoomFurniture(),
        ),

        // ── Foreground layout ──────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Reveal(
                  animation: _seg(0.0, 0.45),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBackgroundColor.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.shadow.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hello Greeting
                        RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.displayMedium,
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
                        const SizedBox(height: 14),

                        // Tip of the Day Button with Sparkle Icon at front
                        Material(
                          color: cs.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => _showTipSheet(context, cs),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 18,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(width: 10),
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
                                    size: 18,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Heart and Fire stats as rounded rectangle pills
                        Row(
                          children: [
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: user != null
                                    ? FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(user.uid)
                                          .collection('matched_suggestions')
                                          .snapshots()
                                    : null,
                                builder: (context, snapshot) {
                                  final count = snapshot.data?.docs.length ?? 0;
                                  return _StatPill(
                                    cs: cs,
                                    icon: Icons.favorite_rounded,
                                    tint: cs.primary,
                                    label: '$count matches',
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
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
                                      (data?['sharedStreakCurrent'] as int?) ??
                                      (data?['streakCurrent'] as int?) ??
                                      0;
                                  return _StatPill(
                                    cs: cs,
                                    icon: Icons.local_fire_department_rounded,
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
              ],
            ),
          ),
        ),

        // ── Companion, sitting cleanly on the floor ────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: kPetFloorOffset,
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
                  final data = snapshot.data?.data() as Map<String, dynamic>?;

                  final companionSource =
                      (data?['companionAsset'] as String?) ??
                      (data?['companionLottie'] as String?) ??
                      'assets/images/cat.png';

                  final companionEmoji =
                      (data?['companionEmoji'] as String?) ?? '🐱';

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

        // ── Furniture Inventory Button (Bottom Right) ──────────────────
        Positioned(
          right: 24,
          bottom: kPetFloorOffset + 20,
          child: _Reveal(
            animation: _seg(0.3, 0.8),
            child: Material(
              color: cs.surface.withValues(alpha: 0.85),
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _showFurnitureInventory(context, cs),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Icon(
                    Icons.chair_alt_rounded,
                    color: cs.primary,
                    size: 24,
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

// ── Room Furniture Widget ─────────────────────────────────────────────────

class _RoomFurniture extends StatelessWidget {
  const _RoomFurniture();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: user != null
          ? FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('furniture')
                .where('isEquipped', isEqualTo: true)
                .snapshots()
          : null,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SizedBox(
            width: 90,
            height: 90,
            child: Image.asset(
              'assets/images/furniture/sofa_brown.png',
              fit: BoxFit.contain,
            ),
          );
        }

        String variantKey = 'brown';
        for (final doc in snapshot.data!.docs) {
          if (doc.id.startsWith('sofa_')) {
            variantKey = doc.id.contains('_')
                ? doc.id.split('_').last
                : 'brown';
            break;
          }
        }
        final assetPath =
            _kSofaAssets[variantKey] ??
            'assets/images/furniture/sofa_brown.png';

        return SizedBox(
          width: 90,
          height: 90,
          child: Image.asset(
            assetPath,
            width: 90,
            height: 90,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }
}

// ── Stat Pill Widget ──────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 8),
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

// ── Furniture Inventory Sheet with Theme Beige Style & Sliding Toggle ─────

class _FurnitureInventorySheet extends StatefulWidget {
  final ColorScheme cs;

  const _FurnitureInventorySheet({required this.cs});

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final cs = widget.cs;
    final cardBackgroundColor = cs.surfaceContainerHighest;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
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
              ],
            ),
            const SizedBox(height: 16),
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
                          final roomKeys = _kRoomBackgrounds.keys.toList();

                          final hasEquippedRoom = docs.any((doc) {
                            if (!_kRoomBackgrounds.containsKey(doc.id)) {
                              return false;
                            }
                            final data = doc.data() as Map<String, dynamic>?;
                            return data?['isEquipped'] == true;
                          });

                          return GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1.5,
                                ),
                            itemCount: roomKeys.length,
                            itemBuilder: (context, index) {
                              final roomKey = roomKeys[index];

                              final roomDoc = docs
                                  .where((d) => d.id == roomKey)
                                  .firstOrNull;
                              final roomData =
                                  roomDoc?.data() as Map<String, dynamic>?;
                              final isEquippedExplicitly =
                                  roomData?['isEquipped'] == true;

                              final actuallyEquipped =
                                  isEquippedExplicitly ||
                                  (roomKey == 'room_bg' && !hasEquippedRoom);

                              return GestureDetector(
                                onTap: () async {
                                  if (!actuallyEquipped &&
                                      user != null &&
                                      user.email != null) {
                                    final firestore =
                                        FirebaseFirestore.instance;
                                    final userDoc = await firestore
                                        .collection('users')
                                        .doc(user.uid)
                                        .get();
                                    final data = userDoc.data() ?? {};
                                    final partnerEmail =
                                        ((data['partnerEmailLower']
                                                    as String?) ??
                                                (data['partnerEmail']
                                                    as String?) ??
                                                '')
                                            .trim()
                                            .toLowerCase();

                                    final userQuery = await firestore
                                        .collection('users')
                                        .where('email', isEqualTo: user.email)
                                        .get();
                                    final partnerQuery = partnerEmail.isNotEmpty
                                        ? await firestore
                                              .collection('users')
                                              .where(
                                                'email',
                                                isEqualTo: partnerEmail,
                                              )
                                              .get()
                                        : null;

                                    final batch = firestore.batch();

                                    Future<void> updateRoomSubcollection(
                                      DocumentReference userRef,
                                    ) async {
                                      final furnitureRef = userRef.collection(
                                        'furniture',
                                      );
                                      final furnitureDocs = await furnitureRef
                                          .get();

                                      for (final fDoc in furnitureDocs.docs) {
                                        if (_kRoomBackgrounds.containsKey(
                                          fDoc.id,
                                        )) {
                                          batch.update(fDoc.reference, {
                                            'isEquipped': false,
                                          });
                                        }
                                      }

                                      batch.set(
                                        furnitureRef.doc(roomKey),
                                        {'isEquipped': true},
                                        SetOptions(merge: true),
                                      );
                                    }

                                    for (final doc in userQuery.docs) {
                                      await updateRoomSubcollection(
                                        doc.reference,
                                      );
                                    }
                                    if (partnerQuery != null) {
                                      for (final doc in partnerQuery.docs) {
                                        await updateRoomSubcollection(
                                          doc.reference,
                                        );
                                      }
                                    }

                                    await batch.commit();
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: actuallyEquipped
                                          ? cs.primary
                                          : cs.outlineVariant,
                                      width: actuallyEquipped ? 2 : 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.asset(
                                          _kRoomBackgrounds[roomKey]!,
                                          fit: BoxFit.cover,
                                          alignment: Alignment.bottomCenter,
                                        ),
                                        if (actuallyEquipped)
                                          Container(
                                            color: cs.primary.withValues(
                                              alpha: 0.2,
                                            ),
                                            child: Center(
                                              child: Icon(
                                                Icons.check_circle_rounded,
                                                color: cs.primary,
                                                size: 28,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }

                        final filteredDocs = docs.where((doc) {
                          if (_kRoomBackgrounds.containsKey(doc.id)) {
                            return false; // Skip rooms in non-room category tabs
                          }
                          final data = doc.data() as Map<String, dynamic>?;
                          final category = (data?['category'] as String?) ?? '';
                          return category.toLowerCase() ==
                                  _selectedCategory.toLowerCase() ||
                              (_selectedCategory.toLowerCase() == 'sofas' &&
                                  doc.id.startsWith('sofa_'));
                        }).toList();

                        // Fallback: If user has no furniture docs in Firestore for Sofas yet, show default brown sofa as owned
                        if (filteredDocs.isEmpty &&
                            _selectedCategory.toLowerCase() == 'sofas') {
                          return GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1.1,
                                ),
                            itemCount: 1,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {},
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: cs.primary,
                                      width: 2,
                                    ),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Center(
                                        child: Image.asset(
                                          _kSofaAssets['brown']!,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      const Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Icon(
                                          Icons.check_circle_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }

                        if (filteredDocs.isEmpty) {
                          return Center(
                            child: Text(
                              'No items unlocked in $_selectedCategory yet.',
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
                                crossAxisCount: 3,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.1,
                              ),
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final currentDoc = filteredDocs[index];
                            final furnitureData =
                                currentDoc.data() as Map<String, dynamic>?;
                            final isEquipped =
                                (furnitureData?['isEquipped'] ?? false) == true;

                            final docId = currentDoc.id;
                            final variantKey = docId.contains('_')
                                ? docId.split('_').last
                                : 'brown';

                            final assetPath =
                                _kSofaAssets[variantKey] ??
                                _kSofaAssets['brown']!;

                            return GestureDetector(
                              onTap: () async {
                                if (!isEquipped && user != null) {
                                  final firestore = FirebaseFirestore.instance;
                                  final batch = firestore.batch();
                                  final furnitureRef = firestore
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('furniture');

                                  // 1. Unequip all other sofas in current user subcollection
                                  final allItems = await furnitureRef.get();
                                  for (var doc in allItems.docs) {
                                    final data = doc.data();
                                    if (doc.id.startsWith('sofa_') ||
                                        data['category'] == 'Sofas') {
                                      batch.update(doc.reference, {
                                        'isEquipped': false,
                                      });
                                    }
                                  }

                                  // 2. Equip selected sofa for user
                                  batch.set(currentDoc.reference, {
                                    'isEquipped': true,
                                    'category': 'Sofas',
                                    'variantKey': variantKey,
                                  }, SetOptions(merge: true));

                                  // 3. Sync to partner if partner email exists
                                  final userDoc = await firestore
                                      .collection('users')
                                      .doc(user.uid)
                                      .get();
                                  final userData = userDoc.data() ?? {};
                                  final partnerEmail =
                                      ((userData['partnerEmailLower']
                                                  as String?) ??
                                              (userData['partnerEmail']
                                                  as String?) ??
                                              '')
                                          .trim()
                                          .toLowerCase();

                                  if (partnerEmail.isNotEmpty) {
                                    final partnerQuery = await firestore
                                        .collection('users')
                                        .where('email', isEqualTo: partnerEmail)
                                        .get();
                                    for (var pDoc in partnerQuery.docs) {
                                      final pFurnitureRef = pDoc.reference
                                          .collection('furniture');
                                      final pItems = await pFurnitureRef.get();
                                      for (var pItemDoc in pItems.docs) {
                                        final data = pItemDoc.data();
                                        if (pItemDoc.id.startsWith('sofa_') ||
                                            data['category'] == 'Sofas') {
                                          batch.update(pItemDoc.reference, {
                                            'isEquipped': false,
                                          });
                                        }
                                      }
                                      batch.set(
                                        pFurnitureRef.doc(currentDoc.id),
                                        {
                                          'isEquipped': true,
                                          'category': 'Sofas',
                                          'variantKey': variantKey,
                                        },
                                        SetOptions(merge: true),
                                      );
                                    }
                                  }

                                  await batch.commit();
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isEquipped
                                      ? cs.primary.withValues(alpha: 0.12)
                                      : cs.surfaceContainerHighest.withValues(
                                          alpha: 0.3,
                                        ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isEquipped
                                        ? cs.primary
                                        : cs.outlineVariant,
                                    width: isEquipped ? 2 : 1,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Center(
                                      child: Image.asset(
                                        assetPath,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    if (isEquipped)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Icon(
                                          Icons.check_circle_rounded,
                                          size: 16,
                                          color: cs.primary,
                                        ),
                                      ),
                                  ],
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

// ── Companion Sprite Widget ───────────────────────────────────────────────

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

    final matchingOption = _kCompanions.firstWhere(
      (c) => c.assetPath == source,
      orElse: () => _kCompanions.first,
    );

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

// ── Original Entrance & Design Components ─────────────────────────────────

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

class _TipButton extends StatelessWidget {
  final ColorScheme cs;
  final VoidCallback onTap;

  const _TipButton({required this.cs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.65),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(Icons.auto_awesome_rounded, size: 18, color: cs.primary),
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
