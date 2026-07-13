import 'package:flutter/material.dart';
import '../models/love_letter.dart';
import '../tabs/connect/love_letter_detail.dart';

class LoveLetterTile extends StatelessWidget {
  final LoveLetter letter;
  final bool isSent;
  final VoidCallback onTap;

  const LoveLetterTile({
    required this.letter,
    required this.isSent,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.015),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Accent Indicator Bar
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.6),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        bottomLeft: Radius.circular(24),
                      ),
                    ),
                  ),

                  // Card Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: cs.primaryContainer.withOpacity(
                                        0.4,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSent
                                          ? Icons.outbox_rounded
                                          : Icons.all_inbox_rounded,
                                      size: 14,
                                      color: cs.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _formatDate(letter.createdAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: cs.onSurfaceVariant
                                              .withOpacity(0.8),
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.3,
                                        ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: cs.onSurfaceVariant.withOpacity(0.35),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            letter.text,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: cs.onSurface.withOpacity(0.8),
                                  height: 1.5,
                                  letterSpacing: 0.1,
                                ),
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
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
