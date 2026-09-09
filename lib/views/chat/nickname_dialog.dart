import 'package:flutter/material.dart';

class NicknameDialog extends StatefulWidget {
  final String targetUid;
  final String originalName;
  final String currentNickname;
  final Future<void> Function(String newNickname) onSave;
  final Future<void> Function()? onRemove;

  const NicknameDialog({
    super.key,
    required this.targetUid,
    required this.originalName,
    required this.currentNickname,
    required this.onSave,
    this.onRemove,
  });

  static Future<void> show(
    BuildContext context, {
    required String targetUid,
    required String originalName,
    required String currentNickname,
    required Future<void> Function(String newNickname) onSave,
    Future<void> Function()? onRemove,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => NicknameDialog(
        targetUid: targetUid,
        originalName: originalName,
        currentNickname: currentNickname,
        onSave: onSave,
        onRemove: onRemove,
      ),
    );
  }

  @override
  State<NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<NicknameDialog> {
  late TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentNickname);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E162B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.badge_rounded, color: Color(0xFFD4AF37)),
          SizedBox(width: 10),
          Text('Set Nickname', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This nickname is private to you and only visible on your device.',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(
            'Original profile name: ${widget.originalName}',
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFFD4AF37)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Enter custom nickname...',
              filled: true,
              fillColor: isDark ? const Color(0xFF0E0B16) : Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _controller.clear();
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        if (widget.currentNickname.isNotEmpty && widget.onRemove != null)
          TextButton(
            onPressed: _isSaving
                ? null
                : () async {
                    final nav = Navigator.of(context);
                    setState(() => _isSaving = true);
                    await widget.onRemove!();
                    if (mounted) nav.pop();
                  },
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
          ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6A1B9A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isSaving
              ? null
              : () async {
                  final nav = Navigator.of(context);
                  setState(() => _isSaving = true);
                  await widget.onSave(_controller.text.trim());
                  if (mounted) nav.pop();
                },
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
