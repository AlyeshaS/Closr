import 'package:flutter/material.dart';
import '../../../models/love_letter.dart';

class LoveLetterDetailPage extends StatefulWidget {
  final LoveLetter letter;
  const LoveLetterDetailPage({required this.letter, super.key});

  @override
  State<LoveLetterDetailPage> createState() => _LoveLetterDetailPageState();
}

class _LoveLetterDetailPageState extends State<LoveLetterDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text(
          'A Keepsake',
          style: TextStyle(fontWeight: FontWeight.w400, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: cs.onSurface,
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
                color: cs.primaryContainer.withOpacity(0.45),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: cs.primary.withOpacity(0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    Positioned(
                      right: -24,
                      bottom: -24,
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 160,
                        color: cs.primary.withOpacity(0.035),
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
                                        0.6,
                                      ),
                                    ),
                              ),
                              Icon(
                                Icons.favorite_rounded,
                                color: cs.primary,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          Text(
                            widget.letter.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                          ),
                          const SizedBox(height: 10),

                          Divider(
                            color: cs.primary.withOpacity(0.18),
                            thickness: 1.0,
                          ),
                          const SizedBox(height: 12),

                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Text(
                                widget.letter.text,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      height: 1.6,
                                      color: cs.onSurface.withOpacity(0.8),
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
