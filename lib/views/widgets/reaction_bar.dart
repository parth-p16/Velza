import 'package:flutter/material.dart';

class ReactionBar extends StatelessWidget {
  final String? currentReaction;
  final ValueChanged<String> onSelectEmoji;

  static const List<String> defaultEmojis = ['❤️', '👍', '😂', '😮', '😢', '😡'];

  const ReactionBar({
    super.key,
    this.currentReaction,
    required this.onSelectEmoji,
  });

  static Future<void> show({
    required BuildContext context,
    String? currentReaction,
    required ValueChanged<String> onSelectEmoji,
  }) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: ReactionBar(
            currentReaction: currentReaction,
            onSelectEmoji: (emoji) {
              Navigator.pop(ctx);
              onSelectEmoji(emoji);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F162E) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: defaultEmojis.map((emoji) {
          final isSelected = currentReaction == emoji;
          return GestureDetector(
            onTap: () => onSelectEmoji(emoji),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD4AF37).withValues(alpha: 0.25) : Colors.transparent,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: const Color(0xFFD4AF37), width: 1.5)
                    : null,
              ),
              child: Text(
                emoji,
                style: TextStyle(
                  fontSize: isSelected ? 28 : 24,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
