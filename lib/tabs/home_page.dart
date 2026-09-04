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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadEquippedRoom();
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

  Future<void> _loadEquippedRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoadingRoom = false);
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
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingRoom = false);
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
        Positioned.fill(
          child: _RoomScene(
            isEditing: _isEditingLayout,
            colorScheme: cs,
            roomThemeKey: _selectedRoomTheme,
            onToggleEditing: (val) {
              setState(() {
                _isEditingLayout = val;
              });
            },
          ),
        ),

        IgnorePointer(
          // AnimatedOpacity at opacity 0 still participates in hit testing.
          // After loading, ignore this full-screen overlay so room controls
          // underneath (including the furniture arrows) can receive taps.
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

        IgnorePointer(
          ignoring: _isEditingLayout,
          child: SafeArea(
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
                                    final count =
                                        snapshot.data?.docs.length ?? 0;
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
                                        (data?['sharedStreakCurrent']
                                            as int?) ??
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
        ),
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
                    final data = snapshot.data?.data() as Map<String, dynamic>?;

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
        Positioned(
          right: 24,
          bottom: kPetFloorOffset + 20,
          child: IgnorePointer(
            ignoring: _isEditingLayout,
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
}

class _RoomScene extends StatelessWidget {
  final bool isEditing;
  final ColorScheme colorScheme;
  final String roomThemeKey;
  final ValueChanged<bool> onToggleEditing;

  const _RoomScene({
    required this.isEditing,
    required this.colorScheme,
    required this.roomThemeKey,
    required this.onToggleEditing,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Transform.scale(
        scale: _RoomCanvas.displayScale,
        alignment: _RoomCanvas.displayScaleAlignment,
        child: FittedBox(
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
                        kRoomThemes[roomThemeKey] ?? kRoomThemes['room_pink']!,
                  ),
                ),
                _RoomFurniture(
                  isEditing: isEditing,
                  colorScheme: colorScheme,
                  onToggleEditing: onToggleEditing,
                ),
              ],
            ),
          ),
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
      roomRect.left + roomRect.width * _RoomGeometry.leftX,
      roomRect.top + roomRect.height * _RoomGeometry.floorLeftEdgeY,
    );
    final corner = Offset(
      roomRect.left + roomRect.width * _RoomGeometry.centerX,
      roomRect.top + roomRect.height * _RoomGeometry.floorCornerY,
    );
    final right = Offset(
      roomRect.left + roomRect.width * _RoomGeometry.rightX,
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
  }) {
    final path = floorPath();
    final points = floorFootprint(
      gridX: gridX,
      gridY: gridY,
      widthSquares: widthSquares,
      lengthSquares: lengthSquares,
    );

    // Keep the full furniture footprint on the floor. A tiny inset avoids
    // rejecting cells that mathematically land exactly on the path edge.
    final center = Offset(
      points.map((p) => p.dx).reduce((a, b) => a + b) / points.length,
      points.map((p) => p.dy).reduce((a, b) => a + b) / points.length,
    );

    for (final point in points) {
      final inset = Offset.lerp(point, center, 0.015)!;
      if (!path.contains(inset)) return false;
    }
    return true;
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
  final ValueChanged<bool> onToggleEditing;

  const _RoomFurniture({
    required this.isEditing,
    required this.colorScheme,
    required this.onToggleEditing,
  });

  @override
  State<_RoomFurniture> createState() => _RoomFurnitureState();
}

class _RoomFurnitureState extends State<_RoomFurniture> {
  double? _editingCol;
  double? _editingRow;
  String? _editingDocId;
  bool _wasEditing = false;
  String _activeCategory = 'Sofas';
  double _dragGridXAccumulator = 0.0;
  double _dragGridYAccumulator = 0.0;
  double? _dragTargetGridX;
  double? _dragTargetGridY;

  final List<String> _editCategories = [
    'Sofas',
    'Beds',
    'Desks',
    'Rugs',
    'Decor',
  ];

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
        return kSofaAssets;
    }
  }

  bool _checkOverlap(
    String currentDocId,
    double targetCol,
    double targetRow,
    List<QueryDocumentSnapshot> allDocs,
  ) {
    final metaCurrent = getFurnitureMeta(currentDocId);

    final currentX = targetCol * _RoomGeometry.floorColumns;
    final currentY = targetRow * _RoomGeometry.floorColumns;

    final currentRect = Rect.fromLTWH(
      currentX,
      currentY,
      metaCurrent.widthSquares.toDouble(),
      metaCurrent.lengthSquares.toDouble(),
    );

    for (final doc in allDocs) {
      if (doc.id == currentDocId) continue;

      final data = doc.data() as Map<String, dynamic>?;
      if (data?['isEquipped'] != true) continue;

      final metaOther = getFurnitureMeta(doc.id);
      if (metaOther.surface != metaCurrent.surface) continue;

      final loc = data?['location'] as Map<String, dynamic>?;
      if (loc == null) continue;

      final otherCol = (loc['col'] as num?)?.toDouble() ?? 0.5;
      final otherRow = (loc['row'] as num?)?.toDouble() ?? 0.5;

      final otherRect = Rect.fromLTWH(
        otherCol * _RoomGeometry.floorColumns,
        otherRow * _RoomGeometry.floorColumns,
        metaOther.widthSquares.toDouble(),
        metaOther.lengthSquares.toDouble(),
      );

      if (currentRect.overlaps(otherRect)) return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }

            final allDocs = snapshot.data!.docs;
            final equippedDocs = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              return data?['isEquipped'] == true &&
                  !kRoomThemes.containsKey(doc.id);
            }).toList();

            final equippedDoc = widget.isEditing && _editingDocId != null
                ? equippedDocs
                          .where((doc) => doc.id == _editingDocId)
                          .firstOrNull ??
                      equippedDocs.firstOrNull
                : equippedDocs.firstOrNull;

            if (_wasEditing && !widget.isEditing) {
              if (_editingCol != null &&
                  _editingRow != null &&
                  _editingDocId != null &&
                  user != null) {
                _saveItemPosition(
                  user,
                  _editingDocId!,
                  _editingCol!,
                  _editingRow!,
                );
              }
              _editingCol = null;
              _editingRow = null;
              _editingDocId = null;
            }
            _wasEditing = widget.isEditing;

            if (equippedDoc == null) {
              return Stack(
                children: [
                  if (widget.isEditing)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RoomGridPainter(
                          activeSurface: RoomSurface.floor,
                        ),
                      ),
                    ),
                  if (widget.isEditing)
                    Positioned(
                      bottom: 40,
                      left: 16,
                      right: 16,
                      child: _buildBottomEditBar(user, allDocs),
                    ),
                ],
              );
            }

            final data = equippedDoc.data() as Map<String, dynamic>?;
            final locationMap = data?['location'] as Map<String, dynamic>?;

            final meta = getFurnitureMeta(equippedDoc.id);
            final surface = meta.surface;

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
            if (widget.isEditing &&
                (_editingCol == null || _editingRow == null)) {
              _editingCol = savedCol;
              _editingRow = savedRow;
            }

            final rawCol = widget.isEditing ? _editingCol! : savedCol;
            final rawRow = widget.isEditing ? _editingRow! : savedRow;

            final col = surface == RoomSurface.floor
                ? rawCol
                : _clampFurnitureCol(equippedDoc.id, rawCol);
            final row = surface == RoomSurface.floor
                ? rawRow
                : _clampFurnitureRow(equippedDoc.id, rawRow);

            final assetPath = meta.assetPath;
            final squarePixels = _RoomCanvas.furnitureSquarePixels;
            final itemWidth = squarePixels * meta.widthSquares;
            final itemHeight = squarePixels * meta.lengthSquares;

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

              point = _RoomPoint(
                Offset(footprint.center.dx, footprint.bottom),
                1.0,
              );
            } else {
              point = perspective.pointFor(surface, col, row);
            }

            final left = point.anchor.dx - itemWidth / 2;
            final top = isFloor
                ? point.anchor.dy - itemHeight
                : point.anchor.dy - itemHeight / 2;

            return Stack(
              children: [
                if (widget.isEditing)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RoomGridPainter(activeSurface: surface),
                    ),
                  ),

                Positioned(
                  left: left,
                  top: top,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: widget.isEditing
                        ? (_) {
                            _dragGridXAccumulator = 0.0;
                            _dragGridYAccumulator = 0.0;
                            _dragTargetGridX = _normalizedToGrid(
                              _editingCol!,
                            ).toDouble();
                            _dragTargetGridY = _normalizedToGrid(
                              _editingRow!,
                            ).toDouble();
                          }
                        : null,
                    onPanUpdate: widget.isEditing
                        ? (details) {
                            _handleFurnitureDrag(
                              equippedDoc.id,
                              details.delta,
                              perspective,
                            );
                          }
                        : null,
                    onPanEnd: widget.isEditing
                        ? (_) {
                            _dragGridXAccumulator = 0.0;
                            _dragGridYAccumulator = 0.0;
                            _dragTargetGridX = null;
                            _dragTargetGridY = null;
                          }
                        : null,
                    child: SizedBox(
                      width: itemWidth,
                      height: itemHeight,
                      child: Image.asset(assetPath, fit: BoxFit.contain),
                    ),
                  ),
                ),

                if (widget.isEditing)
                  Positioned(
                    bottom: 24,
                    left: 20,
                    right: 20,
                    child: _buildBottomEditBar(user, allDocs),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBottomEditBar(User? user, List<QueryDocumentSnapshot> allDocs) {
    final assetsMap = _getAssetsForCategory(_activeCategory);
    final cs = widget.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 24,
        horizontal: 22,
      ), // Extra large and spacious
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(36), // Generous rounded corners
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48, // Much larger category tabs
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _editCategories.map((cat) {
                final isSelected = cat == _activeCategory;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ChoiceChip(
                    label: Text(
                      cat,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _activeCategory = cat);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 92, // Much larger item asset preview cards
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: assetsMap.entries.map((entry) {
                final variantKey = entry.key;
                final path = entry.value;
                String prefix = '';
                if (_activeCategory.toLowerCase() == 'sofas') prefix = 'sofa_';
                if (_activeCategory.toLowerCase() == 'beds') prefix = 'bed_';
                if (_activeCategory.toLowerCase() == 'desks') prefix = 'desk_';
                if (_activeCategory.toLowerCase() == 'rugs') prefix = 'carpet_';

                final docId = prefix.isNotEmpty
                    ? '$prefix$variantKey'
                    : variantKey;
                final isCurrent = _editingDocId == docId;

                return GestureDetector(
                  onTap: () async {
                    if (user != null) {
                      setState(() {
                        _editingDocId = docId;
                        _editingCol = 0.5;
                        _editingRow = 0.35;
                      });
                      await _equipItem(user, docId, _activeCategory);
                    }
                  },
                  child: Container(
                    width: 92,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? cs.primary.withValues(alpha: 0.2)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isCurrent ? cs.primary : Colors.transparent,
                        width: 4,
                      ),
                    ),
                    child: Image.asset(path, fit: BoxFit.contain),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 60, // Much larger save button
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      if (_editingCol != null &&
                          _editingRow != null &&
                          _editingDocId != null &&
                          user != null) {
                        _saveItemPosition(
                          user,
                          _editingDocId!,
                          _editingCol!,
                          _editingRow!,
                        );
                      }
                      widget.onToggleEditing(false);
                    },
                    icon: const Icon(Icons.check_rounded, size: 26),
                    label: const Text(
                      'Save Layout',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _equipItem(User user, String docId, String category) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    final furnitureRef = firestore
        .collection('users')
        .doc(user.uid)
        .collection('furniture');

    final allItems = await furnitureRef.get();
    for (var doc in allItems.docs) {
      if (!kRoomThemes.containsKey(doc.id)) {
        batch.update(doc.reference, {'isEquipped': false});
      }
    }

    final defaultLocation = {'col': 0.5, 'row': 0.35};

    batch.set(furnitureRef.doc(docId), {
      'isEquipped': true,
      'category': category,
      'location': defaultLocation,
    }, SetOptions(merge: true));

    final userDoc = await firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final partnerEmail =
        ((userData['partnerEmailLower'] as String?) ??
                (userData['partnerEmail'] as String?) ??
                '')
            .trim()
            .toLowerCase();

    if (partnerEmail.isNotEmpty) {
      final partnerQuery = await firestore
          .collection('users')
          .where('email', isEqualTo: partnerEmail)
          .get();
      for (var pDoc in partnerQuery.docs) {
        final pFurnitureRef = pDoc.reference.collection('furniture');
        final pItems = await pFurnitureRef.get();
        for (var pItemDoc in pItems.docs) {
          if (!kRoomThemes.containsKey(pItemDoc.id)) {
            batch.update(pItemDoc.reference, {'isEquipped': false});
          }
        }
        batch.set(pFurnitureRef.doc(docId), {
          'isEquipped': true,
          'category': category,
          'location': defaultLocation,
        }, SetOptions(merge: true));
      }
    }

    await batch.commit();
  }

  double _clampFurnitureCol(String docId, double col) {
    final meta = getFurnitureMeta(docId);
    final maxGridX = (_RoomGeometry.floorColumns - meta.widthSquares).clamp(
      0,
      _RoomGeometry.floorColumns,
    );

    return _gridToNormalized(_normalizedToGrid(col).clamp(0, maxGridX));
  }

  double _clampFurnitureRow(String docId, double row) {
    final meta = getFurnitureMeta(docId);
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

  void _moveGridDirection(
    String currentDocId,
    int dCol,
    int dRow,
    List<QueryDocumentSnapshot> allDocs,
  ) {
    if (_editingCol == null || _editingRow == null) {
      return;
    }

    final meta = getFurnitureMeta(currentDocId);
    final currentGridX = _normalizedToGrid(_editingCol!);
    final currentGridY = _normalizedToGrid(_editingRow!);

    final maxGridX = (_RoomGeometry.floorColumns - meta.widthSquares).clamp(
      0,
      _RoomGeometry.floorColumns,
    );
    final maxGridY = (_RoomGeometry.floorColumns - meta.lengthSquares).clamp(
      0,
      _RoomGeometry.floorColumns,
    );

    final nextGridX = (currentGridX + dCol).clamp(0, maxGridX);
    final nextGridY = (currentGridY + dRow).clamp(0, maxGridY);

    if (nextGridX == currentGridX && nextGridY == currentGridY) {
      return;
    }

    final nextCol = _gridToNormalized(nextGridX);
    final nextRow = _gridToNormalized(nextGridY);

    // This editor currently renders one furniture item at a time.
    // Do NOT let other equipped-but-hidden Firestore items silently block
    // movement. That made arrow taps appear completely dead.
    setState(() {
      _editingCol = nextCol;
      _editingRow = nextRow;
    });
  }

  void _handleFurnitureDrag(
    String currentDocId,
    Offset delta,
    _RoomPerspective perspective,
  ) {
    if (_editingCol == null || _editingRow == null) return;

    final meta = getFurnitureMeta(currentDocId);
    final currentGridX = _normalizedToGrid(_editingCol!);
    final currentGridY = _normalizedToGrid(_editingRow!);

    _dragTargetGridX ??= currentGridX.toDouble();
    _dragTargetGridY ??= currentGridY.toDouble();

    // Resolve finger movement into the two diagonal perspective-grid axes.
    // Using the local axes at the current cell keeps the drag direction
    // visually aligned with the floor lines.
    final p = perspective.floorGridIntersection(
      currentGridX.toDouble(),
      currentGridY.toDouble(),
    );
    final px = perspective.floorGridIntersection(
      currentGridX + 1.0,
      currentGridY.toDouble(),
    );
    final py = perspective.floorGridIntersection(
      currentGridX.toDouble(),
      currentGridY + 1.0,
    );

    final axisX = px - p;
    final axisY = py - p;
    final det = axisX.dx * axisY.dy - axisX.dy * axisY.dx;
    if (det.abs() < 0.0001) return;

    final gridDeltaX = (delta.dx * axisY.dy - delta.dy * axisY.dx) / det;
    final gridDeltaY = (axisX.dx * delta.dy - axisX.dy * delta.dx) / det;

    // Continuous target: don't throw away sub-cell movement. This makes
    // slow drags precise instead of requiring repeated 40%-cell jumps.
    _dragTargetGridX = _dragTargetGridX! + gridDeltaX;
    _dragTargetGridY = _dragTargetGridY! + gridDeltaY;

    // Search the perspective grid around the finger target and choose the
    // closest cell whose ENTIRE furniture footprint still fits on the floor.
    int? bestX;
    int? bestY;
    double bestDistance = double.infinity;

    // The visible floor uses overflowing grid lines, so valid coordinates can
    // extend well outside 0..floorColumns near the bottom of the screen.
    const int overflow = 18;
    final minGrid = -overflow;
    final maxGrid = _RoomGeometry.floorColumns + overflow;

    final targetX = _dragTargetGridX!;
    final targetY = _dragTargetGridY!;

    for (int gx = minGrid; gx <= maxGrid; gx++) {
      for (int gy = minGrid; gy <= maxGrid; gy++) {
        if (!perspective.floorFootprintFits(
          gridX: gx,
          gridY: gy,
          widthSquares: meta.widthSquares,
          lengthSquares: meta.lengthSquares,
        )) {
          continue;
        }

        final dx = gx - targetX;
        final dy = gy - targetY;
        final distance = dx * dx + dy * dy;

        if (distance < bestDistance) {
          bestDistance = distance;
          bestX = gx;
          bestY = gy;
        }
      }
    }

    if (bestX == null || bestY == null) return;

    if (bestX == currentGridX && bestY == currentGridY) return;

    setState(() {
      _editingCol = _gridToNormalized(bestX!);
      _editingRow = _gridToNormalized(bestY!);
    });
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
                          final docId = prefix.isNotEmpty
                              ? '$prefix$variantKey'
                              : variantKey;
                          QueryDocumentSnapshot? matchDoc;
                          for (final doc in docs) {
                            if (doc.id == docId || doc.id == variantKey) {
                              matchDoc = doc;
                              break;
                            }
                          }

                          final data =
                              matchDoc?.data() as Map<String, dynamic>?;
                          final isEquipped =
                              (data?['isEquipped'] ?? false) == true;

                          catalogItems.add({
                            'docId': docId,
                            'doc': matchDoc,
                            'variantKey': variantKey,
                            'assetPath': assetPath,
                            'isEquipped': isEquipped,
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
                            final docId = itemInfo['docId'] as String;
                            final variantKey = itemInfo['variantKey'] as String;
                            final assetPath = itemInfo['assetPath'] as String;
                            final isEquipped = itemInfo['isEquipped'] as bool;
                            final targetDoc =
                                itemInfo['doc'] as QueryDocumentSnapshot?;
                            final itemTitle = _getItemTitle(
                              _selectedCategory,
                              variantKey,
                            );
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
                                    final dId = doc.id;
                                    if (!kRoomThemes.containsKey(dId)) {
                                      final belongsToCat = prefix.isNotEmpty
                                          ? dId.startsWith(prefix)
                                          : categoryAssets.containsKey(dId);
                                      if (belongsToCat) {
                                        batch.update(doc.reference, {
                                          'isEquipped': false,
                                        });
                                      }
                                    }
                                  }

                                  final defaultLocation = {
                                    'col': 0.5,
                                    'row': 0.35,
                                  };

                                  if (targetDoc != null) {
                                    batch.set(targetDoc.reference, {
                                      'isEquipped': true,
                                      'category': _selectedCategory,
                                      'location': defaultLocation,
                                    }, SetOptions(merge: true));
                                  } else {
                                    batch.set(
                                      furnitureRef.doc(docId),
                                      {
                                        'isEquipped': true,
                                        'category': _selectedCategory,
                                        'location': defaultLocation,
                                      },
                                      SetOptions(merge: true),
                                    );
                                  }

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
                                        final pId = pItemDoc.id;
                                        if (!kRoomThemes.containsKey(pId)) {
                                          final pBelongs = prefix.isNotEmpty
                                              ? pId.startsWith(prefix)
                                              : categoryAssets.containsKey(pId);
                                          if (pBelongs) {
                                            batch.update(pItemDoc.reference, {
                                              'isEquipped': false,
                                            });
                                          }
                                        }
                                      }
                                      batch.set(
                                        pFurnitureRef.doc(docId),
                                        {
                                          'isEquipped': true,
                                          'category': _selectedCategory,
                                          'location': defaultLocation,
                                        },
                                        SetOptions(merge: true),
                                      );
                                    }
                                  }

                                  await batch.commit();
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isEquipped
                                        ? cs.primary
                                        : cs.outlineVariant,
                                    width: isEquipped ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              color: cs.surfaceContainerHighest
                                                  .withValues(alpha: 0.3),
                                              child: const SizedBox.expand(),
                                            ),
                                            Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  6.0,
                                                ),
                                                child: Image.asset(
                                                  assetPath,
                                                  fit: BoxFit.contain,
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
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isEquipped
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (isEquipped)
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 16,
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
