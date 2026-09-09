import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:velza/models/message_model.dart';
import 'package:velza/services/e2ee_service.dart';

class MessageSearchDialog extends StatefulWidget {
  final String chatId;
  final String currentUid;
  final String otherUserName;
  final List<MessageModel> activeMessages;

  const MessageSearchDialog({
    super.key,
    required this.chatId,
    required this.currentUid,
    required this.otherUserName,
    required this.activeMessages,
  });

  static Future<String?> show(
    BuildContext context, {
    required String chatId,
    required String currentUid,
    required String otherUserName,
    required List<MessageModel> activeMessages,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E162B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MessageSearchDialog(
        chatId: chatId,
        currentUid: currentUid,
        otherUserName: otherUserName,
        activeMessages: activeMessages,
      ),
    );
  }

  @override
  State<MessageSearchDialog> createState() => _MessageSearchDialogState();
}

class _MessageSearchDialogState extends State<MessageSearchDialog> {
  final TextEditingController _queryController = TextEditingController();
  DateTimeRange? _dateRange;
  String _senderFilter = 'all'; // 'all', 'me', 'other'
  TimeOfDay? _selectedTime;
  List<MessageModel> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    setState(() {
      _isSearching = true;
    });

    final query = _queryController.text.trim().toLowerCase();

    // 1. Search locally cached active messages first (decrypting if needed)
    final matched = <MessageModel>[];
    for (final msg in widget.activeMessages) {
      if (msg.isEncrypted || E2eeService.isPayloadEncrypted(msg.text)) {
        final otherUid = msg.senderId == widget.currentUid
            ? widget.chatId.replaceAll(widget.currentUid, '').replaceAll('_', '')
            : msg.senderId;
        await E2eeService().decryptMessage(
          chatId: widget.chatId,
          otherUid: otherUid,
          payload: msg.text,
        );
      }
      if (_matchesFilters(msg, query)) {
        matched.add(msg);
      }
    }

    // 2. If fewer than 20 results, run a targeted Firestore query with limit 50
    if (matched.length < 20) {
      try {
        Query q = FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(50);

        if (_dateRange != null) {
          q = q
              .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(_dateRange!.start))
              .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(_dateRange!.end.add(const Duration(days: 1))));
        }

        final snap = await q.get();
        for (final doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final msg = MessageModel.fromMap(data);
          if (msg.isEncrypted || E2eeService.isPayloadEncrypted(msg.text)) {
            final otherUid = msg.senderId == widget.currentUid
                ? widget.chatId.replaceAll(widget.currentUid, '').replaceAll('_', '')
                : msg.senderId;
            await E2eeService().decryptMessage(
              chatId: widget.chatId,
              otherUid: otherUid,
              payload: msg.text,
            );
          }
          if (!matched.any((m) => m.id == msg.id) && _matchesFilters(msg, query)) {
            matched.add(msg);
          }
        }
      } catch (e) {
        debugPrint('[MessageSearch] Targeted query warning: $e');
      }
    }

    matched.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (mounted) {
      setState(() {
        _searchResults = matched;
        _isSearching = false;
      });
    }
  }

  bool _matchesFilters(MessageModel msg, String query) {
    if (msg.deleted || msg.deletedForEveryone) return false;

    // Sender Filter
    if (_senderFilter == 'me' && msg.senderId != widget.currentUid) return false;
    if (_senderFilter == 'other' && msg.senderId == widget.currentUid) return false;

    // Date Range Filter
    if (_dateRange != null) {
      if (msg.timestamp.isBefore(_dateRange!.start) ||
          msg.timestamp.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
        return false;
      }
    }

    // Time Filter (within ~1.5 hours of selected time)
    if (_selectedTime != null) {
      final msgMinute = msg.timestamp.hour * 60 + msg.timestamp.minute;
      final targetMinute = _selectedTime!.hour * 60 + _selectedTime!.minute;
      if ((msgMinute - targetMinute).abs() > 90) return false;
    }

    // Query String Filter
    if (query.isNotEmpty) {
      if (msg.type == MessageType.gift && !msg.isGiftOpened) {
        // Gift message plaintext is confidential until unlocked
        if (!'surprise message'.contains(query) && !'gift'.contains(query)) {
          return false;
        }
      } else {
        String effectiveText = msg.text;
        if (msg.isEncrypted || E2eeService.isPayloadEncrypted(msg.text)) {
          effectiveText = E2eeService().getCachedDecrypted(msg.text) ?? '';
        }
        final textMatches = effectiveText.toLowerCase().contains(query);
        final fileMatches = msg.fileName.toLowerCase().contains(query);
        if (!textMatches && !fileMatches) return false;
      }
    }

    return true;
  }

  void _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD4AF37),
              onPrimary: Colors.black,
              surface: Color(0xFF1E162B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
      _performSearch();
    }
  }

  void _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
      _performSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: Color(0xFFD4AF37), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Search in Conversation',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: TextField(
              controller: _queryController,
              autofocus: true,
              onChanged: (_) => _performSearch(),
              decoration: InputDecoration(
                hintText: 'Search keyword, phrase...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _queryController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _queryController.clear();
                          _performSearch();
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF261D35) : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filters Row (Date range, Time, Sender)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                // Date Range Chip
                FilterChip(
                  label: Text(
                    _dateRange == null
                        ? 'Date Range'
                        : '${DateFormat('d MMM').format(_dateRange!.start)} - ${DateFormat('d MMM').format(_dateRange!.end)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _dateRange != null ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: _dateRange != null ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: _dateRange != null,
                  selectedColor: const Color(0xFFD4AF37),
                  onSelected: (_) => _pickDateRange(),
                  avatar: Icon(Icons.date_range_rounded, size: 16, color: _dateRange != null ? Colors.black : Colors.grey),
                ),
                if (_dateRange != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () {
                      setState(() => _dateRange = null);
                      _performSearch();
                    },
                  ),
                ],
                const SizedBox(width: 8),

                // Time Filter Chip
                FilterChip(
                  label: Text(
                    _selectedTime == null ? 'Time' : _selectedTime!.format(context),
                    style: TextStyle(
                      fontSize: 12,
                      color: _selectedTime != null ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: _selectedTime != null ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: _selectedTime != null,
                  selectedColor: const Color(0xFFD4AF37),
                  onSelected: (_) => _pickTime(),
                  avatar: Icon(Icons.access_time_rounded, size: 16, color: _selectedTime != null ? Colors.black : Colors.grey),
                ),
                if (_selectedTime != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () {
                      setState(() => _selectedTime = null);
                      _performSearch();
                    },
                  ),
                ],
                const SizedBox(width: 8),

                // Sender Segmented Filter
                ChoiceChip(
                  label: const Text('All', style: TextStyle(fontSize: 12)),
                  selected: _senderFilter == 'all',
                  selectedColor: const Color(0xFF6A1B9A),
                  onSelected: (_) {
                    setState(() => _senderFilter = 'all');
                    _performSearch();
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Me', style: TextStyle(fontSize: 12)),
                  selected: _senderFilter == 'me',
                  selectedColor: const Color(0xFF6A1B9A),
                  onSelected: (_) {
                    setState(() => _senderFilter = 'me');
                    _performSearch();
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(widget.otherUserName, style: const TextStyle(fontSize: 12)),
                  selected: _senderFilter == 'other',
                  selectedColor: const Color(0xFF6A1B9A),
                  onSelected: (_) {
                    setState(() => _senderFilter = 'other');
                    _performSearch();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 12),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                Text(
                  '${_searchResults.length} message${_searchResults.length == 1 ? '' : 's'} found',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                if (_isSearching) ...[
                  const SizedBox(width: 12),
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ],
            ),
          ),

          // Search Results List
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade600),
                        const SizedBox(height: 8),
                        Text(
                          'No matching messages found',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final msg = _searchResults[index];
                      final isMe = msg.senderId == widget.currentUid;
                      final senderTitle = isMe ? 'You' : widget.otherUserName;
                      final dateStr = DateFormat('d MMM yyyy, h:mm a').format(msg.timestamp);

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: isMe ? const Color(0xFF6A1B9A) : const Color(0xFFD4AF37),
                          child: Icon(
                            isMe ? Icons.person_rounded : Icons.chat_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              senderTitle,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Spacer(),
                            Text(
                              dateStr,
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 3.0),
                          child: Text(
                            msg.type == MessageType.gift && !msg.isGiftOpened
                                ? '🎁 Surprise Message (Locked)'
                                : (msg.isEncrypted || E2eeService.isPayloadEncrypted(msg.text)
                                    ? (E2eeService().getCachedDecrypted(msg.text) ?? '🔒 Encrypted message')
                                    : (msg.text.isNotEmpty ? msg.text : '[Attachment]')),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 13,
                              fontStyle: msg.type == MessageType.gift && !msg.isGiftOpened
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context, msg.id);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
