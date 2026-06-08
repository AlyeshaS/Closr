import 'package:flutter/material.dart';
import '../../services/love_letter_service.dart';
import '../../models/love_letter.dart';

class ComposeLoveLetterPage extends StatefulWidget {
  final LoveLetter? editingLetter;
  const ComposeLoveLetterPage({super.key, this.editingLetter});

  @override
  State<ComposeLoveLetterPage> createState() => _ComposeLoveLetterPageState();
}

class _ComposeLoveLetterPageState extends State<ComposeLoveLetterPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();
  bool _sending = false;
  bool _canSend = false;
  bool _showHeart = false;
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
    // If editing, prefill
    if (widget.editingLetter != null) {
      _ctrl.text = widget.editingLetter!.text;
      _canSend = _ctrl.text.trim().isNotEmpty;
    }
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heartScale = Tween<double>(begin: 0.6, end: 1.25).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.elasticOut),
    );
    _heartOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _heartController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
  }

  void _onTextChanged() {
    final hasText = _ctrl.text.trim().isNotEmpty;
    if (hasText != _canSend) {
      setState(() => _canSend = hasText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Write a Love Letter'),
        centerTitle: true,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: 'Write something sweet...',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_sending || !_canSend) ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.editingLetter != null
                                ? 'Update Love Letter'
                                : 'Send Love Letter',
                          ),
                  ),
                ),
              ],
            ),
          ),

          // Heart animation overlay
          if (_showHeart)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _heartController,
                    builder: (context, child) => Opacity(
                      opacity: _heartOpacity.value,
                      child: Transform.scale(
                        scale: _heartScale.value,
                        child: child,
                      ),
                    ),
                    child: Icon(Icons.favorite, size: 120, color: cs.primary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      if (widget.editingLetter != null) {
        await LoveLetterService().updateLetter(widget.editingLetter!.id, text);
      } else {
        await LoveLetterService().sendLetter(text);
      }
      // play heart animation then pop
      if (!mounted) return;
      setState(() {
        _showHeart = true;
      });
      await _heartController.forward();
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _heartController.dispose();
    super.dispose();
  }
}
