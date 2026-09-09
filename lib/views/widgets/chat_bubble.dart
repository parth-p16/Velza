import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:velza/models/message_model.dart';
import 'package:velza/models/sticker_model.dart';
import 'package:velza/services/audio_service.dart';
import 'package:velza/viewmodels/settings_viewmodel.dart';
import 'package:velza/views/widgets/swipe_to_reply.dart';
import 'package:velza/views/widgets/reaction_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:velza/views/widgets/media_viewer.dart';
import 'package:velza/services/e2ee_service.dart';

class ChatBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final String currentUserId;
  final String? otherUserId;
  final AudioService audioService;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleteForMe;
  final VoidCallback? onDeleteForEveryone;
  final void Function(String emoji)? onReact;
  final bool isHighlighted;
  final void Function(String replyToMessageId)? onQuotedMessageTap;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelect;
  final VoidCallback? onRetry;
  final void Function(String optionText)? onVotePoll;
  final VoidCallback? onPlaylistTap;
  final VoidCallback? onOpenGift;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.currentUserId = '',
    this.otherUserId,
    required this.audioService,
    this.onReply,
    this.onEdit,
    this.onDeleteForMe,
    this.onDeleteForEveryone,
    this.onReact,
    this.isHighlighted = false,
    this.onQuotedMessageTap,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.onSelect,
    this.onRetry,
    this.onVotePoll,
    this.onPlaylistTap,
    this.onOpenGift,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.message.type == MessageType.audio) {
      widget.audioService.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        final isThisUrl = widget.audioService.currentlyPlayingUrl == widget.message.url;
        setState(() {
          _isPlaying = state == PlayerState.playing && isThisUrl;
          if (!_isPlaying && state == PlayerState.stopped) {
            _playbackProgress = 0.0;
          }
        });
      });

      widget.audioService.onDurationChanged.listen((d) {
        if (!mounted) return;
        if (widget.audioService.currentlyPlayingUrl == widget.message.url) {
          setState(() {
            _duration = d;
          });
        }
      });

      widget.audioService.onPositionChanged.listen((p) {
        if (!mounted) return;
        if (widget.audioService.currentlyPlayingUrl == widget.message.url) {
          setState(() {
            _position = p;
            _playbackProgress = _duration.inMilliseconds > 0
                ? p.inMilliseconds / _duration.inMilliseconds
                : 0.0;
          });
        }
      });

      widget.audioService.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _playbackProgress = 0.0;
          _position = Duration.zero;
        });
      });
    }
  }

  void _handleAudioPlay() async {
    if (_isPlaying) {
      await widget.audioService.pauseAudio();
    } else {
      await widget.audioService.playAudio(widget.message.url);
    }
  }

  String _formatAudioDuration(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showContextMenu(BuildContext context) {
    final isDeleted = widget.message.deleted || widget.message.deletedForEveryone;
    final bool isOwn = widget.isMe || (widget.currentUserId.isNotEmpty && widget.message.senderId == widget.currentUserId);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E162B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji Reaction Bar
              if (!isDeleted && widget.onReact != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ReactionBar(
                    currentReaction: widget.message.reactions[widget.currentUserId],
                    onSelectEmoji: (emoji) {
                      Navigator.pop(ctx);
                      widget.onReact!(emoji);
                    },
                  ),
                ),

              // Reply action
              if (!isDeleted && widget.onReply != null)
                ListTile(
                  leading: const Icon(Icons.reply_rounded, color: Color(0xFFD4AF37)),
                  title: const Text('Reply', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onReply!();
                  },
                ),

              // Copy action (text messages)
              if (!isDeleted && widget.message.type == MessageType.text)
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: Color(0xFFD4AF37)),
                  title: const Text('Copy Text', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    final textToCopy = (widget.message.isEncrypted || E2eeService.isPayloadEncrypted(widget.message.text))
                        ? (E2eeService().getCachedDecrypted(widget.message.text) ?? widget.message.text)
                        : widget.message.text;
                    Clipboard.setData(ClipboardData(text: textToCopy));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),

              // Edit action (only own text messages, not deleted)
              if (!isDeleted && isOwn && widget.message.type == MessageType.text && widget.onEdit != null)
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: Color(0xFFD4AF37)),
                  title: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onEdit!();
                  },
                ),

              // Select action
              if (widget.onSelect != null)
                ListTile(
                  leading: const Icon(Icons.checklist_rounded, color: Color(0xFF6A1B9A)),
                  title: const Text('Select', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onSelect!();
                  },
                ),

              // Delete action
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmDialog(context, isOwn);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, bool isOwn) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E162B)
            : Colors.white,
        title: const Text('Delete message?'),
        content: Text(
          isOwn && !widget.message.deletedForEveryone
              ? 'You can delete this message for everyone or just for yourself.'
              : 'Delete this message from your chat history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (widget.onDeleteForMe != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onDeleteForMe!();
              },
              child: const Text('Delete for me'),
            ),
          if (isOwn && !widget.message.deletedForEveryone && widget.onDeleteForEveryone != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onDeleteForEveryone!();
              },
              child: const Text('Delete for everyone', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // Quoted reply banner inside the bubble
  Widget _buildReplyQuote(bool isDark) {
    if (widget.message.replyToMessageId == null) return const SizedBox.shrink();

    final quoteWidget = Container(
      margin: const EdgeInsets.only(bottom: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.black.withValues(alpha: 0.2)
            : (isDark ? Colors.black26 : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFFD4AF37), width: 3.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message.replyToSenderName ?? 'Reply',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD4AF37),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.message.replyToText ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: widget.isMe ? Colors.white70 : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );

    if (widget.onQuotedMessageTap != null) {
      return InkWell(
        onTap: () => widget.onQuotedMessageTap!(widget.message.replyToMessageId!),
        borderRadius: BorderRadius.circular(8),
        child: quoteWidget,
      );
    }
    return quoteWidget;
  }

  Widget _buildMessageContent(ThemeData theme, bool isDark, SettingsViewModel settingsVM) {
    // 1. Deleted Message Placeholder
    if (widget.message.deleted || widget.message.deletedForEveryone) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block_flipped,
            size: 16,
            color: widget.isMe ? Colors.white60 : (isDark ? Colors.white54 : Colors.black45),
          ),
          const SizedBox(width: 6),
          Text(
            'This message was deleted',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 14,
              color: widget.isMe ? Colors.white60 : (isDark ? Colors.white54 : Colors.black45),
            ),
          ),
        ],
      );
    }

    // 2. Message Types
    switch (widget.message.type) {
      case MessageType.text:
        final rawText = widget.message.text;
        if (widget.message.isEncrypted || E2eeService.isPayloadEncrypted(rawText)) {
          final cached = E2eeService().getCachedDecrypted(rawText);
          if (cached != null) {
            return _buildHighlightedText(cached, isDark, settingsVM);
          }
          final resolvedOtherUid = widget.otherUserId != null && widget.otherUserId!.isNotEmpty
              ? widget.otherUserId!
              : (widget.message.senderId == widget.currentUserId
                  ? widget.message.chatId.replaceAll(widget.currentUserId, '').replaceAll('_', '')
                  : widget.message.senderId);

          return FutureBuilder<String>(
            future: E2eeService().decryptMessage(
              chatId: widget.message.chatId,
              otherUid: resolvedOtherUid,
              payload: rawText,
            ),
            builder: (context, snapshot) {
              final text = snapshot.data ?? '🔒 Encrypted message';
              return _buildHighlightedText(text, isDark, settingsVM);
            },
          );
        }
        return _buildHighlightedText(rawText, isDark, settingsVM);

      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                if (widget.message.url.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImageViewerScreen(imageUrl: widget.message.url),
                    ),
                  );
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: widget.message.url,
                  placeholder: (context, url) => Container(
                    width: 220,
                    height: 200,
                    color: Colors.black12,
                    child: const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 220,
                    height: 150,
                    color: Colors.black12,
                    child: const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                  ),
                  fit: BoxFit.cover,
                  width: 230,
                  height: 230,
                ),
              ),
            ),
            if (widget.message.text.isNotEmpty && widget.message.text != 'image message') ...[
              const SizedBox(height: 6),
              Text(
                widget.message.text,
                style: TextStyle(
                  color: widget.isMe ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  fontSize: settingsVM.chatFontSizeValue - 1,
                  fontFamily: settingsVM.chatFontFamily,
                ),
              ),
            ],
          ],
        );

      case MessageType.video:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                if (widget.message.url.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerModal(videoUrl: widget.message.url),
                    ),
                  );
                }
              },
              child: Container(
                width: 230,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.videocam_rounded, size: 54, color: Colors.white24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF6A1B9A),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.white),
                    ),
                    const Positioned(
                      bottom: 8,
                      right: 8,
                      child: Row(
                        children: [
                          Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 14),
                          SizedBox(width: 4),
                          Text('Watch Video', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.message.text.isNotEmpty && widget.message.text != 'video message') ...[
              const SizedBox(height: 6),
              Text(
                widget.message.text,
                style: TextStyle(
                  color: widget.isMe ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  fontSize: settingsVM.chatFontSizeValue - 1,
                  fontFamily: settingsVM.chatFontFamily,
                ),
              ),
            ],
          ],
        );

      case MessageType.audio:
        final durationText = _isPlaying
            ? '${_formatAudioDuration(_position.inSeconds)} / ${_formatAudioDuration(_duration.inSeconds)}'
            : (widget.message.audioDuration > 0
                ? _formatAudioDuration(widget.message.audioDuration)
                : 'Voice note');

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                color: widget.isMe ? const Color(0xFFD4AF37) : const Color(0xFF6A1B9A),
                size: 38,
              ),
              onPressed: _handleAudioPlay,
            ),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: LinearProgressIndicator(
                    value: _playbackProgress,
                    backgroundColor: widget.isMe ? Colors.white30 : Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.isMe ? const Color(0xFFD4AF37) : const Color(0xFF6A1B9A),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  durationText,
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isMe ? Colors.white70 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        );

      case MessageType.document:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_rounded,
              color: widget.isMe ? const Color(0xFFD4AF37) : const Color(0xFF6A1B9A),
              size: 30,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.message.fileName.isNotEmpty ? widget.message.fileName : 'Document',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.isMe ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  fontFamily: settingsVM.chatFontFamily,
                ),
              ),
            ),
          ],
        );

      case MessageType.sticker:
        final sticker = StickerService.findById(widget.message.stickerId ?? '');
        final isNetwork = widget.message.url.startsWith('http');
        final isLocal = (widget.message.url.startsWith('/') || widget.message.url.contains('\\'));
        final isUsableLocal = isLocal && widget.isMe && File(widget.message.url).existsSync();

        Widget stickerContent;
        if (isNetwork) {
          stickerContent = ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: widget.message.url,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 120,
                height: 120,
                color: isDark ? const Color(0xFF1E162B) : Colors.black12,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37))),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A1B9A), Color(0xFFD4AF37)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.palette_rounded, color: Colors.white, size: 36),
                      SizedBox(height: 4),
                      Text('Sticker', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (isUsableLocal) {
          stickerContent = ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(widget.message.url),
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 120,
                height: 120,
                color: Colors.black26,
                child: const Center(child: Icon(Icons.palette_rounded, color: Colors.white54)),
              ),
            ),
          );
        } else if (sticker != null) {
          stickerContent = Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: sticker.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: sticker.gradientColors.first.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                sticker.emoji,
                style: const TextStyle(fontSize: 48),
              ),
            ),
          );
        } else {
          // Graceful fallback card for receiver if custom sticker image URL is missing or old local path
          stickerContent = Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B1E54), Color(0xFF6A1B9A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFFD4AF37), size: 36),
                  SizedBox(height: 6),
                  Text('Custom Sticker', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              stickerContent,
              const SizedBox(height: 4),
              Text(
                isNetwork ? 'Custom Sticker' : (sticker?.name ?? 'Sticker'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: widget.isMe ? Colors.white70 : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        );

      case MessageType.quickPing:
        final emoji = widget.message.quickPingEmoji ?? '⚡';
        final label = widget.message.quickPingLabel ?? 'Quick Ping';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isMe
                  ? [const Color(0xFFD4AF37).withValues(alpha: 0.35), const Color(0xFF8A2387).withValues(alpha: 0.35)]
                  : [const Color(0xFF6A1B9A).withValues(alpha: 0.35), const Color(0xFF2E0249).withValues(alpha: 0.35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: widget.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.isMe ? 'Sent with Velza' : 'Thinking of you',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isMe ? Colors.white70 : (isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case MessageType.poll:
        final question = widget.message.pollQuestion ?? widget.message.text;
        final options = widget.message.pollOptions ?? [];
        final votes = widget.message.pollVotes ?? {};
        int totalVotes = 0;
        votes.forEach((_, list) {
          totalVotes += list.length;
        });

        return Container(
          width: 240,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isMe
                ? Colors.black.withValues(alpha: 0.25)
                : (isDark ? const Color(0xFF1E1528) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.poll_rounded, color: Color(0xFFD4AF37), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'POLL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                question,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: widget.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                ),
              ),
              const SizedBox(height: 10),
              ...options.map((option) {
                final optionVoters = List<String>.from(votes[option] ?? []);
                final count = optionVoters.length;
                final isVoted = optionVoters.contains(widget.currentUserId);
                final ratio = totalVotes > 0 ? (count / totalVotes) : 0.0;

                return InkWell(
                  onTap: () => widget.onVotePoll?.call(option),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isVoted
                          ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
                          : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isVoted ? const Color(0xFFD4AF37) : Colors.white24,
                        width: isVoted ? 1.5 : 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isVoted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 16,
                              color: isVoted ? const Color(0xFFD4AF37) : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isVoted ? FontWeight.bold : FontWeight.w500,
                                  color: widget.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                            ),
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: widget.isMe ? Colors.white70 : (isDark ? Colors.white70 : Colors.black54),
                              ),
                            ),
                          ],
                        ),
                        if (totalVotes > 0) ...[
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 4,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isVoted ? const Color(0xFFD4AF37) : const Color(0xFF9C27B0),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isMe ? Colors.white54 : (isDark ? Colors.white38 : Colors.black45),
                    ),
                  ),
                  Text(
                    'Tap to vote',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case MessageType.scheduled:
        final scheduledFor = widget.message.scheduledFor;
        final isUnlocked = scheduledFor == null || scheduledFor.isBefore(DateTime.now());
        if (isUnlocked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_open_rounded, size: 12, color: Color(0xFFD4AF37)),
                    SizedBox(width: 4),
                    Text(
                      'Time Capsule Unlocked',
                      style: TextStyle(fontSize: 10, color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.message.text,
                style: TextStyle(
                  color: widget.isMe ? Colors.white : (isDark ? const Color(0xE6FFFFFF) : Colors.black87),
                  fontSize: settingsVM.chatFontSizeValue,
                  fontFamily: settingsVM.chatFontFamily,
                ),
              ),
            ],
          );
        } else {
          final formatted = '${scheduledFor.day}/${scheduledFor.month}/${scheduledFor.year} at ${scheduledFor.hour.toString().padLeft(2, '0')}:${scheduledFor.minute.toString().padLeft(2, '0')}';
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD4AF37), size: 28),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Time Capsule (Locked)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFD4AF37)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Opens on $formatted',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

      case MessageType.playlist:
        final playlistName = widget.message.playlistName ?? 'Shared Playlist';
        final trackCount = widget.message.playlistTracks?.length ?? 0;
        return InkWell(
          onTap: widget.onPlaylistTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1DB954), Color(0xFF191414)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.music_note_rounded, color: Colors.white, size: 30),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playlistName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$trackCount track${trackCount == 1 ? '' : 's'} • Tap to open',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

      case MessageType.gift:
        return _buildGiftCard(context, isDark, settingsVM);
    }
  }

  // Mention-aware RichText builder
  Widget _buildHighlightedText(String text, bool isDark, SettingsViewModel settingsVM) {
    final mentions = widget.message.mentions;
    final words = text.split(' ');
    final spans = <InlineSpan>[];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final isMention = word.startsWith('@') && word.length > 1;

      if (isMention) {
        final mentionName = word.substring(1);
        final matchesStored = mentions != null &&
            mentions.values.any((name) => name.toLowerCase() == mentionName.toLowerCase());

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.25)
                    : (isDark ? const Color(0xFFD4AF37).withValues(alpha: 0.2) : const Color(0xFF6A1B9A).withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: matchesStored || widget.message.mentionedUserIds.isNotEmpty
                      ? const Color(0xFFD4AF37)
                      : Colors.transparent,
                  width: 0.8,
                ),
              ),
              child: Text(
                word,
                style: TextStyle(
                  color: widget.isMe
                      ? Colors.amber.shade200
                      : (isDark ? const Color(0xFFFFD54F) : const Color(0xFF6A1B9A)),
                  fontWeight: FontWeight.w700,
                  fontSize: settingsVM.chatFontSizeValue - 1,
                  fontFamily: settingsVM.chatFontFamily,
                ),
              ),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: word,
            style: TextStyle(
              color: widget.isMe
                  ? Colors.white
                  : (isDark ? const Color(0xE6FFFFFF) : Colors.black87),
              fontSize: settingsVM.chatFontSizeValue,
              fontFamily: settingsVM.chatFontFamily,
            ),
          ),
        );
      }

      if (i < words.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  // Luxury Gift Message Card
  Widget _buildGiftCard(BuildContext context, bool isDark, SettingsViewModel settingsVM) {
    final unlockAt = widget.message.scheduledFor;
    final now = DateTime.now();
    final isReadyToOpen = unlockAt == null || now.isAfter(unlockAt);
    final isOpened = widget.message.isGiftOpened;

    if (isOpened) {
      // Opened luxury reveal state
      return InkWell(
        onTap: () => _showGiftRevealDialog(context, isDark),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E0249), Color(0xFF570A57), Color(0xFFA91079)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('🎁', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'GIFT UNWRAPPED',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('OPENED', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  widget.message.giftPayload?.isNotEmpty == true
                      ? widget.message.giftPayload!
                      : widget.message.text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: settingsVM.chatFontSizeValue,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Tap to view special note ✨',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Locked luxury gift card
    final timeRemaining = unlockAt != null ? unlockAt.difference(now) : Duration.zero;
    final timeText = unlockAt != null && !isReadyToOpen
        ? (timeRemaining.inHours > 0
            ? 'Reveals in ${timeRemaining.inHours}h ${timeRemaining.inMinutes % 60}m'
            : 'Reveals in ${timeRemaining.inMinutes}m')
        : 'Ready to unwrap!';

    return InkWell(
      onTap: () {
        if (isReadyToOpen) {
          widget.onOpenGift?.call();
          _showGiftRevealDialog(context, isDark);
        } else {
          final timeFormatted = DateFormat('MMM dd, hh:mm a').format(unlockAt);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎁 This gift message is sealed until $timeFormatted!'),
              backgroundColor: const Color(0xFF6A1B9A),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E162B), Color(0xFF3B1E54), Color(0xFF6A1B9A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isReadyToOpen ? const Color(0xFFFFD700) : const Color(0xFFD4AF37).withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isReadyToOpen
                  ? const Color(0xFFFFD700).withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF1E162B), size: 32),
            ),
            const SizedBox(height: 10),
            const Text(
              'SECRET SURPRISE GIFT',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeText,
              style: TextStyle(
                color: isReadyToOpen ? Colors.greenAccent : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isReadyToOpen ? const Color(0xFFFFD700) : Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isReadyToOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                      size: 14,
                      color: isReadyToOpen ? Colors.black : Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isReadyToOpen ? 'Tap to Unwrap Gift 🎁' : 'Sealed with Love',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isReadyToOpen ? Colors.black : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGiftRevealDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E162B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8E53)]),
              ),
              child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Surprise Gift Unwrapped! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sent by ${widget.message.senderName}',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C223D) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.6)),
              ),
              child: Text(
                widget.message.giftPayload?.isNotEmpty == true
                    ? widget.message.giftPayload!
                    : widget.message.text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close & Enjoy ✨', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reactions summary pill rendered below the message bubble
  Widget _buildReactionsPill(bool isDark) {
    if (widget.message.reactions.isEmpty) return const SizedBox.shrink();

    final Map<String, int> counts = {};
    for (var emoji in widget.message.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    final hasMyReaction = widget.currentUserId.isNotEmpty &&
        widget.message.reactions.containsKey(widget.currentUserId);

    return GestureDetector(
      onTap: () {
        if (widget.onReact != null) {
          ReactionBar.show(
            context: context,
            currentReaction: widget.message.reactions[widget.currentUserId],
            onSelectEmoji: (emoji) => widget.onReact!(emoji),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: hasMyReaction
              ? const Color(0xFFD4AF37).withValues(alpha: 0.25)
              : (isDark ? const Color(0xFF241B32) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasMyReaction
                ? const Color(0xFFD4AF37)
                : (isDark ? const Color(0xFF4A3E56) : Colors.grey.shade300),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              counts.keys.take(3).join(''),
              style: const TextStyle(fontSize: 13),
            ),
            if (widget.message.reactions.length > 1) ...[
              const SizedBox(width: 4),
              Text(
                '${widget.message.reactions.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: hasMyReaction ? const Color(0xFFD4AF37) : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(SettingsViewModel settingsVM) {
    final status = widget.message.getDeliveryStatus(
      readReceiptsEnabled: settingsVM.readReceiptsEnabled,
    );

    switch (status) {
      case MessageDeliveryStatus.failed:
        return InkWell(
          onTap: widget.onRetry,
          child: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.error_outline_rounded, size: 14, color: Colors.redAccent),
          ),
        );
      case MessageDeliveryStatus.sending:
        return const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(Icons.access_time_rounded, size: 12, color: Colors.white60),
        );
      case MessageDeliveryStatus.sent:
        return const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(Icons.done_rounded, size: 14, color: Colors.white54),
        );
      case MessageDeliveryStatus.delivered:
        return const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(Icons.done_all_rounded, size: 14, color: Colors.white54),
        );
      case MessageDeliveryStatus.read:
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(
            Icons.done_all_rounded,
            size: 14,
            color: settingsVM.readReceiptsEnabled ? const Color(0xFFD4AF37) : Colors.white54,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settingsVM = Provider.of<SettingsViewModel>(context);
    final timeStr = DateFormat('jm').format(widget.message.timestamp);

    final isSticker = widget.message.type == MessageType.sticker;

    final bubbleBg = isSticker
        ? Colors.transparent
        : (widget.isMe
            ? const Color(0xFF6A1B9A) // Velza Purple for sender
            : (isDark ? const Color(0xFF1E162B) : Colors.white)); // Velza Dark Card or Clean White

    final isDeleted = widget.message.deleted || widget.message.deletedForEveryone;

    final messageBubble = GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress ?? () => _showContextMenu(context),
      child: Container(
        color: widget.isSelected
            ? const Color(0xFF6A1B9A).withValues(alpha: 0.22)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Align(
          alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                margin: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                padding: isSticker
                    ? const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0)
                    : const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: bubbleBg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(widget.isMe ? 16 : 2),
                    bottomRight: Radius.circular(widget.isMe ? 2 : 16),
                  ),
                  border: widget.isSelected
                      ? Border.all(color: const Color(0xFFD4AF37), width: 1.5)
                      : (widget.isHighlighted
                          ? Border.all(color: const Color(0xFFD4AF37), width: 2.0)
                          : null),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isSelected
                          ? const Color(0xFF6A1B9A).withValues(alpha: 0.35)
                          : (widget.isHighlighted
                              ? const Color(0xFFD4AF37).withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.08)),
                      blurRadius: (widget.isSelected || widget.isHighlighted) ? 10 : 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Quoted reply
                    if (!isDeleted) _buildReplyQuote(isDark),

                    // Message payload
                    _buildMessageContent(theme, isDark, settingsVM),

                    const SizedBox(height: 4),

                    // Timestamp, Edited badge & Read status
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.message.edited && !isDeleted) ...[
                          Text(
                            'edited  ',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: widget.isMe ? Colors.white60 : (isDark ? Colors.white38 : Colors.black38),
                            ),
                          ),
                        ],
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: widget.isMe
                                ? Colors.white60
                                : (isDark ? Colors.white30 : Colors.black38),
                          ),
                        ),
                        if (widget.isMe && !isDeleted)
                          _buildStatusIcon(settingsVM),
                      ],
                    )
                  ],
                ),
              ),
              if (widget.message.reactions.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    left: widget.isMe ? 0 : 20.0,
                    right: widget.isMe ? 20.0 : 0,
                    bottom: 2.0,
                  ),
                  child: _buildReactionsPill(isDark),
                ),
            ],
          ),
        ),
      ),
    );

    if (widget.onReply != null && !isDeleted) {
      return SwipeToReply(
        onReply: widget.onReply!,
        isMe: widget.isMe,
        child: messageBubble,
      );
    }
    return messageBubble;
  }
}
