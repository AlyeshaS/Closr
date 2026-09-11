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
part '../widgets/home_page_widgets.dart';
part '../models/home_page_models.dart';
part 'home_page_room.dart';
part 'home_page_inventory.dart';

// How far up from the bottom of the screen the pet sits on the floor.
const double kPetFloorOffset = 16.0;

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
  bool _isSelectedFurnitureLocked = false;
  bool _isFurnitureTrayOpen = false;
  bool _isEditPanelCollapsed = false;
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
            _isEditPanelCollapsed = false;
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
    final roomTheme =
        kRoomThemes[_selectedRoomTheme] ?? kRoomThemes['room_pink']!;
    final roomBrown = roomTheme.baseboardDark;

    final canInteract = _hasFurnitureSelection && !_isSelectedFurnitureLocked;

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
              final isLocked =
                  _roomFurnitureKey.currentState?.isSelectedLocked ?? false;
              if ((_hasFurnitureSelection != hasSelection ||
                      _isSelectedFurnitureLocked != isLocked) &&
                  mounted) {
                setState(() {
                  _hasFurnitureSelection = hasSelection;
                  _isSelectedFurnitureLocked = isLocked;
                });
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
                            color: cs.shadow.withValues(alpha: 0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
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
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: cs.outline.withValues(alpha: 0.3),
                                width: 0.5,
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
                                        backgroundColor: cs.surface,
                                        foregroundColor: roomBrown,
                                        side: BorderSide(
                                          color: roomBrown.withValues(
                                            alpha: 0.28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _showTipSheet(context, cs),
                                    borderRadius: BorderRadius.circular(14),
                                    child: _StatPill(
                                      cs: cs,
                                      icon: Icons.auto_awesome_rounded,
                                      tint: cs.primary,
                                      label: 'Daily inspiration',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
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
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.shadow.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 34,
                              child: IconButton(
                                tooltip: _isEditPanelCollapsed
                                    ? 'Expand controls'
                                    : 'Collapse controls',
                                onPressed: () => setState(
                                  () => _isEditPanelCollapsed =
                                      !_isEditPanelCollapsed,
                                ),
                                icon: AnimatedRotation(
                                  turns: _isEditPanelCollapsed ? 0.5 : 0.0,
                                  duration: const Duration(milliseconds: 180),
                                  child: Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                    color: cs.onSurface,
                                    size: 24,
                                  ),
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Edit Room',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 19,
                                    color: cs.onSurface,
                                  ),
                            ),
                            const SizedBox(width: 5),
                            Transform.translate(
                              offset: const Offset(-6, 0),
                              child: IconButton(
                                tooltip: 'How room editing works',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 26,
                                  minHeight: 34,
                                ),
                                onPressed: () {
                                  showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (sheetContext) {
                                      final sheetTheme = Theme.of(sheetContext);
                                      final sheetCs = sheetTheme.colorScheme;
                                      final steps = <({IconData icon, String title, String body})>[
                                        (
                                          icon: Icons.touch_app_rounded,
                                          title: 'Select',
                                          body:
                                              'Tap any furniture item to select it. Locked items can still be selected to unlock them.',
                                        ),
                                        (
                                          icon: Icons.open_with_rounded,
                                          title: 'Move',
                                          body:
                                              'Drag the selected item across the room grid to place it exactly where you want.',
                                        ),
                                        (
                                          icon: Icons.rotate_right_rounded,
                                          title: 'Rotate & resize',
                                          body:
                                              'Use the Rotate and Size sliders for precise adjustments.',
                                        ),
                                        (
                                          icon: Icons.flip_rounded,
                                          title: 'Flip',
                                          body:
                                              'Mirror the selected furniture with one tap.',
                                        ),
                                        (
                                          icon: Icons.lock_rounded,
                                          title: 'Lock',
                                          body:
                                              'Use the lock button or double-tap an item to lock or unlock it. Locked furniture stays in place.',
                                        ),
                                        (
                                          icon: Icons.restart_alt_rounded,
                                          title: 'Restart',
                                          body:
                                              'Return the selected item to the position, size, rotation and flip state it had when you selected it.',
                                        ),
                                        (
                                          icon: Icons.delete_outline_rounded,
                                          title: 'Delete',
                                          body:
                                              'Delete the selected item. With nothing selected, Delete lets you remove all furniture after confirmation.',
                                        ),
                                        (
                                          icon: Icons.deselect_rounded,
                                          title: 'Deselect',
                                          body:
                                              'Tap an empty part of the room to clear your selection.',
                                        ),
                                        (
                                          icon: Icons.check_rounded,
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
                                              color: sheetCs.surface,
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    top: Radius.circular(32),
                                                  ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: sheetCs.shadow
                                                      .withValues(alpha: 0.16),
                                                  blurRadius: 30,
                                                  offset: const Offset(0, -8),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              children: [
                                                const SizedBox(height: 10),
                                                Container(
                                                  width: 44,
                                                  height: 5,
                                                  decoration: BoxDecoration(
                                                    color: sheetCs.primary
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
                                                          color: sheetCs.primary
                                                              .withValues(
                                                                alpha: 0.13,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                14,
                                                              ),
                                                          border: Border.all(
                                                            color: sheetCs
                                                                .primary
                                                                .withValues(
                                                                  alpha: 0.18,
                                                                ),
                                                          ),
                                                        ),
                                                        child: Icon(
                                                          Icons
                                                              .chair_alt_rounded,
                                                          color:
                                                              sheetCs.primary,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'How to edit your room',
                                                              style: sheetTheme
                                                                  .textTheme
                                                                  .titleLarge
                                                                  ?.copyWith(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    color: sheetCs
                                                                        .onSurface,
                                                                  ),
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              'Scroll through the controls below',
                                                              style: sheetTheme
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    color: sheetCs
                                                                        .onSurfaceVariant,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      IconButton(
                                                        tooltip: 'Close',
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              sheetContext,
                                                            ).pop(),
                                                        icon: const Icon(
                                                          Icons.close_rounded,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Divider(
                                                  height: 1,
                                                  color: sheetCs.primary
                                                      .withValues(alpha: 0.12),
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
                                                    itemCount: steps.length + 1,
                                                    separatorBuilder: (_, __) =>
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                    itemBuilder: (context, index) {
                                                      if (index ==
                                                          steps.length) {
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                top: 6,
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
                                                                color: sheetCs
                                                                    .primary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.14,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .swipe_up_rounded,
                                                                  color: sheetCs
                                                                      .primary,
                                                                ),
                                                                const SizedBox(
                                                                  width: 12,
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    'Tip: drag this panel up for more room, or swipe it down when you are done.',
                                                                    style: sheetTheme
                                                                        .textTheme
                                                                        .bodyMedium
                                                                        ?.copyWith(
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                      final step = steps[index];
                                                      return TweenAnimationBuilder<
                                                        double
                                                      >(
                                                        duration: Duration(
                                                          milliseconds:
                                                              240 +
                                                              (index * 35),
                                                        ),
                                                        curve:
                                                            Curves.easeOutCubic,
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
                                                                    (1 - value),
                                                              ),
                                                              child: Opacity(
                                                                opacity: value,
                                                                child: child,
                                                              ),
                                                            ),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                14,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                sheetCs.surface,
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
                                                                color: sheetCs
                                                                    .shadow
                                                                    .withValues(
                                                                      alpha:
                                                                          0.07,
                                                                    ),
                                                                blurRadius: 12,
                                                                offset:
                                                                    const Offset(
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
                                                                width: 42,
                                                                height: 42,
                                                                decoration: BoxDecoration(
                                                                  color: sheetCs
                                                                      .primary
                                                                      .withValues(
                                                                        alpha:
                                                                            0.12,
                                                                      ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        13,
                                                                      ),
                                                                ),
                                                                child: Icon(
                                                                  step.icon,
                                                                  size: 21,
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
                                                                      step.title,
                                                                      style: sheetTheme
                                                                          .textTheme
                                                                          .titleSmall
                                                                          ?.copyWith(
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                            color:
                                                                                sheetCs.onSurface,
                                                                          ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 3,
                                                                    ),
                                                                    Text(
                                                                      step.body,
                                                                      style: sheetTheme
                                                                          .textTheme
                                                                          .bodySmall
                                                                          ?.copyWith(
                                                                            color:
                                                                                sheetCs.onSurfaceVariant,
                                                                            height:
                                                                                1.35,
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
                            IconButton(
                              tooltip: _isSelectedFurnitureLocked
                                  ? 'Unlock selected item'
                                  : 'Lock selected item',
                              onPressed: _hasFurnitureSelection
                                  ? () async {
                                      await _roomFurnitureKey.currentState
                                          ?.toggleSelectedLock();
                                      if (!mounted) return;
                                      setState(() {
                                        _isSelectedFurnitureLocked =
                                            _roomFurnitureKey
                                                .currentState
                                                ?.isSelectedLocked ??
                                            false;
                                      });
                                    }
                                  : null,
                              icon: Icon(
                                _isSelectedFurnitureLocked
                                    ? Icons.lock_rounded
                                    : Icons.lock_open_rounded,
                                size: 21,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            const Spacer(),
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
                                  color: cs.onSurface,
                                ),
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(7),
                                  backgroundColor: cs.surface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.shadow.withValues(alpha: 0.12),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
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
                        Transform.translate(
                          offset: const Offset(0, -6),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 24, top: 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Tap an item, then drag across grid',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 220),
                          firstCurve: Curves.easeOutCubic,
                          secondCurve: Curves.easeInCubic,
                          crossFadeState: _isEditPanelCollapsed
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 12),
                              // Dedicated row for Flip, Restart, Delete
                              Row(
                                children: [
                                  Expanded(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: cs.shadow.withValues(
                                              alpha: 0.10,
                                            ),
                                            blurRadius: 7,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: FilledButton.tonalIcon(
                                        onPressed: canInteract
                                            ? () => _roomFurnitureKey
                                                  .currentState
                                                  ?.toggleFlipSelected()
                                            : null,
                                        icon: Icon(
                                          Icons.flip_rounded,
                                          size: 16,
                                          color: canInteract
                                              ? cs.onSurface
                                              : cs.onSurface.withValues(
                                                  alpha: 0.38,
                                                ),
                                        ),
                                        label: Text(
                                          'Flip',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: canInteract
                                                ? cs.onSurface
                                                : cs.onSurface.withValues(
                                                    alpha: 0.38,
                                                  ),
                                          ),
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: canInteract
                                              ? cs.surface
                                              : cs.surfaceContainerHighest
                                                    .withValues(alpha: 0.4),
                                          foregroundColor: canInteract
                                              ? cs.onSurface
                                              : cs.onSurface.withValues(
                                                  alpha: 0.38,
                                                ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                          minimumSize: const Size(0, 36),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            side: BorderSide(
                                              color: canInteract
                                                  ? cs.primary.withValues(
                                                      alpha: 0.65,
                                                    )
                                                  : cs.outlineVariant
                                                        .withValues(alpha: 0.3),
                                              width: canInteract ? 1.2 : 1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: cs.shadow.withValues(
                                              alpha: 0.10,
                                            ),
                                            blurRadius: 7,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: FilledButton.tonalIcon(
                                        onPressed: canInteract
                                            ? () {
                                                _roomFurnitureKey.currentState
                                                    ?.restartSelected();
                                                setState(() {});
                                              }
                                            : null,
                                        icon: Icon(
                                          Icons.restart_alt_rounded,
                                          size: 16,
                                          color: canInteract
                                              ? cs.onSurface
                                              : cs.onSurface.withValues(
                                                  alpha: 0.38,
                                                ),
                                        ),
                                        label: Text(
                                          'Restart',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: canInteract
                                                ? cs.onSurface
                                                : cs.onSurface.withValues(
                                                    alpha: 0.38,
                                                  ),
                                          ),
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: canInteract
                                              ? cs.surface
                                              : cs.surfaceContainerHighest
                                                    .withValues(alpha: 0.4),
                                          foregroundColor: canInteract
                                              ? cs.onSurface
                                              : cs.onSurface.withValues(
                                                  alpha: 0.38,
                                                ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                          minimumSize: const Size(0, 36),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            side: BorderSide(
                                              color: canInteract
                                                  ? cs.primary.withValues(
                                                      alpha: 0.65,
                                                    )
                                                  : cs.outlineVariant
                                                        .withValues(alpha: 0.3),
                                              width: canInteract ? 1.2 : 1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: cs.shadow.withValues(
                                              alpha: 0.10,
                                            ),
                                            blurRadius: 7,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: FilledButton.tonalIcon(
                                        onPressed: _isSelectedFurnitureLocked
                                            ? null
                                            : () async {
                                                final roomState =
                                                    _roomFurnitureKey
                                                        .currentState;
                                                if (roomState == null) return;

                                                if (roomState.hasSelection) {
                                                  await roomState
                                                      .deleteSelected();
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
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              dialogContext,
                                                            ).pop(false),
                                                        child: const Text(
                                                          'Cancel',
                                                        ),
                                                      ),
                                                      FilledButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              dialogContext,
                                                            ).pop(true),
                                                        style:
                                                            FilledButton.styleFrom(
                                                              backgroundColor:
                                                                  cs.error,
                                                              foregroundColor:
                                                                  cs.onError,
                                                            ),
                                                        child: const Text(
                                                          'Delete all',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );

                                                if (confirmed == true) {
                                                  await roomState
                                                      .deleteAllFurniture();
                                                }
                                              },
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 16,
                                          color: !_isSelectedFurnitureLocked
                                              ? cs.error
                                              : cs.error.withValues(
                                                  alpha: 0.38,
                                                ),
                                        ),
                                        label: Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: !_isSelectedFurnitureLocked
                                                ? cs.error
                                                : cs.error.withValues(
                                                    alpha: 0.38,
                                                  ),
                                            fontSize: 12,
                                          ),
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              !_isSelectedFurnitureLocked
                                              ? cs.surface
                                              : cs.surfaceContainerHighest
                                                    .withValues(alpha: 0.4),
                                          foregroundColor:
                                              !_isSelectedFurnitureLocked
                                              ? cs.error
                                              : cs.error.withValues(
                                                  alpha: 0.38,
                                                ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                          minimumSize: const Size(0, 36),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            side: BorderSide(
                                              color: !_isSelectedFurnitureLocked
                                                  ? cs.primary.withValues(
                                                      alpha: 0.65,
                                                    )
                                                  : cs.outlineVariant
                                                        .withValues(alpha: 0.3),
                                              width: !_isSelectedFurnitureLocked
                                                  ? 1.2
                                                  : 1.0,
                                            ),
                                          ),
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
                                        activeColor: cs.primary,
                                        inactiveColor: cs.onSurfaceVariant
                                            .withValues(alpha: 0.32),
                                        onChanged: canInteract
                                            ? (val) {
                                                setState(() {
                                                  _roomFurnitureKey.currentState
                                                      ?.setRotationSelected(
                                                        val,
                                                      );
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
                                        activeColor: cs.primary,
                                        inactiveColor: cs.onSurfaceVariant
                                            .withValues(alpha: 0.32),
                                        onChanged: canInteract
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
                          secondChild: const SizedBox.shrink(),
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
              color: cs.surface,
              shape: CircleBorder(
                side: BorderSide(
                  color: roomBrown.withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
              elevation: 8,
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
                          (data?['companionEmoji'] as String?) ?? 'ðŸ ±';
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
                  color: cs.surface,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: roomBrown.withValues(alpha: 0.22),
                      width: 1,
                    ),
                  ),
                  elevation: 8,
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
    this.fallbackEmoji = 'ðŸ ±',
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
                child: const Text('â˜ ï¸ ', style: TextStyle(fontSize: 12)),
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
                child: const Text('ðŸŒ™', style: TextStyle(fontSize: 14)),
              ),
            ),
          if (equippedAccessories.contains('star_collar'))
            const Positioned(
              bottom: 18,
              child: Text('âœ¨', style: TextStyle(fontSize: 13)),
            ),
          if (equippedAccessories.contains('heart_tag'))
            const Positioned(
              bottom: 8,
              child: Text('ðŸ’—', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
