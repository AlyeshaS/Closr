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
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _textController;

  bool _isSaving = false;
  late final AnimationController _heartController;
  final List<_FloatingHeart> _hearts = [];
  final _random = math.Random();

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
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _saveLetter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? '';

      // Determine existing values or defaults
      final String docId = widget.editingLetter?.id.isNotEmpty == true
          ? widget.editingLetter!.id
          : FirebaseFirestore.instance.collection('love_letters').doc().id;

      final String recipientId = widget.editingLetter?.recipientId ?? '';

      final letterData = LoveLetter(
        id: docId,
        senderId: widget.editingLetter?.senderId ?? uid,
        recipientId: recipientId,
        title: _titleController.text.trim(),
        text: _textController.text.trim(),
        createdAt: widget.editingLetter?.createdAt ?? DateTime.now(),
      );

      // Directly writing to Firestore to bypass any service method discrepancies!
      await FirebaseFirestore.instance
          .collection('love_letters')
          .doc(docId)
          .set(letterData.toMap(), SetOptions(merge: true));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to deliver your letter: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: cs.primary.withOpacity(0.35),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: cs.primary.withOpacity(0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Icon(
                                    Icons.favorite_outline_rounded,
                                    size: 24,
                                    color: cs.primary.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _titleController,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Letter Title',
                                    labelStyle: TextStyle(
                                      color: cs.primary.withOpacity(0.8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    hintText:
                                        'Give your letter a sweet title...',
                                    hintStyle: TextStyle(
                                      color: cs.onSurfaceVariant.withOpacity(
                                        0.4,
                                      ),
                                      fontSize: 15,
                                    ),
                                    border: InputBorder.none,
                                    prefixIcon: Icon(
                                      Icons.edit_note_rounded,
                                      color: cs.primary,
                                      size: 20,
                                    ),
                                  ),
                                  validator: (val) =>
                                      val == null || val.trim().isEmpty
                                      ? 'Please add a title'
                                      : null,
                                ),
                                Divider(
                                  color: cs.primary.withOpacity(0.2),
                                  thickness: 1.0,
                                ),
                                const SizedBox(height: 8),

                                TextFormField(
                                  controller: _textController,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.6,
                                    color: cs.onSurface.withOpacity(0.85),
                                  ),
                                  maxLines: null,
                                  minLines: 8,
                                  keyboardType: TextInputType.multiline,
                                  decoration: InputDecoration(
                                    hintText: 'Pour your heart out here...',
                                    hintStyle: TextStyle(
                                      color: cs.onSurfaceVariant.withOpacity(
                                        0.4,
                                      ),
                                      fontWeight: FontWeight.w300,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  validator: (val) =>
                                      val == null || val.trim().isEmpty
                                      ? 'Write down some sweet thoughts'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator()
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
                            icon: const Icon(Icons.favorite_rounded, size: 18),
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
                ),
              ],
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
