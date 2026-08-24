import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../models/love_letter.dart';
import '../../../services/love_letter_service.dart';

class ComposeLoveLetterPage extends StatefulWidget {
  final LoveLetter? editingLetter;
  const ComposeLoveLetterPage({this.editingLetter, super.key});

  @override
  State<ComposeLoveLetterPage> createState() => _ComposeLoveLetterPageState();
}

class _ComposeLoveLetterPageState extends State<ComposeLoveLetterPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final LoveLetterService _loveLetterService = LoveLetterService();
  late final TextEditingController _titleController;
  late final TextEditingController _textController;

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _textFocusNode = FocusNode();

  bool _isSaving = false;
  bool _isDeleting = false;

  late final AnimationController _heartController;
  final List<_FloatingHeart> _hearts = [];
  final _random = math.Random();

  late final AnimationController _sendAnimController;
  late final Animation<double> _heartScaleAnimation;
  late final Animation<double> _heartYAnimation;
  late final Animation<double> _heartFadeAnimation;
  bool _showSendAnimation = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.editingLetter?.title ?? '',
    );
    _textController = TextEditingController(
      text: widget.editingLetter?.text ?? '',
    );

    _heartController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2000),
        )..addListener(() {
          setState(() {
            _hearts.removeWhere((heart) => heart.progress >= 1.0);
            for (var heart in _hearts) {
              heart.update();
            }
          });
        });

    _textController.addListener(_onTypeLetter);

    _titleFocusNode.addListener(() => setState(() {}));
    _textFocusNode.addListener(() => setState(() {}));

    _sendAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.4,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.4,
          end: 0.4,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 70,
      ),
    ]).animate(_sendAnimController);

    _heartYAnimation = Tween<double>(begin: 0.1, end: -1.6).animate(
      CurvedAnimation(parent: _sendAnimController, curve: Curves.easeInCubic),
    );

    _heartFadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_sendAnimController);
  }

  void _onTypeLetter() {
    if (_textController.text.isNotEmpty && _random.nextDouble() < 0.15) {
      setState(() {
        _hearts.add(
          _FloatingHeart(
            xOffset: _random.nextDouble() * 1.6 - 0.8,
            size: 12 + _random.nextDouble() * 14,
          ),
        );
      });
      if (!_heartController.isAnimating) {
        _heartController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    _titleFocusNode.dispose();
    _textFocusNode.dispose();
    _heartController.dispose();
    _sendAnimController.dispose();
    super.dispose();
  }

  Future<void> _deleteLetter() async {
    if (widget.editingLetter == null) return;

    setState(() => _isDeleting = true);

    try {
      await _loveLetterService.deleteLoveLetter(widget.editingLetter!.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Letter deleted successfully.')),
        );
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete letter: $e')));
      }
    }
  }

  Future<void> _saveLetter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _showSendAnimation = true;
    });

    await _sendAnimController.forward();

    try {
      await _loveLetterService.sendLoveLetter(
        letterId: widget.editingLetter?.id,
        title: _titleController.text.trim(),
        text: _textController.text.trim(),
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isSaving = false;
        _showSendAnimation = false;
      });
      _sendAnimController.reset();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to deliver your letter: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: cs.primary,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                'Return to letters',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (widget.editingLetter != null)
            _isDeleting
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: cs.primary,
                      size: 22,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text(
                            'Delete Letter?',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          content: const Text(
                            'Are you sure you want to permanently delete this keepsake? This cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _deleteLetter();
                              },
                              child: Text(
                                'Delete',
                                style: TextStyle(
                                  color: cs.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          const SizedBox(width: 8),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ..._hearts.map((heart) {
            return Align(
              alignment: Alignment(heart.xOffset, 1.0 - (heart.progress * 1.5)),
              child: Opacity(
                opacity: (1.0 - heart.progress).clamp(0.0, 1.0),
                child: Icon(
                  Icons.favorite_rounded,
                  color: cs.primary.withOpacity(0.15),
                  size: heart.size,
                ),
              ),
            );
          }),

          SafeArea(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _titleController,
                            focusNode: _titleFocusNode,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Give your letter a sweet title...',
                              hintStyle: TextStyle(
                                color: cs.onSurfaceVariant.withOpacity(0.35),
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                              ),
                              filled: false,
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? 'Please add a title'
                                : null,
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 1,
                            width: double.infinity,
                            color: _titleFocusNode.hasFocus
                                ? cs.primary.withOpacity(0.4)
                                : cs.primary.withOpacity(0.12),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: TextFormField(
                              controller: _textController,
                              focusNode: _textFocusNode,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.7,
                                color: cs.onSurface.withOpacity(0.85),
                              ),
                              maxLines: null,
                              expands: true,
                              keyboardType: TextInputType.multiline,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: InputDecoration(
                                hintText: 'Pour your heart out here...',
                                hintStyle: TextStyle(
                                  color: cs.onSurfaceVariant.withOpacity(0.35),
                                  fontWeight: FontWeight.w300,
                                ),
                                filled: false,
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                  ? 'Write down some sweet thoughts'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _isSaving
                        ? const SizedBox(
                            height: 52,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _saveLetter,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.primary,
                                foregroundColor: cs.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                elevation: 4.0,
                                shadowColor: cs.primary.withOpacity(0.4),
                              ),
                              icon: const Icon(
                                Icons.favorite_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'Seal & Send',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),

          if (_showSendAnimation)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _sendAnimController,
                builder: (context, child) {
                  return Align(
                    alignment: Alignment(0.0, _heartYAnimation.value),
                    child: FadeTransition(
                      opacity: _heartFadeAnimation,
                      child: Transform.scale(
                        scale: _heartScaleAnimation.value,
                        child: Icon(
                          Icons.favorite_rounded,
                          color: cs.primary,
                          size: 120,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FloatingHeart {
  final double xOffset;
  final double size;
  double progress = 0.0;

  _FloatingHeart({required this.xOffset, required this.size});

  void update() {
    progress += 0.012;
  }
}
