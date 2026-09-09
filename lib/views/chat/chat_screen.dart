import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:velza/models/chat_model.dart';
import 'package:velza/models/message_model.dart';
import 'package:velza/models/sticker_model.dart';
import 'package:velza/models/user_model.dart';
import 'package:velza/models/relationship_model.dart';
import 'package:velza/viewmodels/auth_viewmodel.dart';
import 'package:velza/viewmodels/chat_viewmodel.dart';
import 'package:velza/viewmodels/settings_viewmodel.dart';
import 'package:velza/services/audio_service.dart';
import 'package:velza/services/database_service.dart';
import 'package:velza/services/notification_service.dart';
import 'package:velza/services/wallpaper_service.dart';
import 'package:velza/views/widgets/wallpaper_background.dart';
import 'package:velza/views/chat/wallpaper_picker_dialog.dart';
import 'package:velza/views/chat/chat_details_screen.dart';
import 'package:velza/views/chat/nickname_dialog.dart';
import 'package:velza/views/chat/chat_composer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:velza/views/widgets/chat_bubble.dart';
import 'package:intl/intl.dart';
import 'package:velza/views/chat/message_search_dialog.dart';
import 'package:velza/views/chat/quick_ping_sheet.dart';
import 'package:velza/views/chat/poll_creator_dialog.dart';
import 'package:velza/views/chat/time_capsule_dialog.dart';
import 'package:velza/views/chat/shared_playlist_sheet.dart';
import 'package:velza/views/chat/sticker_creator_sheet.dart';
import 'package:velza/services/e2ee_service.dart';

class ChatScreen extends StatefulWidget {
  final ChatModel chat;
  const ChatScreen({super.key, required this.chat});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final AudioService _audioService = AudioService();
  final ImagePicker _imagePicker = ImagePicker();

  // Active reply & edit states
  MessageModel? _replyingToMessage;
  MessageModel? _editingMessage;

  // Active wallpaper state
  late WallpaperModel _currentWallpaper;

  // Highlight navigation state
  String? _highlightedMessageId;
  Timer? _highlightTimer;

  // Multi-message selection mode state (up to 999 messages)
  final Set<String> _selectedMessageIds = {};
  bool get _isSelectionMode => _selectedMessageIds.isNotEmpty;

  // Pagination state for older messages
  final List<MessageModel> _olderMessages = [];
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;

  @override
  void initState() {
    super.initState();
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final currentUid = authVM.currentUserModel?.uid ?? authVM.firebaseUser?.uid ?? '';
    _currentWallpaper = WallpaperService().getPersonalWallpaper(currentUid, widget.chat.id);
    NotificationService().setActiveChat(widget.chat.id);

    if (currentUid.isNotEmpty) {
      WallpaperService().loadPersonalWallpaper(currentUid, widget.chat.id).then((wp) {
        if (mounted) {
          setState(() {
            _currentWallpaper = wp;
          });
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentUid.isNotEmpty) {
        Provider.of<ChatViewModel>(context, listen: false).initNicknames(currentUid);
        E2eeService().initUserKeys(currentUid);
      }
    });
  }

  void _openWallpaperPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E162B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => WallpaperPickerDialog(
        chatId: widget.chat.id,
        currentWallpaper: _currentWallpaper,
        onWallpaperSelected: (wp) {
          setState(() {
            _currentWallpaper = wp;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    NotificationService().setActiveChat(null);
    _scrollController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _jumpToMessage(String messageId, List<MessageModel> messages) async {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final currentUid = authVM.currentUserModel?.uid ?? authVM.firebaseUser?.uid ?? '';
    final chatVM = Provider.of<ChatViewModel>(context, listen: false);

    // 1. Check if message is already loaded in messages list
    int index = messages.indexWhere((m) => m.id == messageId);

    // 2. If not loaded in initial/current list, attempt to fetch older messages iteratively
    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading earlier messages...'),
          duration: Duration(milliseconds: 1000),
        ),
      );

      DateTime? oldestTimestamp = messages.isNotEmpty ? messages.last.timestamp : null;
      int attempts = 0;
      while (index == -1 && attempts < 5 && _hasMoreOlder && oldestTimestamp != null) {
        attempts++;
        final olderBatch = await chatVM.fetchOlderMessages(
          chatId: widget.chat.id,
          beforeTimestamp: oldestTimestamp,
          limit: 30,
          currentUserId: currentUid,
        );

        if (olderBatch.isEmpty) {
          _hasMoreOlder = false;
          break;
        }

        if (mounted) {
          setState(() {
            for (final msg in olderBatch) {
              if (!_olderMessages.any((m) => m.id == msg.id) &&
                  !messages.any((m) => m.id == msg.id)) {
                _olderMessages.add(msg);
              }
            }
          });
        }

        final combined = [...messages, ..._olderMessages];
        index = combined.indexWhere((m) => m.id == messageId);
        oldestTimestamp = olderBatch.last.timestamp;
      }
    }

    // 3. Scroll to target message
    if (index != -1 && _scrollController.hasClients) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final targetOffset = (index * 76.0).clamp(0.0, maxScroll);
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    }

    // 4. Highlight message for 2.5 seconds
    setState(() {
      _highlightedMessageId = messageId;
    });
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  // --- Sending / Editing Messages ---

  void _handleSendText(
    ChatViewModel chatVM,
    String senderId,
    String senderName,
    String text, {
    List<String>? mentionedUserIds,
    Map<String, String>? mentions,
  }) async {
    final otherUid = _getOtherUserId(senderId);

    if (_editingMessage != null) {
      final msgToEdit = _editingMessage!;
      setState(() {
        _editingMessage = null;
      });

      String textToSend = text;
      bool isEncrypted = false;
      if (!widget.chat.isGroup && otherUid.isNotEmpty) {
        final cipher = await E2eeService().encryptMessage(
          chatId: widget.chat.id,
          otherUid: otherUid,
          plaintext: text,
        );
        if (E2eeService.isPayloadEncrypted(cipher)) {
          textToSend = cipher;
          isEncrypted = true;
          E2eeService().cacheDecrypted(cipher, text);
        }
      }

      await chatVM.editMessage(
        chatId: widget.chat.id,
        messageId: msgToEdit.id,
        senderId: senderId,
        newText: textToSend,
        isEncrypted: isEncrypted,
      );
    } else {
      final replyTarget = _replyingToMessage;
      setState(() {
        _replyingToMessage = null;
      });

      String textToSend = text;
      bool isEncrypted = false;
      if (!widget.chat.isGroup && otherUid.isNotEmpty) {
        final cipher = await E2eeService().encryptMessage(
          chatId: widget.chat.id,
          otherUid: otherUid,
          plaintext: text,
        );
        if (E2eeService.isPayloadEncrypted(cipher)) {
          textToSend = cipher;
          isEncrypted = true;
          E2eeService().cacheDecrypted(cipher, text);
        }
      }

      await chatVM.sendTextMessage(
        chatId: widget.chat.id,
        senderId: senderId,
        senderName: senderName,
        text: textToSend,
        isEncrypted: isEncrypted,
        replyToMessageId: replyTarget?.id,
        replyToText: null, // Zero plaintext leakage in reply fields
        replyToSenderId: replyTarget?.senderId,
        replyToSenderName: replyTarget?.senderName,
        mentionedUserIds: mentionedUserIds,
        mentions: mentions,
      );
    }
  }

  void _handleSendVoice(ChatViewModel chatVM, String senderId, String senderName, AudioRecordResult result, int duration) async {
    final replyTarget = _replyingToMessage;
    setState(() {
      _replyingToMessage = null;
    });

    await chatVM.sendVoiceNote(
      chatId: widget.chat.id,
      senderId: senderId,
      senderName: senderName,
      file: result.file,
      audioDuration: duration > 0 ? duration : result.durationSeconds,
      replyToMessageId: replyTarget?.id,
      replyToText: replyTarget != null ? _getMessageSummary(replyTarget) : null,
      replyToSenderId: replyTarget?.senderId,
      replyToSenderName: replyTarget?.senderName,
    );
  }

  void _handleSendSticker(ChatViewModel chatVM, String senderId, String senderName, VelzaSticker sticker) async {
    final replyTarget = _replyingToMessage;
    setState(() {
      _replyingToMessage = null;
    });

    String assetOrUrl = sticker.assetPath;
    if (sticker.isCustom && sticker.localCustomPath != null) {
      final file = File(sticker.localCustomPath!);
      if (await file.exists()) {
        try {
          final downloadUrl = await chatVM.storageService.uploadChatMedia(
            chatId: widget.chat.id,
            messageId: const Uuid().v4(),
            file: file,
            fileExtension: 'png',
            type: 'stickers',
          );
          assetOrUrl = downloadUrl;
        } catch (e) {
          debugPrint('[Sticker] Custom sticker upload failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to upload custom sticker. Please check your internet connection.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
      }
    }

    await chatVM.sendStickerMessage(
      chatId: widget.chat.id,
      senderId: senderId,
      senderName: senderName,
      stickerId: sticker.id,
      stickerAsset: assetOrUrl,
      replyToMessageId: replyTarget?.id,
      replyToText: replyTarget != null ? _getMessageSummary(replyTarget) : null,
      replyToSenderId: replyTarget?.senderId,
      replyToSenderName: replyTarget?.senderName,
    );
  }

  String _getMessageSummary(MessageModel msg) {
    if (msg.type == MessageType.image) return '📷 Photo';
    if (msg.type == MessageType.video) return '🎥 Video';
    if (msg.type == MessageType.audio) return '🎤 Voice message';
    if (msg.type == MessageType.sticker) return '🏷️ Sticker';
    if (msg.type == MessageType.document) {
      return '📄 ${msg.fileName.isNotEmpty ? msg.fileName : "Document"}';
    }
    return msg.text;
  }

  // --- Reply Message Navigation ---

  void _scrollToAndHighlightMessage(String targetMessageId, List<MessageModel> messages) {
    final index = messages.indexWhere((m) => m.id == targetMessageId);
    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Original message could not be found or was deleted.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetOffset = (index * 75.0).clamp(0.0, maxScroll);
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }

    _highlightTimer?.cancel();
    setState(() {
      _highlightedMessageId = targetMessageId;
    });

    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  // --- Attachments & Media Preview ---

  void _showAttachmentBottomSheet(ChatViewModel chatVM, String senderId, String senderName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E162B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Share & Interact',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(
                    Icons.camera_alt_rounded, 'Camera', Colors.pink,
                    () {
                      Navigator.pop(ctx);
                      _pickMedia(chatVM, senderId, senderName, MessageType.image, ImageSource.camera);
                    },
                  ),
                  _buildAttachmentOption(
                    Icons.photo_library_rounded, 'Gallery', Colors.purple,
                    () {
                      Navigator.pop(ctx);
                      _pickMedia(chatVM, senderId, senderName, MessageType.image, ImageSource.gallery);
                    },
                  ),
                  _buildAttachmentOption(
                    Icons.videocam_rounded, 'Video', Colors.blueAccent,
                    () {
                      Navigator.pop(ctx);
                      _pickMedia(chatVM, senderId, senderName, MessageType.video, ImageSource.gallery);
                    },
                  ),
                  _buildAttachmentOption(
                    Icons.insert_drive_file_rounded, 'Document', Colors.amber.shade700,
                    () {
                      Navigator.pop(ctx);
                      _pickDocument(chatVM, senderId, senderName);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(
                    Icons.bolt_rounded, 'Quick Ping', const Color(0xFFD4AF37),
                    () {
                      Navigator.pop(ctx);
                      QuickPingSheet.show(
                        context,
                        onSelectPing: (emoji, label) {
                          chatVM.sendQuickPing(
                            chatId: widget.chat.id,
                            senderId: senderId,
                            senderName: senderName,
                            emoji: emoji,
                            label: label,
                          );
                        },
                      );
                    },
                  ),
                  _buildAttachmentOption(
                    Icons.poll_rounded, 'Poll', Colors.teal,
                    () {
                      Navigator.pop(ctx);
                      PollCreatorDialog.show(
                        context,
                        onCreatePoll: (question, options) {
                          chatVM.sendPoll(
                            chatId: widget.chat.id,
                            senderId: senderId,
                            senderName: senderName,
                            question: question,
                            options: options,
                          );
                        },
                      );
                    },
                  ),
                  _buildAttachmentOption(
                    Icons.card_giftcard_rounded, 'Gift / Capsule', const Color(0xFFD4AF37),
                    () {
                      Navigator.pop(ctx);
                      TimeCapsuleDialog.show(
                        context,
                        onScheduleMessage: (text, scheduledFor, {bool isGift = true}) {
                          if (isGift) {
                            chatVM.sendGiftMessage(
                              chatId: widget.chat.id,
                              senderId: senderId,
                              senderName: senderName,
                              surpriseText: text,
                              scheduledFor: scheduledFor,
                            );
                          } else {
                            chatVM.sendScheduledMessage(
                              chatId: widget.chat.id,
                              senderId: senderId,
                              senderName: senderName,
                              text: text,
                              scheduledFor: scheduledFor,
                            );
                          }
                        },
                      );
                    },
                  ),
                  _buildAttachmentOption(
                    Icons.queue_music_rounded, 'Playlist', Colors.green,
                    () {
                      Navigator.pop(ctx);
                      SharedPlaylistSheet.show(
                        context,
                        chatId: widget.chat.id,
                        currentUid: senderId,
                        currentUserName: senderName,
                      );
                    },
                  ),
                  _buildAttachmentOption(
                    Icons.auto_awesome_rounded, 'Sticker Studio', Colors.purpleAccent,
                    () {
                      Navigator.pop(ctx);
                      StickerCreatorSheet.show(
                        context,
                        onStickerCreated: (file) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Custom sticker saved! Open Stickers to use it.')),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickMedia(
    ChatViewModel chatVM,
    String senderId,
    String senderName,
    MessageType type,
    ImageSource source,
  ) async {
    try {
      XFile? pickedFile;
      if (type == MessageType.image) {
        pickedFile = await _imagePicker.pickImage(source: source, imageQuality: 80);
      } else {
        pickedFile = await _imagePicker.pickVideo(source: source);
      }

      if (pickedFile != null && mounted) {
        _showMediaPreviewDialog(
          chatVM: chatVM,
          senderId: senderId,
          senderName: senderName,
          file: File(pickedFile.path),
          type: type,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access media: $e')),
        );
      }
    }
  }

  void _pickDocument(ChatViewModel chatVM, String senderId, String senderName) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result != null && result.files.single.path != null && mounted) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final replyTarget = _replyingToMessage;
        setState(() {
          _replyingToMessage = null;
        });

        await chatVM.sendMediaMessage(
          chatId: widget.chat.id,
          senderId: senderId,
          senderName: senderName,
          file: file,
          type: MessageType.document,
          customFileName: fileName,
          replyToMessageId: replyTarget?.id,
          replyToText: replyTarget != null ? _getMessageSummary(replyTarget) : null,
          replyToSenderId: replyTarget?.senderId,
          replyToSenderName: replyTarget?.senderName,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting document: $e')),
        );
      }
    }
  }

  void _showMediaPreviewDialog({
    required ChatViewModel chatVM,
    required String senderId,
    required String senderName,
    required File file,
    required MessageType type,
  }) {
    final TextEditingController captionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(ctx),
          ),
          title: Text(
            type == MessageType.image ? 'Preview Photo' : 'Preview Video',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: type == MessageType.image
                    ? Image.file(file, fit: BoxFit.contain)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.video_file_rounded, size: 80, color: Color(0xFFD4AF37)),
                          const SizedBox(height: 12),
                          Text(
                            file.path.split(Platform.pathSeparator).last,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
              ),
            ),
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF1E162B),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: captionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      backgroundColor: const Color(0xFF6A1B9A),
                      mini: true,
                      child: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: () async {
                        final caption = captionController.text.trim();
                        final replyTarget = _replyingToMessage;
                        Navigator.pop(ctx);
                        setState(() {
                          _replyingToMessage = null;
                        });

                        await chatVM.sendMediaMessage(
                          chatId: widget.chat.id,
                          senderId: senderId,
                          senderName: senderName,
                          file: file,
                          type: type,
                          caption: caption,
                          replyToMessageId: replyTarget?.id,
                          replyToText: replyTarget != null ? _getMessageSummary(replyTarget) : null,
                          replyToSenderId: replyTarget?.senderId,
                          replyToSenderName: replyTarget?.senderName,
                        );
                      },
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

  // --- Dialogs & Menu Actions ---

  void _openNicknameDialog(String otherUid, String originalName, ChatViewModel chatVM) {
    showDialog(
      context: context,
      builder: (ctx) => NicknameDialog(
        targetUid: otherUid,
        originalName: originalName,
        currentNickname: chatVM.getNickname(otherUid) ?? '',
        onSave: (newNick) async {
          final currentUid = Provider.of<AuthViewModel>(context, listen: false).currentUserModel?.uid ?? '';
          if (currentUid.isNotEmpty) {
            await chatVM.setNickname(currentUid: currentUid, targetUid: otherUid, nickname: newNick, chatId: widget.chat.id);
          }
        },
        onRemove: () async {
          final currentUid = Provider.of<AuthViewModel>(context, listen: false).currentUserModel?.uid ?? '';
          if (currentUid.isNotEmpty) {
            await chatVM.deleteNickname(currentUid: currentUid, targetUid: otherUid, chatId: widget.chat.id);
          }
        },
      ),
    );
  }

  void _handleMenuAction(ChatViewModel chatVM, String currentUid, String otherUid, String action) {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    if (action == 'clear') {
      _showClearChatDialog(chatVM, currentUid);
    } else if (action == 'block') {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Block User?'),
          content: const Text('Blocked users will not be able to send you messages.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await chatVM.blockUser(currentUid, otherUid);
                nav.pop();
                messenger.showSnackBar(const SnackBar(content: Text('User blocked')));
              },
              child: const Text('Block', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } else if (action == 'report') {
      final TextEditingController reportController = TextEditingController();
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Report User'),
          content: TextField(
            controller: reportController,
            decoration: const InputDecoration(hintText: 'Enter reason for report...'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final reason = reportController.text.trim();
                if (reason.isNotEmpty) {
                  Navigator.pop(dialogCtx);
                  await chatVM.reportUser(currentUid, otherUid, reason);
                  messenger.showSnackBar(const SnackBar(content: Text('Report submitted')));
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      );
    }
  }

  void _showClearChatDialog(ChatViewModel chatVM, String currentUid) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Clear this chat?'),
        content: const Text(
          'This will remove messages from your view. The conversation will remain intact for the other participant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() {
                _olderMessages.clear();
                _selectedMessageIds.clear();
              });
              await chatVM.clearChat(chatId: widget.chat.id, currentUserId: currentUid);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat cleared from your view')),
                );
              }
            },
            child: const Text('Clear for me', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(MessageModel message) {
    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
      } else {
        if (_selectedMessageIds.length < 999) {
          _selectedMessageIds.add(message.id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 999 messages can be selected')),
          );
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMessageIds.clear();
    });
  }

  void _copySelectedMessages(List<MessageModel> allMessages) {
    final selected = allMessages.where((m) => _selectedMessageIds.contains(m.id)).toList();
    selected.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final textToCopy = selected.map((m) {
      if (m.text.isNotEmpty) return '[${m.senderName}]: ${m.text}';
      return '[${m.senderName}]: ${_getMessageSummary(m)}';
    }).join('\n');

    Clipboard.setData(ClipboardData(text: textToCopy));
    final count = selected.length;
    _clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count message${count > 1 ? "s" : ""} copied')),
    );
  }

  void _showBulkDeleteDialog(List<MessageModel> allMessages, String currentUid, ChatViewModel chatVM) {
    final selected = allMessages.where((m) => _selectedMessageIds.contains(m.id)).toList();
    if (selected.isEmpty) return;

    final canDeleteForEveryone = selected.every((m) => m.senderId == currentUid && !m.deleted && !m.deletedForEveryone);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Delete ${selected.length} message${selected.length > 1 ? "s" : ""}?'),
        content: Text(
          canDeleteForEveryone
              ? 'You can delete these messages for everyone or just for yourself.'
              : 'Delete these messages from your view?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              _clearSelection();
              await chatVM.bulkDeleteMessages(
                chatId: widget.chat.id,
                messages: selected,
                forEveryone: false,
                currentUserId: currentUid,
              );
            },
            child: const Text('Delete for me'),
          ),
          if (canDeleteForEveryone)
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                _clearSelection();
                await chatVM.bulkDeleteMessages(
                  chatId: widget.chat.id,
                  messages: selected,
                  forEveryone: true,
                  currentUserId: currentUid,
                );
              },
              child: const Text('Delete for everyone', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  void _loadMoreOlderMessages(String currentUid, DateTime beforeTimestamp, DateTime? clearedAt) async {
    if (_isLoadingOlder || !_hasMoreOlder) return;
    setState(() {
      _isLoadingOlder = true;
    });

    final chatVM = Provider.of<ChatViewModel>(context, listen: false);
    final older = await chatVM.fetchOlderMessages(
      chatId: widget.chat.id,
      beforeTimestamp: beforeTimestamp,
      limit: 30,
      currentUserId: currentUid,
      clearedAt: clearedAt,
    );

    if (mounted) {
      setState(() {
        _isLoadingOlder = false;
        if (older.isEmpty) {
          _hasMoreOlder = false;
        } else {
          _olderMessages.addAll(older);
        }
      });
    }
  }

  String _getOtherUserId(String currentUid) {
    return widget.chat.memberIds.firstWhere((id) => id != currentUid, orElse: () => '');
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final chatVM = Provider.of<ChatViewModel>(context);

    final String currentUid = authVM.currentUserModel?.uid ?? '';
    final String currentName = authVM.currentUserModel?.displayName ?? 'Anonymous';
    final String otherUid = _getOtherUserId(currentUid);

    return StreamBuilder<ChatModel?>(
      stream: chatVM.streamChat(widget.chat.id),
      builder: (context, chatDocSnap) {
        final liveChat = chatDocSnap.data ?? widget.chat;
        final activeWallpaper = _currentWallpaper;
        final clearedAt = liveChat.clearedAtBy[currentUid];

        return StreamBuilder<List<MessageModel>>(
          stream: chatVM.streamMessages(widget.chat.id, currentUid, clearedAt),
          builder: (context, msgSnap) {
            final liveMessages = msgSnap.data ?? [];

            // Combine live recent messages with paged older messages, deduplicated
            final Map<String, MessageModel> messageMap = {};
            for (final m in liveMessages) {
              messageMap[m.id] = m;
            }
            for (final m in _olderMessages) {
              if (!messageMap.containsKey(m.id)) {
                messageMap[m.id] = m;
              }
            }
            final allMessages = messageMap.values.toList()
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

            // Mark unread and delivered messages respecting read receipts setting
            if (liveMessages.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final settingsVM = Provider.of<SettingsViewModel>(context, listen: false);
                for (final m in liveMessages) {
                  if (m.senderId != currentUid) {
                    if (!m.deliveredTo.contains(currentUid)) {
                      chatVM.markMessageDelivered(widget.chat.id, m.id, currentUid);
                    }
                    if (settingsVM.readReceiptsEnabled && !m.readBy.contains(currentUid)) {
                      chatVM.markMessageAsRead(widget.chat.id, m.id, currentUid);
                    }
                  }
                }
              });
            }

            return Scaffold(
              appBar: _isSelectionMode
                  ? AppBar(
                      backgroundColor: const Color(0xFF1E162B),
                      leading: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: _clearSelection,
                      ),
                      title: Text(
                        '${_selectedMessageIds.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: Colors.white),
                          tooltip: 'Copy',
                          onPressed: () => _copySelectedMessages(allMessages),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_rounded, color: Colors.white),
                          tooltip: 'Delete',
                          onPressed: () => _showBulkDeleteDialog(allMessages, currentUid, chatVM),
                        ),
                        const SizedBox(width: 8),
                      ],
                    )
                  : AppBar(
                      titleSpacing: 0,
                      title: StreamBuilder<UserModel>(
                        stream: chatVM.streamUserProfile(otherUid),
                        builder: (context, userSnap) {
                          final user = userSnap.data;
                          final fallbackName = user != null && user.displayName.isNotEmpty
                              ? user.displayName
                              : widget.chat.name;
                          final isOnline = user?.isOnline ?? false;

                          return StreamBuilder<RelationshipModel?>(
                            stream: chatVM.streamRelationship(currentUid, otherUid),
                            builder: (context, relSnap) {
                              final rel = relSnap.data;
                              final sharedNick = rel?.sharedNickname?.trim() ?? '';

                              return StreamBuilder<MutualNicknameInfo>(
                                stream: chatVM.streamMutualNicknames(currentUid: currentUid, otherUid: otherUid, chatId: widget.chat.id),
                                builder: (context, nickSnap) {
                                  final nickInfo = nickSnap.data;
                                  final myNicknameForOther = nickInfo?.nicknameGivenByMe ?? chatVM.getNickname(otherUid) ?? '';

                                  // Priority: 1. Personal contact nickname (A sees B as King, B sees A as Queen)
                                  // 2. Relationship-scoped shared nickname (if any)
                                  // 3. Global display name
                                  final String primaryName = myNicknameForOther.isNotEmpty
                                      ? myNicknameForOther
                                      : (sharedNick.isNotEmpty ? sharedNick : fallbackName);
                                  final bool hasCustomNick = myNicknameForOther.isNotEmpty || sharedNick.isNotEmpty;

                                  final typingMap = liveChat.typingStatus;
                                  final String typingState = typingMap[otherUid] ?? 'none';
                                  String subText = isOnline ? 'Online' : 'Offline';
                                  if (user != null && !isOnline) {
                                    final diff = DateTime.now().difference(user.lastSeen);
                                    if (diff.inDays == 0) {
                                      subText = 'Last seen today at ${DateFormat('jm').format(user.lastSeen)}';
                                    } else {
                                      subText = 'Last seen ${DateFormat('MMM d, jm').format(user.lastSeen)}';
                                    }
                                  }
                                  if (typingState == 'typing') {
                                    subText = 'typing...';
                                  } else if (typingState == 'recording') {
                                    subText = 'recording voice note...';
                                  }

                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatDetailsScreen(
                                            chat: widget.chat,
                                            otherUid: otherUid,
                                            currentUid: currentUid,
                                            initialUser: user,
                                          ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                      child: Row(
                                        children: [
                                          Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor: const Color(0xFF6A1B9A),
                                                backgroundImage: user?.photoUrl != null && user!.photoUrl.isNotEmpty
                                                    ? CachedNetworkImageProvider(user.photoUrl)
                                                    : null,
                                                child: user?.photoUrl == null || user!.photoUrl.isEmpty
                                                    ? const Icon(Icons.person, color: Colors.white, size: 20)
                                                    : null,
                                              ),
                                              if (user?.moodEmoji != null && user!.moodEmoji!.isNotEmpty)
                                                Positioned(
                                                  bottom: -2,
                                                  right: -2,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF1E162B),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Color(user.moodColor ?? 0xFFD4AF37),
                                                        width: 1.2,
                                                      ),
                                                    ),
                                                    child: Text(user.moodEmoji!, style: const TextStyle(fontSize: 10)),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        primaryName,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                    if (hasCustomNick && primaryName != fallbackName) ...[
                                                      const SizedBox(width: 6),
                                                      Flexible(
                                                        child: Text(
                                                          '~ $fallbackName',
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.white60,
                                                            fontWeight: FontWeight.normal,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    if (liveChat.streakCount > 0) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.orange.withValues(alpha: 0.2),
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: Border.all(color: Colors.orangeAccent, width: 0.8),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Text('🔥', style: TextStyle(fontSize: 11)),
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              '${liveChat.streakCount}',
                                                              style: const TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.bold,
                                                                color: Colors.orangeAccent,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                Text(
                                                  subText,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: subText.contains('...') ? const Color(0xFFD4AF37) : Colors.white60,
                                                    fontWeight: subText.contains('...') ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.search_rounded),
                          tooltip: 'Search Messages',
                          onPressed: () async {
                            final targetMsgId = await MessageSearchDialog.show(
                              context,
                              chatId: widget.chat.id,
                              currentUid: currentUid,
                              otherUserName: (chatVM.getNickname(otherUid) ?? widget.chat.name),
                              activeMessages: allMessages,
                            );
                            if (targetMsgId != null) {
                              _jumpToMessage(targetMsgId, allMessages);
                            }
                          },
                        ),
                        PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'nickname') {
                              _openNicknameDialog(otherUid, widget.chat.name, chatVM);
                            } else if (val == 'wallpaper') {
                              _openWallpaperPicker();
                            } else {
                              _handleMenuAction(chatVM, currentUid, otherUid, val);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'nickname',
                              child: Row(
                                children: [
                                  Icon(Icons.badge_outlined, size: 20, color: Color(0xFFD4AF37)),
                                  SizedBox(width: 10),
                                  Text('Set Nickname'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'wallpaper',
                              child: Row(
                                children: [
                                  Icon(Icons.wallpaper_rounded, size: 20, color: Color(0xFFD4AF37)),
                                  SizedBox(width: 10),
                                  Text('Chat Wallpaper'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'clear',
                              child: Row(
                                children: [
                                  Icon(Icons.cleaning_services_rounded, size: 20, color: Color(0xFFD4AF37)),
                                  SizedBox(width: 10),
                                  Text('Clear Chat'),
                                ],
                              ),
                            ),
                            PopupMenuDivider(),
                            PopupMenuItem(value: 'block', child: Text('Block User')),
                            PopupMenuItem(value: 'report', child: Text('Report User')),
                          ],
                        ),
                      ],
                    ),
              body: WallpaperBackgroundWidget(
                wallpaper: activeWallpaper,
                child: Column(
                  children: [
                    // Upload Progress Bar
                    if (chatVM.isLoading && chatVM.uploadProgress > 0)
                      LinearProgressIndicator(
                        value: chatVM.uploadProgress,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                      ),

                    // Messages area
                    Expanded(
                      child: allMessages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text('No messages yet. Say hello!', style: TextStyle(color: Colors.grey.shade500)),
                                ],
                              ),
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: (ScrollNotification scrollInfo) {
                                if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200 &&
                                    !_isLoadingOlder &&
                                    _hasMoreOlder &&
                                    allMessages.isNotEmpty) {
                                  _loadMoreOlderMessages(currentUid, allMessages.last.timestamp, clearedAt);
                                }
                                return false;
                              },
                              child: ListView.builder(
                                controller: _scrollController,
                                reverse: true,
                                itemCount: allMessages.length + (_isLoadingOlder ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= allMessages.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8.0),
                                      child: Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFD4AF37),
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final message = allMessages[index];
                                  final isMe = message.senderId == currentUid;
                                  final isSelected = _selectedMessageIds.contains(message.id);

                                  return ChatBubble(
                                    key: ValueKey(message.id),
                                    message: message,
                                    isMe: isMe,
                                    currentUserId: currentUid,
                                    otherUserId: otherUid,
                                    audioService: _audioService,
                                    isHighlighted: message.id == _highlightedMessageId,
                                    isSelected: isSelected,
                                    onTap: _isSelectionMode ? () => _toggleSelection(message) : null,
                                    onLongPress: _isSelectionMode ? () => _toggleSelection(message) : null,
                                    onSelect: () => _toggleSelection(message),
                                    onRetry: () => chatVM.retryFailedMessage(widget.chat.id, message),
                                    onQuotedMessageTap: (replyId) => _scrollToAndHighlightMessage(replyId, allMessages),
                                    onReply: () {
                                      setState(() {
                                        _replyingToMessage = message;
                                        _editingMessage = null;
                                      });
                                    },
                                    onEdit: () {
                                      setState(() {
                                        _editingMessage = message;
                                        _replyingToMessage = null;
                                      });
                                    },
                                    onDeleteForMe: () async {
                                      await chatVM.deleteMessageForMe(
                                        chatId: widget.chat.id,
                                        messageId: message.id,
                                        currentUserId: currentUid,
                                      );
                                    },
                                    onDeleteForEveryone: () async {
                                      await chatVM.deleteMessageForEveryone(
                                        chatId: widget.chat.id,
                                        messageId: message.id,
                                        senderId: currentUid,
                                      );
                                    },
                                    onReact: (emoji) async {
                                      await chatVM.toggleReaction(
                                        chatId: widget.chat.id,
                                        messageId: message.id,
                                        userId: currentUid,
                                        emoji: emoji,
                                      );
                                    },
                                    onVotePoll: (option) async {
                                      await chatVM.votePoll(
                                        chatId: widget.chat.id,
                                        messageId: message.id,
                                        optionText: option,
                                        userId: currentUid,
                                      );
                                    },
                                    onPlaylistTap: () {
                                      SharedPlaylistSheet.show(
                                        context,
                                        chatId: widget.chat.id,
                                        currentUid: currentUid,
                                        currentUserName: currentName,
                                      );
                                    },
                                    onOpenGift: () async {
                                      await chatVM.openGiftMessage(
                                        chatId: widget.chat.id,
                                        messageId: message.id,
                                        userId: currentUid,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                    ),

                    // Decoupled ChatComposer: isolates typing rebuilds & recording timer from message list
                    StreamBuilder<List<UserModel>>(
                      stream: chatVM.streamRegisteredUsers(currentUid),
                      builder: (context, usersSnap) {
                        final mentionList = usersSnap.data ?? [];
                        return ChatComposer(
                          chatId: widget.chat.id,
                          currentUid: currentUid,
                          currentName: currentName,
                          replyingToMessage: _replyingToMessage,
                          editingMessage: _editingMessage,
                          audioService: _audioService,
                          mentionableUsers: mentionList,
                          onSendText: (text, {mentionedUserIds, mentions}) => _handleSendText(
                            chatVM,
                            currentUid,
                            currentName,
                            text,
                            mentionedUserIds: mentionedUserIds,
                            mentions: mentions,
                          ),
                          onSendVoice: (res, dur) => _handleSendVoice(chatVM, currentUid, currentName, res, dur),
                          onSendSticker: (sticker) => _handleSendSticker(chatVM, currentUid, currentName, sticker),
                          onCancelReply: () => setState(() => _replyingToMessage = null),
                          onCancelEdit: () => setState(() => _editingMessage = null),
                          onAttachmentTap: () => _showAttachmentBottomSheet(chatVM, currentUid, currentName),
                          onTypingStatusChanged: (status) => chatVM.updateChatTypingStatus(widget.chat.id, currentUid, status),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAttachmentOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
