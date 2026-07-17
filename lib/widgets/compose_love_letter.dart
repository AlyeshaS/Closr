import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../../../models/love_letter.dart';

class ComposeLoveLetterPage extends StatefulWidget {
  final LoveLetter? editingLetter;
  const ComposeLoveLetterPage({this.editingLetter, super.key});

  @override
  State<ComposeLoveLetterPage> createState() => _ComposeLoveLetterPageState();
}

class _ComposeLoveLetterPageState extends State<ComposeLoveLetterPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _textController;

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _textFocusNode = FocusNode();

  bool _isSaving = false;

  // Typing background hearts
  late final AnimationController _heartController;
  final List<_FloatingHeart> _hearts = [];
  final _random = math.Random();

  // Send animation controller
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

    // Flying animation configuration
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

    // Forces the heart to fly completely past the top of the screen (-1.6)
    _heartYAnimation = Tween<double>(begin: 0.1, end: -1.6).animate(
      CurvedAnimation(parent: _sendAnimController, curve: Curves.easeInCubic),
    );

    // Smoothly dissolves/fades out as it approaches the top
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

  Future<void> _saveLetter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _showSendAnimation = true;
    });

    // Fire flying heart animation
    await _sendAnimController.forward();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? '';

      // 1. Fetch current user's profile to retrieve their shared couple group/connection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists || userDoc.data() == null) {
        throw Exception("User profile not found.");
      }

      final String myEmail =
          (userDoc.data()?['emailLower'] ?? user?.email ?? '')
              .toString()
              .trim()
              .toLowerCase();
      final String partnerEmail =
          (userDoc.data()?['partnerEmailLower'] ??
                  userDoc.data()?['partnerEmail'] ??
                  '')
              .toString()
              .trim()
              .toLowerCase();

      if (myEmail.isEmpty || partnerEmail.isEmpty) {
        throw Exception("You must be connected by email to send love letters!");
      }

      final List<String> coupleEmails = [myEmail, partnerEmail]..sort();
      final String coupleGroupId = '${coupleEmails[0]}_${coupleEmails[1]}';

      // 2. Determine recipient's actual UID
      String recipientId = widget.editingLetter?.recipientId ?? '';
      if (recipientId.isEmpty && partnerEmail.isNotEmpty) {
        // Look up the partner's UID based on their email
        final partnerQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('emailLower', isEqualTo: partnerEmail)
            .limit(1)
            .get();

        if (partnerQuery.docs.isNotEmpty) {
          recipientId = partnerQuery.docs.first.id;
        } else {
          final partnerQueryFallback = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: partnerEmail)
              .limit(1)
              .get();

          if (partnerQueryFallback.docs.isNotEmpty) {
            recipientId = partnerQueryFallback.docs.first.id;
          }
        }
      }

      // 3. Set up the reference nested under the couple's document path
      final CollectionReference lettersRef = FirebaseFirestore.instance
          .collection('couples')
          .doc(coupleGroupId)
          .collection('love_letters');

      final String docId = widget.editingLetter?.id.isNotEmpty == true
          ? widget.editingLetter!.id
          : lettersRef.doc().id;

      final letterData = LoveLetter(
        id: docId,
        senderId: widget.editingLetter?.senderId ?? uid,
        recipientId: recipientId,
        title: _titleController.text.trim(),
        text: _textController.text.trim(),
        createdAt: widget.editingLetter?.createdAt ?? DateTime.now(),
      );

      // Write to the nested subcollection path
      await lettersRef
          .doc(docId)
          .set(letterData.toMap(), SetOptions(merge: true));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isSaving = false;
        _showSendAnimation = false;
      });
      _sendAnimController.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to deliver your letter: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          widget.editingLetter != null ? 'Edit Love Letter' : 'Write a Letter',
          style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: cs.onSurface,
      ),
      body: Stack(
        children: [
          // Typing floating background hearts
          ..._hearts.map((heart) {
            return Align(
              alignment: Alignment(heart.xOffset, 1.0 - (heart.progress * 1.5)),
              child: Opacity(
                opacity: (1.0 - heart.progress).clamp(0.0, 1.0),
                child: Icon(
                  Icons.favorite_rounded,
                  color: cs.primary.withOpacity(0.25),
                  size: heart.size,
                ),
              ),
            );
          }),

          // Main interactive fields card
          SafeArea(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: cs.primary.withOpacity(0.35),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withOpacity(0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Icon(
                                Icons.favorite_rounded,
                                size: 26,
                                color: cs.primary.withOpacity(0.85),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 1. Title Container (Dynamic focus border)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _titleFocusNode.hasFocus
                                      ? cs.primary
                                      : cs.primary.withOpacity(0.5),
                                  width: 1.3,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: TextFormField(
                                controller: _titleController,
                                focusNode: _titleFocusNode,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Letter Title',
                                  labelStyle: TextStyle(
                                    color: cs.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  hintText: 'Give your letter a sweet title...',
                                  hintStyle: TextStyle(
                                    color: cs.onSurfaceVariant.withOpacity(0.4),
                                    fontSize: 14,
                                  ),
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.only(right: 4.0),
                                    child: Icon(
                                      Icons.edit_note_rounded,
                                      color: cs.primary,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                    ? 'Please add a title'
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 2. Open Typing Container (No nesting backgrounds, full height touch support)
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _textFocusNode.hasFocus
                                        ? cs.primary
                                        : cs.primary.withOpacity(0.5),
                                    width: 1.3,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: TextFormField(
                                  controller: _textController,
                                  focusNode: _textFocusNode,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.6,
                                    color: cs.onSurface.withOpacity(0.85),
                                  ),
                                  maxLines: null,
                                  expands: true,
                                  keyboardType: TextInputType.multiline,
                                  textAlignVertical: TextAlignVertical.top,
                                  decoration: InputDecoration(
                                    hintText: 'Pour your heart out here...',
                                    hintStyle: TextStyle(
                                      color: cs.onSurfaceVariant.withOpacity(
                                        0.4,
                                      ),
                                      fontWeight: FontWeight.w300,
                                    ),
                                    filled: false,
                                    fillColor: Colors.transparent,
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  validator: (val) =>
                                      val == null || val.trim().isEmpty
                                      ? 'Write down some sweet thoughts'
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                                elevation: 2,
                              ),
                              icon: const Icon(
                                Icons.favorite_rounded,
                                size: 18,
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

          // Flying Heart Dispatch Animation
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
