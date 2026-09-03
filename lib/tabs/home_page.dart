// lib/tabs/home_page.dart
import 'dart:math' as math;
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
  bool _isEditingLayout = false;

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
      builder: (sheetContext) => _FurnitureInventorySheet(
        cs: cs,
        onEditModeChanged: (isEditing) {
          setState(() {
            _isEditingLayout = isEditing;
          });
        },
      ),
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

        // ── Room Furniture (Sofa) with Edit Grid Support ────────────────
        Positioned.fill(child: _RoomFurniture(isEditing: _isEditingLayout)),

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

// ─────────────────────────────────────────────────────────────────────────
// Room perspective geometry — the SINGLE source of truth for both the grid
// that gets painted on screen and the math that positions furniture. Every
// number here is calibrated against the actual room_bg / room_bg2 art (the
// back corner and the wall/floor seam), so "where an item can go" always
// matches "what the grid lines show"[cite: 1].
// ─────────────────────────────────────────────────────────────────────────

enum RoomSurface { floor, leftWall, rightWall }

class _RoomPoint {
  final Offset anchor;
  final double scale;
  const _RoomPoint(this.anchor, this.scale);
}

class _RoomPerspective {
  const _RoomPerspective(this.size);
  final Size size;

  // Fraction of the room height where the back corner (where both walls
  // meet the floor) sits, at screen center. Measured from room_bg.png[cite: 1].
  static const double kCornerVertexYFrac = 0.605;
  // The same wall/floor seam slopes downward as it goes outward — this is
  // how far down it's reached by the time it hits the left/right edges[cite: 1].
  static const double kSeamEdgeYFrac = 0.68;
  // How small an item gets at the farthest point of its surface (the back
  // corner for floor items, the seam for wall items)[cite: 1].
  static const double kMinDepthScale = 0.55;
  // >1 compresses grid rows near the vanishing point, like real perspective[cite: 1].
  static const double kPerspectiveGamma = 1.5;

  double get centerX => size.width / 2;
  double get cornerVertexY => size.height * kCornerVertexYFrac;
  double get _seamEdgeY => size.height * kSeamEdgeYFrac;

  double _ease(double t) =>
      math.pow(t.clamp(0.0, 1.0), kPerspectiveGamma).toDouble();

  /// Y of the wall/floor seam at a horizontal fraction across the screen
  /// (0 = left edge, 0.5 = the back corner, 1 = right edge). It's a shallow
  /// "V" peaking at the corner, matching the room art[cite: 1].
  double seamYAt(double xFrac) {
    final distFromCenter = (xFrac.clamp(0.0, 1.0) - 0.5).abs() * 2;
    return lerpDouble(cornerVertexY, _seamEdgeY, distFromCenter)!;
  }

  /// Floor placement. col: 0 (left) .. 1 (right).
  /// row: 0 (back, against the wall) .. 1 (front, closest to the viewer)[cite: 1].
  _RoomPoint floorPoint(double col, double row) {
    final c = col.clamp(0.0, 1.0);
    final x = size.width * c;
    final seamY = seamYAt(c);
    final t = _ease(row);
    final y = lerpDouble(seamY, size.height, t)!;
    final scale = lerpDouble(kMinDepthScale, 1.0, t)!;
    return _RoomPoint(Offset(x, y), scale);
  }

  /// Wall placement. col: 0 (at the back corner seam) .. 1 (at the wall's
  /// outer/front edge). row: 0 (floor) .. 1 (ceiling)[cite: 1].
  _RoomPoint wallPoint(RoomSurface side, double col, double row) {
    final outerX = side == RoomSurface.leftWall ? 0.0 : size.width;
    final dt = _ease(col);
    final x = lerpDouble(centerX, outerX, dt)!;
    final xFrac = (x / size.width).clamp(0.0, 1.0);
    final floorY = seamYAt(xFrac);
    final y = lerpDouble(floorY, 0, row.clamp(0.0, 1.0))!;
    final scale = lerpDouble(kMinDepthScale, 1.0, dt)!;
    return _RoomPoint(Offset(x, y), scale);
  }

  _RoomPoint pointFor(RoomSurface surface, double col, double row) {
    if (surface == RoomSurface.floor) return floorPoint(col, row);
    return wallPoint(surface, col, row);
  }
}

class _RoomFurniture extends StatefulWidget {
  final bool isEditing;
  const _RoomFurniture({this.isEditing = false});

  @override
  State<_RoomFurniture> createState() => _RoomFurnitureState();
}

class _RoomFurnitureState extends State<_RoomFurniture> {
  static const double kBaseItemSize = 130.0;
  static const double kStep = 0.08;

  double? _editingCol;
  double? _editingRow;
  String? _editingDocId;
  bool _wasEditing = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final screenSize = MediaQuery.of(context).size;
    final perspective = _RoomPerspective(screenSize);

    if (_wasEditing && !widget.isEditing) {
      if (_editingCol != null &&
          _editingRow != null &&
          _editingDocId != null &&
          user != null) {
        _saveItemPosition(user, _editingDocId!, _editingCol!, _editingRow!);
      }
      _editingCol = null;
      _editingRow = null;
      _editingDocId = null;
    }
    _wasEditing = widget.isEditing;

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
          return const SizedBox.shrink();
        }

        final equippedDoc = snapshot.data!.docs.first;
        final data = equippedDoc.data() as Map<String, dynamic>?;
        final locationMap = data?['location'] as Map<String, dynamic>?;

        // The surface is a property of the item itself (set on the
        // furniture doc, e.g. by whoever catalogued it), not something
        // picked in the editor: 'floor', 'leftWall', or 'rightWall'[cite: 1].
        final surface = RoomSurface.values.firstWhere(
          (s) => s.name == (data?['surface'] as String?),
          orElse: () => RoomSurface.floor,
        );

        final defaultRow = surface == RoomSurface.floor ? 0.35 : 0.5;
        final savedCol = (locationMap?['col'] as num?)?.toDouble() ?? 0.5;
        final savedRow =
            (locationMap?['row'] as num?)?.toDouble() ?? defaultRow;

        if (_editingDocId != equippedDoc.id) {
          _editingDocId = equippedDoc.id;
          if (widget.isEditing) {
            _editingCol = savedCol;
            _editingRow = savedRow;
          }
        }
        if (widget.isEditing && (_editingCol == null || _editingRow == null)) {
          _editingCol = savedCol;
          _editingRow = savedRow;
        }

        final col = widget.isEditing ? _editingCol! : savedCol;
        final row = widget.isEditing ? _editingRow! : savedRow;

        String variantKey = 'brown';
        if (equippedDoc.id.startsWith('sofa_')) {
          variantKey = equippedDoc.id.contains('_')
              ? equippedDoc.id.split('_').last
              : 'brown';
        }
        final assetPath =
            _kSofaAssets[variantKey] ??
            'assets/images/furniture/sofa_brown.png';

        final point = perspective.pointFor(surface, col, row);
        final itemSize = kBaseItemSize * point.scale;
        final isFloor = surface == RoomSurface.floor;
        final left = point.anchor.dx - itemSize / 2;
        final top = isFloor
            ? point.anchor.dy - itemSize
            : point.anchor.dy - itemSize / 2;

        return Stack(
          children: [
            if (widget.isEditing)
              Positioned.fill(
                child: CustomPaint(
                  painter: _RoomGridPainter(activeSurface: surface),
                ),
              ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 150),
              left: left,
              top: top,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: itemSize,
                    height: itemSize,
                    child: Image.asset(assetPath, fit: BoxFit.contain),
                  ),

                  if (widget.isEditing) ...[
                    Positioned(
                      top: -30,
                      child: _GridArrowButton(
                        icon: Icons.keyboard_arrow_up_rounded,
                        onTap: () => setState(() => _moveVertical(surface, 1)),
                      ),
                    ),
                    Positioned(
                      bottom: -30,
                      child: _GridArrowButton(
                        icon: Icons.keyboard_arrow_down_rounded,
                        onTap: () => setState(() => _moveVertical(surface, -1)),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      child: _GridArrowButton(
                        icon: Icons.keyboard_arrow_left_rounded,
                        onTap: () =>
                            setState(() => _moveHorizontal(surface, -1)),
                      ),
                    ),
                    Positioned(
                      right: -30,
                      child: _GridArrowButton(
                        icon: Icons.keyboard_arrow_right_rounded,
                        onTap: () =>
                            setState(() => _moveHorizontal(surface, 1)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  double _clamp01(double v) => v.clamp(0.0, 1.0);

  // "Left"/"right"/"up"/"down" always mean what they look like on screen,
  // regardless of which surface the item is on — the col/row delta needed
  // to achieve that differs per surface (see _RoomPerspective)[cite: 1].
  void _moveHorizontal(RoomSurface surface, int dir) {
    final sign = surface == RoomSurface.leftWall ? -dir : dir;
    _editingCol = _clamp01(_editingCol! + sign * kStep);
  }

  void _moveVertical(RoomSurface surface, int dir) {
    if (surface == RoomSurface.floor) {
      // dir 1 = "up" arrow = further back = smaller row[cite: 1].
      _editingRow = _clamp01(_editingRow! - dir * kStep);
    } else {
      // dir 1 = "up" arrow = toward the ceiling = larger row[cite: 1].
      _editingRow = _clamp01(_editingRow! + dir * kStep);
    }
  }

  Future<void> _saveItemPosition(
    User user,
    String docId,
    double col,
    double row,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final userDoc = await firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};
    final partnerEmail =
        ((data['partnerEmailLower'] as String?) ??
                (data['partnerEmail'] as String?) ??
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
              .where('email', isEqualTo: partnerEmail)
              .get()
        : null;

    final location = {'col': col, 'row': row};

    final batch = firestore.batch();
    for (final doc in userQuery.docs) {
      batch.set(doc.reference.collection('furniture').doc(docId), {
        'location': location,
      }, SetOptions(merge: true));
    }
    if (partnerQuery != null) {
      for (final doc in partnerQuery.docs) {
        batch.set(
          doc.reference.collection('furniture').doc(docId),
          {'location': location},
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
  }
}

// ── Helper UI Components for Grid & Arrows ──────────────────────────────

class _GridArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GridArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ── Room Grid Painter with correct isometric-style diamond floor tiles ───

class _RoomGridPainter extends CustomPainter {
  final RoomSurface activeSurface;
  const _RoomGridPainter({required this.activeSurface});

  // These values match the room artwork itself.
  //
  // The room is split into:
  //   • left wall polygon
  //   • right wall polygon
  //   • floor polygon
  //
  // Drawing inside clipped polygons keeps every line perfectly contained
  // inside its own surface, like the reference image.
  static const double _centerX = 0.50;

  // Top centre point where both walls meet.
  static const double _ceilingCenterY = 0.010;

  // Outer top corners of each wall.
  static const double _ceilingEdgeY = 0.086;

  // Back floor corner.
  static const double _floorCornerY = 0.535;

  // Floor/wall seam at the left/right edges.
  static const double _floorEdgeY = 0.645;

  // Tiny right-side correction so the grid aligns with the background.
  // Smaller Y = slightly higher on screen.
  static const double _rightFloorEdgeY = 0.642;

  // Grid density. These values give the same "pixel room" feel as the
  // generated reference while keeping cells large enough for furniture.
  static const int _wallColumns = 8;
  static const int _wallRows = 14;
  static const int _floorBands = 10;

  @override
  void paint(Canvas canvas, Size size) {
    _paintLeftWall(canvas, size, activeSurface == RoomSurface.leftWall);
    _paintRightWall(canvas, size, activeSurface == RoomSurface.rightWall);
    _paintFloor(canvas, size, activeSurface == RoomSurface.floor);
  }

  Paint _gridPaint(bool active) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = active ? 1.15 : 0.85
    ..color = Colors.black.withValues(alpha: active ? 0.34 : 0.20);

  Offset _p(Size size, double x, double y) =>
      Offset(size.width * x, size.height * y);

  Path _leftWallPath(Size size) {
    return Path()
      ..moveTo(size.width * _centerX, size.height * _ceilingCenterY)
      ..lineTo(0, size.height * _ceilingEdgeY)
      ..lineTo(0, size.height * _floorEdgeY)
      ..lineTo(size.width * _centerX, size.height * _floorCornerY)
      ..close();
  }

  Path _rightWallPath(Size size) {
    return Path()
      ..moveTo(size.width * _centerX, size.height * _ceilingCenterY)
      ..lineTo(size.width, size.height * _ceilingEdgeY)
      ..lineTo(size.width, size.height * _rightFloorEdgeY)
      ..lineTo(size.width * _centerX, size.height * _floorCornerY)
      ..close();
  }

  Path _floorPath(Size size) {
    return Path()
      ..moveTo(0, size.height * _floorEdgeY)
      ..lineTo(size.width * _centerX, size.height * _floorCornerY)
      ..lineTo(size.width, size.height * _rightFloorEdgeY)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  void _paintLeftWall(Canvas canvas, Size size, bool active) {
    final paint = _gridPaint(active);
    final clip = _leftWallPath(size);

    canvas.save();
    canvas.clipPath(clip);

    // Vertical-ish columns. Each line connects the sloped ceiling edge to
    // the sloped floor seam, producing straight perspective cells.
    for (int i = 1; i < _wallColumns; i++) {
      final t = i / _wallColumns;

      final top = Offset.lerp(
        _p(size, _centerX, _ceilingCenterY),
        _p(size, 0, _ceilingEdgeY),
        t,
      )!;

      final bottom = Offset.lerp(
        _p(size, _centerX, _floorCornerY),
        _p(size, 0, _floorEdgeY),
        t,
      )!;

      canvas.drawLine(top, bottom, paint);
    }

    // Horizontal rows. Interpolating between the ceiling edge and floor
    // seam keeps the rows straight and parallel to the wall perspective.
    for (int j = 1; j < _wallRows; j++) {
      final t = j / _wallRows;

      final inner = Offset.lerp(
        _p(size, _centerX, _ceilingCenterY),
        _p(size, _centerX, _floorCornerY),
        t,
      )!;

      final outer = Offset.lerp(
        _p(size, 0, _ceilingEdgeY),
        _p(size, 0, _floorEdgeY),
        t,
      )!;

      canvas.drawLine(inner, outer, paint);
    }

    canvas.restore();
  }

  void _paintRightWall(Canvas canvas, Size size, bool active) {
    final paint = _gridPaint(active);
    final clip = _rightWallPath(size);

    canvas.save();
    canvas.clipPath(clip);

    for (int i = 1; i < _wallColumns; i++) {
      final t = i / _wallColumns;

      final top = Offset.lerp(
        _p(size, _centerX, _ceilingCenterY),
        _p(size, 1, _ceilingEdgeY),
        t,
      )!;

      final bottom = Offset.lerp(
        _p(size, _centerX, _floorCornerY),
        _p(size, 1, _rightFloorEdgeY),
        t,
      )!;

      canvas.drawLine(top, bottom, paint);
    }

    for (int j = 1; j < _wallRows; j++) {
      final t = j / _wallRows;

      final inner = Offset.lerp(
        _p(size, _centerX, _ceilingCenterY),
        _p(size, _centerX, _floorCornerY),
        t,
      )!;

      final outer = Offset.lerp(
        _p(size, 1, _ceilingEdgeY),
        _p(size, 1, _rightFloorEdgeY),
        t,
      )!;

      canvas.drawLine(inner, outer, paint);
    }

    canvas.restore();
  }

  void _paintFloor(Canvas canvas, Size size, bool active) {
    final paint = _gridPaint(active);
    final floor = _floorPath(size);

    canvas.save();
    canvas.clipPath(floor);

    final w = size.width;
    final h = size.height;

    final corner = Offset(w * _centerX, h * _floorCornerY);

    final leftEdge = Offset(0, h * _floorEdgeY);

    final rightEdge = Offset(w, h * _rightFloorEdgeY);

    // IMPORTANT:
    // The floor lines now use the EXACT SAME seam division points as the
    // vertical wall-column lines above them.
    //
    // That means every wall column ends at a point on the wall/floor seam,
    // and a floor line begins at that exact same point. Visually the grid
    // now looks continuous across the corner instead of being two separate
    // grids that merely have similar spacing.

    // Screen-space slopes of the actual left and right wall/floor seams.
    final leftSeamSlope = (leftEdge.dy - corner.dy) / (leftEdge.dx - corner.dx);
    final rightSeamSlope =
        (rightEdge.dy - corner.dy) / (rightEdge.dx - corner.dx);

    // ── LEFT WALL -> FLOOR ────────────────────────────────────────────
    //
    // These start at the same bottom points used by _paintLeftWall().
    // Once they hit the floor, they travel in the direction parallel to
    // the RIGHT seam, forming one family of the diamond grid.
    const int floorOverflowLines = 24;

    for (
      int i = -floorOverflowLines;
      i <= _wallColumns + floorOverflowLines;
      i++
    ) {
      final t = i / _wallColumns;

      final start = Offset.lerp(corner, leftEdge, t)!;

      // Continue down-right, parallel to the opposite/right seam.
      final remainingY = h - start.dy;
      final dx = rightSeamSlope.abs() < 0.0001
          ? w
          : remainingY / rightSeamSlope.abs();

      final end = Offset(start.dx + dx, h);

      canvas.drawLine(start, end, paint);
    }

    // ── RIGHT WALL -> FLOOR ───────────────────────────────────────────
    //
    // These start at the same bottom points used by _paintRightWall().
    // They continue down-left, parallel to the LEFT seam.
    for (
      int i = -floorOverflowLines;
      i <= _wallColumns + floorOverflowLines;
      i++
    ) {
      final t = i / _wallColumns;

      final start = Offset.lerp(corner, rightEdge, t)!;

      final remainingY = h - start.dy;
      final dx = leftSeamSlope.abs() < 0.0001
          ? w
          : remainingY / leftSeamSlope.abs();

      final end = Offset(start.dx - dx, h);

      canvas.drawLine(start, end, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RoomGridPainter oldDelegate) =>
      oldDelegate.activeSurface != activeSurface;
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
  final ValueChanged<bool>? onEditModeChanged;

  const _FurnitureInventorySheet({required this.cs, this.onEditModeChanged});

  @override
  State<_FurnitureInventorySheet> createState() =>
      _FurnitureInventorySheetState();
}

class _FurnitureInventorySheetState extends State<_FurnitureInventorySheet> {
  String _selectedCategory = 'Rooms';
  bool _isEditingLayout = false;

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
      height: MediaQuery.of(context).size.height * 0.70,
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
                  icon: Icon(
                    _isEditingLayout ? Icons.check_rounded : Icons.edit_rounded,
                    color: cs.primary,
                  ),
                  tooltip: _isEditingLayout
                      ? 'Save layout'
                      : 'Edit room layout',
                  onPressed: () {
                    setState(() {
                      _isEditingLayout = !_isEditingLayout;
                    });
                    if (widget.onEditModeChanged != null) {
                      widget.onEditModeChanged!(_isEditingLayout);
                    }
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
                            return false;
                          }
                          final data = doc.data() as Map<String, dynamic>?;
                          final category =
                              (data?['category'] as String?) ?? 'Sofas';
                          return category.toLowerCase() ==
                              _selectedCategory.toLowerCase();
                        }).toList();

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

                                  final allItems = await furnitureRef.get();
                                  for (var doc in allItems.docs) {
                                    if (!_kRoomBackgrounds.containsKey(
                                      doc.id,
                                    )) {
                                      batch.update(doc.reference, {
                                        'isEquipped': false,
                                      });
                                    }
                                  }

                                  batch.update(currentDoc.reference, {
                                    'isEquipped': true,
                                  });

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
                                        if (!_kRoomBackgrounds.containsKey(
                                          pItemDoc.id,
                                        )) {
                                          batch.update(pItemDoc.reference, {
                                            'isEquipped': false,
                                          });
                                        }
                                      }
                                      batch.update(
                                        pFurnitureRef.doc(currentDoc.id),
                                        {'isEquipped': true},
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

// ── Glass Card Component ──────────────────────────────────────────────────

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

// ── Tip Loading & Loaded Components ───────────────────────────────────────

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

// ── Reveal Animation Component ────────────────────────────────────────────

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

// ── Character Sprite Component ────────────────────────────────────────────

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
