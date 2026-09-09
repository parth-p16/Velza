import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeCapsuleDialog extends StatefulWidget {
  final void Function(String text, DateTime scheduledTime, {bool isGift}) onScheduleMessage;

  const TimeCapsuleDialog({super.key, required this.onScheduleMessage});

  static void show(
    BuildContext context, {
    required void Function(String text, DateTime scheduledTime, {bool isGift}) onScheduleMessage,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E162B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TimeCapsuleDialog(onScheduleMessage: onScheduleMessage),
    );
  }

  @override
  State<TimeCapsuleDialog> createState() => _TimeCapsuleDialogState();
}

class _TimeCapsuleDialogState extends State<TimeCapsuleDialog> {
  final TextEditingController _textController = TextEditingController();
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 2));
  TimeOfDay _scheduledTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 2)));
  bool _isGiftMode = true;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _scheduledDate = picked;
      });
    }
  }

  void _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (picked != null) {
      setState(() {
        _scheduledTime = picked;
      });
    }
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message to schedule')),
      );
      return;
    }

    final scheduledDateTime = DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _scheduledTime.hour,
      _scheduledTime.minute,
    );

    if (scheduledDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a future date and time')),
      );
      return;
    }

    Navigator.pop(context);
    widget.onScheduleMessage(text, scheduledDateTime, isGift: _isGiftMode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 16.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
      ),
      child: SingleChildScrollView(
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

            // Mode Selector
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF261D35) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _isGiftMode = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isGiftMode ? const Color(0xFF6A1B9A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🎁', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(
                                'Gift Message',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isGiftMode ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _isGiftMode = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isGiftMode ? const Color(0xFF6A1B9A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.hourglass_top_rounded, size: 16, color: Color(0xFFD4AF37)),
                              const SizedBox(width: 6),
                              Text(
                                'Time Capsule',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: !_isGiftMode ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Row(
              children: [
                Icon(
                  _isGiftMode ? Icons.card_giftcard_rounded : Icons.hourglass_top_rounded,
                  color: const Color(0xFFD4AF37),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  _isGiftMode ? 'Secret Gift Message 🎁' : 'Time Capsule Message',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _isGiftMode
                  ? 'Send a surprise card that stays sealed until the designated reveal time'
                  : 'Schedule a message to be automatically delivered in the future',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Message text input
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _isGiftMode
                    ? 'Write your confidential surprise note or letter...'
                    : 'Type your future message...',
                filled: true,
                fillColor: isDark ? const Color(0xFF261D35) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date and Time selectors
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFFD4AF37)),
                    label: Text(
                      DateFormat('d MMM yyyy').format(_scheduledDate),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    ),
                    onPressed: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFFD4AF37)),
                    label: Text(
                      _scheduledTime.format(context),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    ),
                    onPressed: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isGiftMode ? const Color(0xFFD4AF37) : const Color(0xFF6A1B9A),
                  foregroundColor: _isGiftMode ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _submit,
                child: Text(
                  _isGiftMode ? 'Seal & Send Gift 🎁' : 'Schedule Message',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
