import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/love_letter.dart';
import '../../../services/love_letter_service.dart';

class LoveLetterDetailPage extends StatefulWidget {
  final LoveLetter letter;
  const LoveLetterDetailPage({required this.letter, super.key});

  @override
  State<LoveLetterDetailPage> createState() => _LoveLetterDetailPageState();
}

class _LoveLetterDetailPageState extends State<LoveLetterDetailPage>
    with SingleTickerProviderStateMixin {
  final LoveLetterService _loveLetterService = LoveLetterService();
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _deleteLetter() async {
    setState(() => _isDeleting = true);

    try {
      await _loveLetterService.deleteLoveLetter(widget.letter.id);

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentUser = FirebaseAuth.instance.currentUser;
    final bool isSender = widget.letter.senderId == currentUser?.uid;

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
          if (isSender)
            _isDeleting
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text(
                            'Delete Letter?',
                            style: TextStyle(fontFamily: 'serif'),
                          ),
                          content: const Text(
                            'Are you sure you want to unsend and permanently delete this keepsake?',
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
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.redAccent),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFCFBF7),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Positioned(
                      right: -24,
                      bottom: -24,
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 160,
                        color: cs.primary.withOpacity(0.015),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(26.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatFullDate(widget.letter.createdAt),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: cs.onSurfaceVariant.withOpacity(
                                        0.5,
                                      ),
                                      fontFamily: 'serif',
                                    ),
                              ),
                              Icon(
                                Icons.favorite_rounded,
                                color: cs.primary.withOpacity(0.4),
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.letter.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface.withOpacity(0.9),
                                  fontFamily: 'serif',
                                ),
                          ),
                          const SizedBox(height: 12),
                          Divider(
                            color: cs.primary.withOpacity(0.12),
                            thickness: 1.0,
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Text(
                                widget.letter.text,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      height: 1.7,
                                      color: cs.onSurface.withOpacity(0.8),
                                      fontFamily: 'serif',
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatFullDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
