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

  Future<void> _saveLetter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _showSendAnimation = true;
    });

    await _sendAnimController.forward();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? '';

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

      String recipientId = widget.editingLetter?.recipientId ?? '';
      if (recipientId.isEmpty && partnerEmail.isNotEmpty) {
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
      // Soft, matching base background for a clean, non-glary palette
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
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Typing floating background hearts (softened down to sit gracefully in the back)
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

                          // 1. Completely Borderless & Background-free Title Input
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
                              // Removing default backgrounds and borders completely
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

                          // A beautiful, highly reactive subtle line under the title
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 1,
                            width: double.infinity,
                            color: _titleFocusNode.hasFocus
                                ? cs.primary.withOpacity(0.4)
                                : cs.primary.withOpacity(0.12),
                          ),
                          const SizedBox(height: 20),

                          // 2. Open, Floating Text Area with absolutely zero containment styling
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
                                // Ensure absolutely zero focus borders or filled backgrounds appear
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

                    // Sticky action button at the base
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
                                elevation:
                                    3.0, // Increased slightly for a noticeable, elegant lift
                                shadowColor: cs.primary.withOpacity(
                                  0.3,
                                ), // Soft colored shadow
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

          // Sending flying heart layout
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
