import 'package:flutter/material.dart';
import '../models/love_letter.dart';
import '../tabs/connect/love_letter_detail.dart';

class LoveLetterTile extends StatelessWidget {
  final LoveLetter letter;
  final VoidCallback? onTap;
  final bool isSent;

  const LoveLetterTile({
    required this.letter,
    this.onTap,
    this.isSent = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accentColor = isSent ? cs.secondary : cs.primary;
    final cardColor = theme.cardTheme.color ?? cs.surface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            onTap ??
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LoveLetterDetailPage(letter: letter),
              ),
            ),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: cs.outlineVariant.withOpacity(0.14),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primaryContainer,
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Icon(
                      isSent ? Icons.send_rounded : Icons.inbox_rounded,
                      size: 18,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSent ? 'Sent letter' : 'Received letter',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(letter.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                letter.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    // simple MM/DD or if older show yyyy
    final now = DateTime.now();
    if (dt.year == now.year) {
      return '${dt.month}/${dt.day}';
    }
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
