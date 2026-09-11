part of '../tabs/home_page.dart';

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

  // Keep the visible wall grid and wall-mounted furniture below the very top
  // edge of the room. The walls themselves still extend to the ceiling.
  static const double wallGridTopCenterY = 0.075;
  static const double wallGridTopEdgeY = 0.105;

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
            roomRect.top + roomRect.height * _RoomGeometry.wallGridTopCenterY,
            roomRect.top + roomRect.height * _RoomGeometry.wallGridTopEdgeY,
            dt,
          )!
        : lerpDouble(
            roomRect.top + roomRect.height * _RoomGeometry.wallGridTopCenterY,
            roomRect.top + roomRect.height * _RoomGeometry.wallGridTopEdgeY,
            dt,
          )!;
    final y = lerpDouble(floorY, ceilingY, row.clamp(0.0, 1.0))!;
    final scale = lerpDouble(kMinDepthScale, 1.0, dt)!;
    return _RoomPoint(Offset(x, y), scale);
  }

  bool wallItemFits({
    required RoomSurface surface,
    required int gridX,
    required int gridY,
    required double itemWidth,
    required double itemHeight,
    required double rotation,
  }) {
    final col = gridX / _RoomGeometry.wallColumns;
    final row = gridY / _RoomGeometry.wallRows;
    final anchor = wallPoint(surface, col, row).anchor;

    // Wall movement should be controlled by the wall grid itself. The old
    // full-item bounds check rejected upper rows very early for taller PNGs,
    // which made it feel like the item could only move two squares up.
    // Keep the anchor inside the visible room; rendering separately clamps the
    // sprite so the image itself never leaves the screen.
    const edgeTolerance = 1.0;
    return anchor.dx >= roomRect.left - edgeTolerance &&
        anchor.dx <= roomRect.right + edgeTolerance &&
        anchor.dy >= roomRect.top - edgeTolerance &&
        anchor.dy <= roomRect.bottom + edgeTolerance;
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
  RoomSurface? _editingSurface;

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
  RoomSurface? _initialSurface;

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

  RoomSurface _surfaceForData(Map<String, dynamic> data, RoomSurface fallback) {
    switch (data['roomSurface'] as String?) {
      case 'leftWall':
        return RoomSurface.leftWall;
      case 'rightWall':
        return RoomSurface.rightWall;
      case 'floor':
        return RoomSurface.floor;
      default:
        return fallback;
    }
  }

  String _surfaceName(RoomSurface surface) {
    if (surface == RoomSurface.leftWall) return 'leftWall';
    if (surface == RoomSurface.rightWall) return 'rightWall';
    return 'floor';
  }

  double _visualRotationForFurniture(String itemKey) {
    if (itemKey == 'aquarium') return 0.0;
    if (itemKey.startsWith('sofa_') || kSofaAssets.containsKey(itemKey)) {
      return 0.0;
    }
    if (itemKey.startsWith('bed_') || kBedAssets.containsKey(itemKey)) {
      return 0.0;
    }
    if (itemKey.startsWith('desk_') || kDeskAssets.containsKey(itemKey)) {
      return 0.0;
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
    _editingSurface = null;
    _initialCol = null;
    _initialRow = null;
    _initialVisualScale = null;
    _initialVisualRotation = null;
    _initialFlipX = false;
    _initialFlipY = false;
    _initialLocked = false;
    _initialSurface = null;
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
    final selectedSurface = _surfaceForData(data, meta.surface);
    final location = data['location'] as Map<String, dynamic>?;
    final defaultRow = selectedSurface == RoomSurface.floor ? 0.35 : 0.5;

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
      _editingSurface = selectedSurface;

      _initialCol = col;
      _initialRow = row;
      _initialVisualScale = scale;
      _initialVisualRotation = rotation;
      _initialFlipX = flipX;
      _initialFlipY = flipY;
      _initialLocked = false;
      _initialSurface = selectedSurface;
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
        _editingSurface = _initialSurface;
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
      _editingSurface = _initialSurface;
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
      if (_editingSurface != null) {
        live['roomSurface'] = _surfaceName(_editingSurface!);
      }
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
      surface: _editingSurface,
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
        surface: _editingSurface,
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
                : (_editingSurface ??
                      _surfaceForData(
                        _docData(selectedDoc),
                        getFurnitureMeta(_itemKeyForDoc(selectedDoc)).surface,
                      ));

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
    final isSelected = widget.isEditing && _editingDocId == doc.id;
    final savedSurface = _surfaceForData(data, meta.surface);
    final surface = isSelected
        ? (_editingSurface ?? savedSurface)
        : savedSurface;
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

      // Use the same grid anchor for every floor item. Previously the render
      // anchor came from the centre/bottom of each item's width/length
      // footprint, which made wider furniture appear one cell farther from
      // the side walls than narrower furniture at the same grid coordinate.
      point = _RoomPoint(
        perspective.floorGridIntersection(gridX.toDouble(), gridY.toDouble()),
        1.0,
      );
    } else {
      point = perspective.pointFor(surface, col, row);
    }

    final rawLeft = point.anchor.dx - itemWidth / 2;
    final rawTop = isFloor
        ? point.anchor.dy - itemHeight
        : point.anchor.dy - itemHeight / 2;

    // Let wall items use the full wall grid, but keep the visible PNG inside
    // the room/screen. This does not alter the grid geometry.
    final left = isFloor
        ? rawLeft
        : rawLeft
              .clamp(
                perspective.roomRect.left,
                math.max(
                  perspective.roomRect.left,
                  perspective.roomRect.right - itemWidth,
                ),
              )
              .toDouble();
    final top = isFloor
        ? rawTop
        : rawTop
              .clamp(
                perspective.roomRect.top,
                math.max(
                  perspective.roomRect.top,
                  perspective.roomRect.bottom - itemHeight,
                ),
              )
              .toDouble();

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
              // Selection outline follows the PNG's visible alpha shape.
              // A denser 4 px silhouette halo keeps the selected item obvious
              // without falling back to a large rectangular selection box.
              if (isSelected)
                ...<Offset>[
                  const Offset(-4, 0),
                  const Offset(4, 0),
                  const Offset(0, -4),
                  const Offset(0, 4),
                  const Offset(-3, -3),
                  const Offset(3, -3),
                  const Offset(-3, 3),
                  const Offset(3, 3),
                  const Offset(-4, -1.5),
                  const Offset(-4, 1.5),
                  const Offset(4, -1.5),
                  const Offset(4, 1.5),
                  const Offset(-1.5, -4),
                  const Offset(1.5, -4),
                  const Offset(-1.5, 4),
                  const Offset(1.5, 4),
                ].map(
                  (outlineOffset) => Positioned.fill(
                    child: IgnorePointer(
                      child: Transform.translate(
                        offset: outlineOffset,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..scale(flipX ? -1.0 : 1.0, flipY ? -1.0 : 1.0),
                          child: Transform.rotate(
                            angle: visualRotation,
                            alignment: Alignment.bottomCenter,
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                widget.colorScheme.primary,
                                BlendMode.srcIn,
                              ),
                              child: Image.asset(
                                meta.assetPath,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
      'roomSurface': _surfaceName(meta.surface),
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
      _editingSurface = meta.surface;

      _initialCol = col;
      _initialRow = row;
      _initialVisualScale = scale;
      _initialVisualRotation = rotation;
      _initialFlipX = false;
      _initialFlipY = false;
      _initialSurface = meta.surface;
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
    final isFloor = meta.surface == RoomSurface.floor;
    final gridLimit = isFloor
        ? _RoomGeometry.floorGridDepth
        : _RoomGeometry.wallColumns;
    final maxGridX = gridLimit;
    final grid = _surfaceColToGrid(meta.surface, col).clamp(0, maxGridX);
    return _surfaceColToNormalized(meta.surface, grid);
  }

  double _clampFurnitureRow(String itemKey, double row) {
    final meta = getFurnitureMeta(itemKey);
    final isFloor = meta.surface == RoomSurface.floor;
    final gridLimit = isFloor
        ? _RoomGeometry.floorGridDepth
        : _RoomGeometry.wallRows;
    // Wall items can use the full vertical wall grid. Screen bounds are
    // enforced during movement instead of reserving rows based on item size.
    final maxGridY = gridLimit;
    final grid = _surfaceRowToGrid(meta.surface, row).clamp(0, maxGridY);
    return _surfaceRowToNormalized(meta.surface, grid);
  }

  int _normalizedToGrid(double value) {
    return (value * _RoomGeometry.floorColumns).round();
  }

  double _gridToNormalized(int value) {
    return value / _RoomGeometry.floorColumns;
  }

  int _surfaceColToGrid(RoomSurface surface, double value) {
    final columns = surface == RoomSurface.floor
        ? _RoomGeometry.floorColumns
        : _RoomGeometry.wallColumns;
    return (value * columns).round();
  }

  int _surfaceRowToGrid(RoomSurface surface, double value) {
    final rows = surface == RoomSurface.floor
        ? _RoomGeometry.floorColumns
        : _RoomGeometry.wallRows;
    return (value * rows).round();
  }

  double _surfaceColToNormalized(RoomSurface surface, int value) {
    final columns = surface == RoomSurface.floor
        ? _RoomGeometry.floorColumns
        : _RoomGeometry.wallColumns;
    return value / columns;
  }

  double _surfaceRowToNormalized(RoomSurface surface, int value) {
    final rows = surface == RoomSurface.floor
        ? _RoomGeometry.floorColumns
        : _RoomGeometry.wallRows;
    return value / rows;
  }

  void _handleFurnitureDrag(
    String itemKey,
    Offset delta,
    _RoomPerspective perspective,
  ) {
    if (_editingCol == null || _editingRow == null) return;

    final meta = getFurnitureMeta(itemKey);
    final surface = _editingSurface ?? meta.surface;
    final isFloor = surface == RoomSurface.floor;
    final currentGridX = _surfaceColToGrid(surface, _editingCol!);
    final currentGridY = _surfaceRowToGrid(surface, _editingRow!);

    final canvasDelta = delta / widget.canvasScale;

    // Join the floor grid to the wall grids at their shared seams.
    // Floor (x, 0) maps directly to the left wall's x column and
    // floor (0, y) maps directly to the right wall's y column.
    if (isFloor && canvasDelta.dy < 0) {
      RoomSurface? wallSurface;
      int wallColumn = 0;

      if (currentGridY == 0 && currentGridX > 0) {
        wallSurface = RoomSurface.leftWall;
        wallColumn = currentGridX.clamp(0, _RoomGeometry.wallColumns).toInt();
      } else if (currentGridX == 0 && currentGridY > 0) {
        wallSurface = RoomSurface.rightWall;
        wallColumn = currentGridY.clamp(0, _RoomGeometry.wallColumns).toInt();
      } else if (currentGridX == 0 && currentGridY == 0) {
        wallSurface = canvasDelta.dx < 0
            ? RoomSurface.leftWall
            : RoomSurface.rightWall;
        wallColumn = 0;
      }

      if (wallSurface != null) {
        setState(() {
          _editingSurface = wallSurface;
          _editingCol = _surfaceColToNormalized(wallSurface!, wallColumn);
          _editingRow = 0.0;
          _accumulatedDragX = 0.0;
          _accumulatedDragY = 0.0;
        });
        return;
      }
    }

    // Dragging down from the bottom wall row returns the item to the exact
    // corresponding floor seam cell.
    if (!isFloor && currentGridY == 0 && canvasDelta.dy > 0) {
      final floorGridX = surface == RoomSurface.leftWall ? currentGridX : 0;
      final floorGridY = surface == RoomSurface.rightWall ? currentGridX : 0;
      setState(() {
        _editingSurface = RoomSurface.floor;
        _editingCol = _surfaceColToNormalized(RoomSurface.floor, floorGridX);
        _editingRow = _surfaceRowToNormalized(RoomSurface.floor, floorGridY);
        _accumulatedDragX = 0.0;
        _accumulatedDragY = 0.0;
      });
      return;
    }

    late final Offset p0;
    late final Offset px;
    late final Offset py;

    if (isFloor) {
      p0 = perspective.floorGridIntersection(
        currentGridX.toDouble(),
        currentGridY.toDouble(),
      );
      px = perspective.floorGridIntersection(
        (currentGridX + 1.0).toDouble(),
        currentGridY.toDouble(),
      );
      py = perspective.floorGridIntersection(
        currentGridX.toDouble(),
        (currentGridY + 1.0).toDouble(),
      );
    } else {
      // Wall movement follows the original 8-column Ã— 14-row grid.
      // The visual grid stays unchanged; upper rows remain fully reachable.
      final col0 = currentGridX / _RoomGeometry.wallColumns;
      final row0 = currentGridY / _RoomGeometry.wallRows;
      final col1 = (currentGridX + 1.0) / _RoomGeometry.wallColumns;
      final row1 = (currentGridY + 1.0) / _RoomGeometry.wallRows;
      p0 = perspective.wallPoint(surface, col0, row0).anchor;
      px = perspective.wallPoint(surface, col1, row0).anchor;
      py = perspective.wallPoint(surface, col0, row1).anchor;
    }

    final stepX = px - p0;
    final stepY = py - p0;
    final det = stepX.dx * stepY.dy - stepX.dy * stepY.dx;
    if (det.abs() < 0.0001) return;

    _accumulatedDragX += canvasDelta.dx;
    _accumulatedDragY += canvasDelta.dy;

    final dGridX =
        (_accumulatedDragX * stepY.dy - _accumulatedDragY * stepY.dx) / det;
    final dGridY =
        (stepX.dx * _accumulatedDragY - stepX.dy * _accumulatedDragX) / det;

    if (dGridX.abs() >= 0.5 || dGridY.abs() >= 0.5) {
      // round() makes the first half-cell crossing feel responsive and avoids
      // the old 0.5-to-0.99 dead zone caused by floor().
      final stepMoveX = dGridX.abs() >= 0.5 ? dGridX.round() : 0;
      final stepMoveY = dGridY.abs() >= 0.5 ? dGridY.round() : 0;

      if (stepMoveX != 0 || stepMoveY != 0) {
        final maxGridX = isFloor
            ? _RoomGeometry.floorGridDepth
            : _RoomGeometry.wallColumns;
        final maxGridY = isFloor
            ? _RoomGeometry.floorGridDepth
            : _RoomGeometry.wallRows;

        final targetGridX = (currentGridX + stepMoveX)
            .clamp(0, maxGridX)
            .toInt();
        final targetGridY = (currentGridY + stepMoveY)
            .clamp(0, maxGridY)
            .toInt();

        final currentVisualScale = _editingVisualScale ?? 1.0;
        final targetFits = isFloor
            ? perspective.floorFootprintFits(
                gridX: targetGridX,
                gridY: targetGridY,
                widthSquares: meta.widthSquares,
                lengthSquares: meta.lengthSquares,
                visualScale: currentVisualScale,
              )
            : perspective.wallItemFits(
                surface: surface,
                gridX: targetGridX,
                gridY: targetGridY,
                itemWidth:
                    _RoomCanvas.furnitureSquarePixels *
                    meta.widthSquares *
                    currentVisualScale,
                itemHeight:
                    _RoomCanvas.furnitureSquarePixels *
                    meta.lengthSquares *
                    currentVisualScale,
                rotation: _editingVisualRotation ?? 0.0,
              );

        if (targetFits &&
            (targetGridX != currentGridX || targetGridY != currentGridY)) {
          setState(() {
            _editingCol = _surfaceColToNormalized(surface, targetGridX);
            _editingRow = _surfaceRowToNormalized(surface, targetGridY);
            _editingSurface = surface;
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
    RoomSurface? surface,
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
      if (surface != null) 'roomSurface': _surfaceName(surface),
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
        _p(size, _RoomGeometry.centerX, _RoomGeometry.wallGridTopCenterY),
        _p(size, _RoomGeometry.leftX, _RoomGeometry.wallGridTopEdgeY),
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
        _p(size, _RoomGeometry.centerX, _RoomGeometry.wallGridTopCenterY),
        _p(size, _RoomGeometry.centerX, _RoomGeometry.floorCornerY),
        t,
      )!;
      final outer = Offset.lerp(
        _p(size, _RoomGeometry.leftX, _RoomGeometry.wallGridTopEdgeY),
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
        _p(size, _RoomGeometry.centerX, _RoomGeometry.wallGridTopCenterY),
        _p(size, _RoomGeometry.rightX, _RoomGeometry.wallGridTopEdgeY),
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
        _p(size, _RoomGeometry.centerX, _RoomGeometry.wallGridTopCenterY),
        _p(size, _RoomGeometry.centerX, _RoomGeometry.floorCornerY),
        t,
      )!;
      final outer = Offset.lerp(
        _p(size, _RoomGeometry.rightX, _RoomGeometry.wallGridTopEdgeY),
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
