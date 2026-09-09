import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool isMe;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.isMe = false,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  static const double _triggerThreshold = 50.0;
  static const double _maxDragOffset = 75.0;
  bool _thresholdVibrated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    // Only allow swiping to the right (WhatsApp standard swipe-to-reply)
    if (details.delta.dx < 0 && _dragOffset <= 0) return;

    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, _maxDragOffset);
      if (_dragOffset >= _triggerThreshold && !_thresholdVibrated) {
        _thresholdVibrated = true;
        HapticFeedback.lightImpact();
      } else if (_dragOffset < _triggerThreshold) {
        _thresholdVibrated = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset >= _triggerThreshold) {
      widget.onReply();
    }

    _thresholdVibrated = false;
    _animation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _dragOffset = _animation.value;
        });
      });

    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragOffset / _triggerThreshold).clamp(0.0, 1.0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        // Reply icon revealed behind the swiping message
        if (_dragOffset > 5.0)
          Positioned(
            left: 12.0 + (_dragOffset * 0.25),
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.6 + (0.4 * progress),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _dragOffset >= _triggerThreshold
                        ? const Color(0xFFD4AF37) // Velza Gold when ready to trigger
                        : (isDark ? const Color(0xFF6A1B9A) : const Color(0xFF7B1FA2)),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.reply_rounded,
                    size: 20,
                    color: _dragOffset >= _triggerThreshold ? Colors.black87 : Colors.white,
                  ),
                ),
              ),
            ),
          ),

        // Message bubble translated horizontally
        GestureDetector(
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
