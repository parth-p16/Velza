import 'dart:async';
import 'package:flutter/material.dart';
import 'package:velza/models/message_model.dart';
import 'package:velza/models/sticker_model.dart';
import 'package:velza/services/audio_service.dart';
import 'package:velza/models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:velza/views/chat/sticker_panel.dart';
import 'package:velza/services/e2ee_service.dart';

class ChatComposer extends StatefulWidget {
  final String chatId;
  final String currentUid;
  final String currentName;
  final MessageModel? replyingToMessage;
  final MessageModel? editingMessage;
  final AudioService audioService;
  final void Function(String text, {List<String>? mentionedUserIds, Map<String, String>? mentions}) onSendText;
  final void Function(AudioRecordResult result, int duration) onSendVoice;
  final void Function(VelzaSticker sticker)? onSendSticker;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelEdit;
  final VoidCallback onAttachmentTap;
  final void Function(String status) onTypingStatusChanged;
  final List<UserModel> mentionableUsers;

  const ChatComposer({
    super.key,
    required this.chatId,
    required this.currentUid,
    required this.currentName,
    this.replyingToMessage,
    this.editingMessage,
    required this.audioService,
    required this.onSendText,
    required this.onSendVoice,
    this.onSendSticker,
    required this.onCancelReply,
    required this.onCancelEdit,
    required this.onAttachmentTap,
    required this.onTypingStatusChanged,
    this.mentionableUsers = const [],
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final TextEditingController _textController = TextEditingController();
  bool _hasText = false;
  bool _isTyping = false;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  Timer? _typingDebounceTimer;

  bool _showMentionSuggestions = false;
  String _mentionQuery = '';
  int _mentionStartIndex = -1;
  final List<String> _mentionedUserIds = [];
  final Map<String, String> _mentionsMap = {};

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    if (widget.editingMessage != null) {
      _textController.text = widget.editingMessage!.text;
    }
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingMessage != null && widget.editingMessage != oldWidget.editingMessage) {
      final msg = widget.editingMessage!;
      final clearText = (msg.isEncrypted || E2eeService.isPayloadEncrypted(msg.text))
          ? (E2eeService().getCachedDecrypted(msg.text) ?? msg.text)
          : msg.text;
      _textController.text = clearText;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    } else if (widget.editingMessage == null && oldWidget.editingMessage != null) {
      _textController.clear();
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _typingDebounceTimer?.cancel();
    if (_isTyping) {
      widget.onTypingStatusChanged('none');
    }
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasNonEmpty = _textController.text.trim().isNotEmpty;
    if (hasNonEmpty != _hasText) {
      setState(() {
        _hasText = hasNonEmpty;
      });
    }

    // Mention detection
    final text = _textController.text;
    final selection = _textController.selection;
    if (selection.baseOffset > 0 && selection.baseOffset <= text.length) {
      final beforeCursor = text.substring(0, selection.baseOffset);
      final atIndex = beforeCursor.lastIndexOf('@');
      if (atIndex != -1 && (atIndex == 0 || beforeCursor[atIndex - 1] == ' ' || beforeCursor[atIndex - 1] == '\n')) {
        final query = beforeCursor.substring(atIndex + 1);
        if (!query.contains(' ') && query.length <= 25) {
          setState(() {
            _mentionQuery = query.toLowerCase();
            _mentionStartIndex = atIndex;
            _showMentionSuggestions = true;
          });
        } else if (_showMentionSuggestions) {
          setState(() {
            _showMentionSuggestions = false;
          });
        }
      } else if (_showMentionSuggestions) {
        setState(() {
          _showMentionSuggestions = false;
        });
      }
    } else if (_showMentionSuggestions) {
      setState(() {
        _showMentionSuggestions = false;
      });
    }

    if (hasNonEmpty) {
      if (!_isTyping) {
        _isTyping = true;
        widget.onTypingStatusChanged('typing');
      }
      // Reset debounce timer to auto-expire typing after 2.5s of inactivity
      _typingDebounceTimer?.cancel();
      _typingDebounceTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted && _isTyping) {
          _isTyping = false;
          widget.onTypingStatusChanged('none');
        }
      });
    } else if (!hasNonEmpty && _isTyping) {
      _typingDebounceTimer?.cancel();
      _isTyping = false;
      widget.onTypingStatusChanged('none');
    }
  }

  void _selectMention(UserModel user) {
    final text = _textController.text;
    final selection = _textController.selection;
    if (_mentionStartIndex != -1 && _mentionStartIndex <= text.length) {
      final before = text.substring(0, _mentionStartIndex);
      final after = (selection.baseOffset <= text.length && selection.baseOffset >= 0)
          ? text.substring(selection.baseOffset)
          : '';
      final replacement = '@${user.displayName} ';
      final newText = '$before$replacement$after';
      _textController.text = newText;
      _textController.selection = TextSelection.collapsed(offset: before.length + replacement.length);
      if (!_mentionedUserIds.contains(user.uid)) {
        _mentionedUserIds.add(user.uid);
      }
      _mentionsMap[user.uid] = user.displayName;
    }
    setState(() {
      _showMentionSuggestions = false;
    });
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _typingDebounceTimer?.cancel();
    _textController.clear();
    setState(() {
      _hasText = false;
      _showMentionSuggestions = false;
    });
    _isTyping = false;
    widget.onTypingStatusChanged('none');
    widget.onSendText(
      text,
      mentionedUserIds: List<String>.from(_mentionedUserIds),
      mentions: Map<String, String>.from(_mentionsMap),
    );
    _mentionedUserIds.clear();
    _mentionsMap.clear();
  }

  Future<void> _startRecording() async {
    final hasPermission = await widget.audioService.checkPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required to record audio.')),
      );
      return;
    }

    try {
      await widget.audioService.startRecording();
      widget.onTypingStatusChanged('recording');
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _recordingSeconds++;
        });
      });
    } catch (e) {
      debugPrint('Error starting voice recording: $e');
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    await widget.audioService.cancelRecording();
    widget.onTypingStatusChanged('none');
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
  }

  Future<void> _sendRecording() async {
    _recordingTimer?.cancel();
    final duration = _recordingSeconds;
    widget.onTypingStatusChanged('none');
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });

    final AudioRecordResult? result = await widget.audioService.stopRecording();
    if (result != null && result.file.existsSync()) {
      widget.onSendVoice(result, duration > 0 ? duration : result.durationSeconds);
    }
  }

  String _formatTimer(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _getMessageSummary(MessageModel msg) {
    if (msg.type == MessageType.image) return '📷 Photo';
    if (msg.type == MessageType.video) return '🎥 Video';
    if (msg.type == MessageType.audio) return '🎤 Voice message';
    if (msg.type == MessageType.document) {
      return '📄 ${msg.fileName.isNotEmpty ? msg.fileName : "Document"}';
    }
    if (msg.isEncrypted || E2eeService.isPayloadEncrypted(msg.text)) {
      return E2eeService().getCachedDecrypted(msg.text) ?? '🔒 Encrypted message';
    }
    return msg.text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final suggestions = _showMentionSuggestions
        ? widget.mentionableUsers.where((u) {
            if (u.uid == widget.currentUid) return false;
            if (_mentionQuery.isEmpty) return true;
            return u.displayName.toLowerCase().contains(_mentionQuery) ||
                u.searchableName.toLowerCase().contains(_mentionQuery);
          }).toList()
        : <UserModel>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mention Suggestions Overlay
        if (_showMentionSuggestions && suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E162B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 50),
              itemBuilder: (context, index) {
                final user = suggestions[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundImage: user.photoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(user.photoUrl)
                        : null,
                    child: user.photoUrl.isEmpty ? const Icon(Icons.person, size: 16) : null,
                  ),
                  title: Text(
                    user.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    '@${user.searchableName.isNotEmpty ? user.searchableName : user.displayName.toLowerCase().replaceAll(' ', '')}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFD4AF37)),
                  ),
                  onTap: () => _selectMention(user),
                );
              },
            ),
          ),
        // Quoted Reply Preview Bar
        if (widget.replyingToMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: isDark ? const Color(0xFF261D36) : const Color(0xFFF1EBF9),
            child: Row(
              children: [
                Container(width: 4, height: 36, color: const Color(0xFFD4AF37)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Replying to ${widget.replyingToMessage!.senderName}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                      Text(
                        _getMessageSummary(widget.replyingToMessage!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: widget.onCancelReply,
                ),
              ],
            ),
          ),

        // Edit Message Preview Bar
        if (widget.editingMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: isDark ? const Color(0xFF2E2042) : const Color(0xFFEDE7F6),
            child: Row(
              children: [
                Container(width: 4, height: 36, color: const Color(0xFF9C27B0)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Editing Message',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9C27B0),
                        ),
                      ),
                      Text(
                        (widget.editingMessage!.isEncrypted || E2eeService.isPayloadEncrypted(widget.editingMessage!.text))
                            ? (E2eeService().getCachedDecrypted(widget.editingMessage!.text) ?? '🔒 Encrypted message')
                            : widget.editingMessage!.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    _textController.clear();
                    widget.onCancelEdit();
                  },
                ),
              ],
            ),
          ),

        // Composer input panel
        SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E162B) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: _isRecording
                // Voice recording state
                ? Row(
                    children: [
                      const SizedBox(width: 8),
                      const Icon(Icons.fiber_manual_record_rounded, color: Colors.redAccent, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimer(_recordingSeconds),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.redAccent,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                        label: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                        onPressed: _cancelRecording,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF6A1B9A),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white),
                          onPressed: _sendRecording,
                        ),
                      ),
                    ],
                  )
                // Standard text / attachment / mic state
                : Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.sticky_note_2_outlined, color: Color(0xFFD4AF37), size: 26),
                        tooltip: 'Stickers',
                        onPressed: () {
                          StickerPanel.show(
                            context: context,
                            onSelectSticker: (sticker) {
                              widget.onSendSticker?.call(sticker);
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFD4AF37), size: 28),
                        onPressed: widget.onAttachmentTap,
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0E0B16) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _textController,
                            minLines: 1,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: widget.editingMessage != null ? 'Edit message...' : 'Type a message...',
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                        child: _hasText
                            ? Container(
                                key: const ValueKey('send_button'),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF6A1B9A),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    widget.editingMessage != null ? Icons.check_rounded : Icons.send_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: _handleSend,
                                ),
                              )
                            : GestureDetector(
                                key: const ValueKey('mic_button'),
                                onLongPress: _startRecording,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF6A1B9A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.mic_none_rounded, color: Colors.white),
                                    onPressed: _startRecording,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
