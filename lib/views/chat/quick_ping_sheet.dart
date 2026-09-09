import 'package:flutter/material.dart';

class QuickPingOption {
  final String emoji;
  final String label;
  final Color color;

  const QuickPingOption({
    required this.emoji,
    required this.label,
    required this.color,
  });
}

class QuickPingSheet extends StatelessWidget {
  final void Function(String emoji, String label) onSelectPing;

  const QuickPingSheet({super.key, required this.onSelectPing});

  static const List<QuickPingOption> options = [
    QuickPingOption(emoji: '❤️', label: 'Thinking of you', color: Color(0xFFE91E63)),
    QuickPingOption(emoji: '👋', label: 'Wave', color: Color(0xFF2196F3)),
    QuickPingOption(emoji: '🔥', label: 'Fire', color: Color(0xFFFF9800)),
    QuickPingOption(emoji: '😂', label: 'Laugh', color: Color(0xFFFFC107)),
    QuickPingOption(emoji: '✨', label: 'Magic', color: Color(0xFF9C27B0)),
    QuickPingOption(emoji: '☕', label: 'Coffee break', color: Color(0xFF795548)),
  ];

  static void show(BuildContext context, {required void Function(String emoji, String label) onSelectPing}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E162B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => QuickPingSheet(onSelectPing: onSelectPing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Row(
              children: [
                Icon(Icons.flash_on_rounded, color: Color(0xFFD4AF37), size: 22),
                SizedBox(width: 8),
                Text(
                  'Quick Ping',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Send an instant lightweight interaction card',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                final opt = options[index];
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    onSelectPing(opt.emoji, opt.label);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF261D35) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: opt.color.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(opt.emoji, style: const TextStyle(fontSize: 32)),
                        const SizedBox(height: 6),
                        Text(
                          opt.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
