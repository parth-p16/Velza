import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:velza/models/status_model.dart';
import 'package:velza/models/user_model.dart';
import 'package:velza/viewmodels/auth_viewmodel.dart';
import 'package:velza/services/database_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:velza/views/chat/chat_screen.dart';

import 'package:velza/models/mood_model.dart';
import 'package:velza/models/anonymous_qa_model.dart';
import 'package:velza/models/chat_model.dart';
import 'package:velza/services/e2ee_service.dart';
import 'package:velza/viewmodels/chat_viewmodel.dart';

class UpdatesTab extends StatefulWidget {
  const UpdatesTab({super.key});

  static void openAddStatusComposer(BuildContext context, {bool isQA = false}) {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final user = authVM.currentUserModel;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to post a status')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _StatusComposerScreen(user: user, initialIsQA: isQA),
      ),
    );
  }

  @override
  State<UpdatesTab> createState() => _UpdatesTabState();
}

class _StatusComposerScreen extends StatefulWidget {
  final dynamic user;
  final bool initialIsQA;

  const _StatusComposerScreen({
    required this.user,
    required this.initialIsQA,
  });

  @override
  State<_StatusComposerScreen> createState() => _StatusComposerScreenState();
}

class _StatusComposerScreenState extends State<_StatusComposerScreen> {
  final TextEditingController _textController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  late bool _isQA;
  int _selectedColor = 0xFF6A1B9A;
  bool _isPosting = false;

  final Set<String> _mentionedUserIds = {};
  final Map<String, String> _mentions = {};
  List<UserModel> _allUsers = [];
  bool _isMentioning = false;
  String _mentionQuery = '';

  final List<int> _backgroundColors = const [
    0xFF6A1B9A, // Royal Purple
    0xFF0E0B16, // Velza Midnight
    0xFF1A237E, // Navy
    0xFF004D40, // Emerald
    0xFFB71C1C, // Deep Red
    0xFF880E4F, // Magenta
    0xFFE65100, // Amber / Orange
  ];

  @override
  void initState() {
    super.initState();
    _isQA = widget.initialIsQA;
    if (_isQA) {
      _textController.text = 'Ask me anything! (Anonymous)';
    }
    _textController.addListener(_onTextChanged);
    _loadUsers();
  }

  void _loadUsers() async {
    try {
      final users = await _dbService.streamRegisteredUsers(widget.user.uid).first;
      if (mounted) {
        setState(() {
          _allUsers = users;
        });
      }
    } catch (e) {
      debugPrint('Error loading users for status mentions: $e');
    }
  }

  void _onTextChanged() {
    final text = _textController.text;
    final selection = _textController.selection;
    final cursorPosition = selection.baseOffset;
    if (cursorPosition < 0 || cursorPosition > text.length) {
      if (_isMentioning) {
        setState(() {
          _isMentioning = false;
          _mentionQuery = '';
        });
      }
      return;
    }

    final beforeCursor = text.substring(0, cursorPosition);
    final atIndex = beforeCursor.lastIndexOf('@');
    if (atIndex != -1 && (atIndex == 0 || beforeCursor[atIndex - 1] == ' ' || beforeCursor[atIndex - 1] == '\n')) {
      final query = beforeCursor.substring(atIndex + 1);
      if (!query.contains(' ') && !query.contains('\n')) {
        setState(() {
          _isMentioning = true;
          _mentionQuery = query.toLowerCase();
        });
        return;
      }
    }
    if (_isMentioning) {
      setState(() {
        _isMentioning = false;
        _mentionQuery = '';
      });
    }
  }

  void _selectMention(UserModel user) {
    final text = _textController.text;
    final selection = _textController.selection;
    final cursorPosition = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    final beforeCursor = text.substring(0, cursorPosition);
    final afterCursor = text.substring(cursorPosition);
    final atIndex = beforeCursor.lastIndexOf('@');
    if (atIndex != -1) {
      final newBefore = '${beforeCursor.substring(0, atIndex)}@${user.displayName} ';
      _textController.text = newBefore + afterCursor;
      _textController.selection = TextSelection.collapsed(offset: newBefore.length);
      _mentionedUserIds.add(user.uid);
      _mentions[user.uid] = user.displayName;
      setState(() {
        _isMentioning = false;
        _mentionQuery = '';
      });
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  void _postStatus() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isPosting) return;

    setState(() {
      _isPosting = true;
    });

    try {
      final newStatus = StatusModel(
        statusId: const Uuid().v4(),
        userId: widget.user.uid,
        userName: widget.user.displayName,
        userPhotoUrl: widget.user.photoUrl,
        type: StatusType.text,
        text: text,
        backgroundColor: _selectedColor,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        isQA: _isQA,
        mentionedUserIds: _mentionedUserIds.toList(),
        mentions: _mentions,
      );

      await _dbService.createStatus(newStatus);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status update posted! ✨')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(_selectedColor),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar - Fully inside SafeArea with generous padding
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isQA ? Icons.mark_chat_read_rounded : Icons.quiz_outlined,
                      color: _isQA ? const Color(0xFFD4AF37) : Colors.white,
                    ),
                    tooltip: 'Toggle Anonymous Q&A',
                    onPressed: () {
                      setState(() {
                        _isQA = !_isQA;
                        if (_isQA && _textController.text.trim().isEmpty) {
                          _textController.text = 'Ask me anything! (Anonymous)';
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.color_lens_rounded, color: Colors.white),
                    tooltip: 'Cycle Background Color',
                    onPressed: () {
                      final nextIndex = (_backgroundColors.indexOf(_selectedColor) + 1) % _backgroundColors.length;
                      setState(() {
                        _selectedColor = _backgroundColors[nextIndex];
                      });
                    },
                  ),
                ],
              ),
            ),

            // Optional Q&A active badge
            if (_isQA)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_off_rounded, color: Color(0xFFD4AF37), size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Anonymous Q&A Mode Active',
                      style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Main text input area
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: TextField(
                    controller: _textController,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: _isQA ? 'Type your Q&A prompt...' : 'Type a status...',
                      hintStyle: const TextStyle(color: Colors.white54, fontSize: 26),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),

            // Mention Suggestions Strip
            if (_isMentioning)
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: _allUsers
                      .where((u) =>
                          u.uid != widget.user.uid &&
                          (u.displayName.toLowerCase().contains(_mentionQuery) ||
                              u.email.toLowerCase().contains(_mentionQuery)))
                      .take(5)
                      .map((user) => ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFFD4AF37),
                              backgroundImage: user.photoUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(user.photoUrl)
                                  : null,
                              child: user.photoUrl.isEmpty
                                  ? Text(
                                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                          color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                                    )
                                  : null,
                            ),
                            title: Text(
                              user.displayName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            trailing: const Icon(Icons.alternate_email_rounded, color: Color(0xFFD4AF37), size: 16),
                            onTap: () => _selectMention(user),
                          ))
                      .toList(),
                ),
              ),

            // Bottom Palette + Accessible Send Button (natural thumb position)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(
                children: [
                  ..._backgroundColors.take(5).map((color) {
                    final isSelected = _selectedColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? const Color(0xFFD4AF37) : Colors.white54,
                            width: isSelected ? 2.5 : 1.2,
                          ),
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  _isPosting
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(color: Color(0xFFD4AF37), strokeWidth: 2.5),
                          ),
                        )
                      : FloatingActionButton(
                          heroTag: 'post_status_btn',
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.black,
                          elevation: 4,
                          onPressed: _postStatus,
                          child: const Icon(Icons.send_rounded, size: 24),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdatesTabState extends State<UpdatesTab> {
  final DatabaseService _dbService = DatabaseService();

  void _showMoodPicker(BuildContext context, String currentUid, String currentMoodEmoji) {
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
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set Your Mood',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Friends can see your current vibe next to your name and avatar.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: MoodModel.presetMoods.map((preset) {
                  final isSelected = currentMoodEmoji == preset.emoji;
                  return InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _dbService.updateMood(
                        currentUid,
                        preset.emoji,
                        '0x${preset.color.toARGB32().toRadixString(16)}',
                      );
                      if (context.mounted) {
                        Provider.of<AuthViewModel>(context, listen: false).loadUserProfile(currentUid);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Mood set to ${preset.emoji} ${preset.label}')),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? preset.color.withValues(alpha: 0.25)
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? preset.color : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(preset.emoji, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Text(
                            preset.label,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? preset.color : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              if (currentMoodEmoji.isNotEmpty)
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.clear, size: 16, color: Colors.redAccent),
                    label: const Text('Clear Mood', style: TextStyle(color: Colors.redAccent)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _dbService.updateMood(currentUid, '', '0xFFD4AF37');
                      if (context.mounted) {
                        Provider.of<AuthViewModel>(context, listen: false).loadUserProfile(currentUid);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAuthorInboxDialog(BuildContext context, String currentUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E162B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.mark_email_unread_rounded, color: Color(0xFFD4AF37)),
                    SizedBox(width: 8),
                    Text(
                      'Anonymous Questions Inbox',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<List<AnonymousQAModel>>(
                  stream: _dbService.streamAnonymousQuestions(currentUid),
                  builder: (context, snap) {
                    final questions = snap.data ?? [];
                    if (questions.isEmpty) {
                      return const Center(
                        child: Text(
                          'No anonymous questions yet.\nShare your Q&A status with friends!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: questions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final q = questions[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lock_rounded, size: 14, color: Color(0xFFD4AF37)),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Anonymous',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
                                  ),
                                  const Spacer(),
                                  Text(
                                    DateFormat('MMM d, jm').format(q.createdAt),
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                q.question,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAskQuestionDialog(BuildContext context, StatusModel status, String currentUid) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E162B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.visibility_off_rounded, color: Color(0xFFD4AF37)),
                  const SizedBox(width: 8),
                  Text(
                    'Ask ${status.userName} Anonymously',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Your name and profile are never revealed to the recipient.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Type your anonymous question here...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(ctx);
                    await _dbService.submitAnonymousQuestion(
                      authorUid: status.userId,
                      question: AnonymousQAModel(
                        id: const Uuid().v4(),
                        statusId: status.statusId,
                        question: text,
                        senderUid: currentUid,
                        createdAt: DateTime.now(),
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Anonymous question sent! 💌')),
                      );
                    }
                  },
                  child: const Text('Send Anonymously', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _openStatusViewer(BuildContext context, StatusModel status, String currentUid) {
    final isMe = status.userId == currentUid;
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: SafeArea(
          child: Scaffold(
            backgroundColor: Color(status.backgroundColor),
            appBar: AppBar(
              backgroundColor: Colors.black26,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: status.userPhotoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(status.userPhotoUrl)
                        : null,
                    child: status.userPhotoUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.white, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(status.userName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(
                        DateFormat('jm').format(status.createdAt),
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                if (isMe)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                    onSelected: (val) {
                      if (val == 'delete') {
                        _confirmDeleteStatus(context, ctx, status, currentUid);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                            SizedBox(width: 8),
                            Text('Delete Status', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: status.isQA
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_rounded, size: 16, color: Color(0xFFD4AF37)),
                                SizedBox(width: 6),
                                Text(
                                  'ANONYMOUS Q&A',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD4AF37),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              status.text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Only the recipient can view questions. Sender identity is always hidden.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (status.mentionedUserIds.contains(currentUid))
                            Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.alternate_email_rounded, color: Color(0xFFD4AF37), size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'You were mentioned in this status',
                                    style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          Text(
                            status.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          if (status.mentionedUserIds.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: status.mentionedUserIds.map((uid) {
                                final name = status.mentions?[uid] ?? 'Contact';
                                return ActionChip(
                                  avatar: const Icon(Icons.alternate_email_rounded, size: 14, color: Color(0xFFD4AF37)),
                                  label: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  backgroundColor: Colors.black45,
                                  side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  onPressed: () => _openMentionedUserChat(context, uid, name, currentUid),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
            bottomNavigationBar: status.isQA
                ? Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black38,
                    child: isMe
                        ? ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.inbox_rounded),
                            label: const Text('View Received Questions', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () => _showAuthorInboxDialog(context, currentUid),
                          )
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.visibility_off_rounded),
                            label: const Text('Send Anonymous Question', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () => _showAskQuestionDialog(context, status, currentUid),
                          ),
                  )
                : (!isMe ? _buildPrivateReplyBar(context, ctx, status, currentUid) : null),
          ),
        ),
      ),
    );
  }

  void _openMentionedUserChat(
    BuildContext rootContext,
    String targetUid,
    String targetName,
    String currentUid,
  ) async {
    if (targetUid == currentUid) return;
    try {
      final authVM = Provider.of<AuthViewModel>(rootContext, listen: false);
      final chatVM = Provider.of<ChatViewModel>(rootContext, listen: false);
      final currentUser = authVM.currentUserModel;
      if (currentUser == null) return;

      final targetUser = await DatabaseService().getUserProfile(targetUid);
      if (targetUser == null) return;

      final chatId = await chatVM.startDirectChat(
        currentUser: currentUser,
        otherUser: targetUser,
      );

      final chat = ChatModel(
        id: chatId,
        name: targetUser.displayName,
        photoUrl: targetUser.photoUrl,
        isGroup: false,
        memberIds: [currentUser.uid, targetUser.uid],
        lastMessageText: 'No messages yet',
        lastMessageTime: DateTime.now(),
        unreadCounts: {currentUser.uid: 0, targetUser.uid: 0},
        typingStatus: {currentUser.uid: 'none', targetUser.uid: 'none'},
      );

      if (rootContext.mounted) {
        Navigator.push(
          rootContext,
          MaterialPageRoute(
            builder: (context) => ChatScreen(chat: chat),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error opening chat for mention: $e');
    }
  }

  void _confirmDeleteStatus(BuildContext rootContext, BuildContext dialogCtx, StatusModel status, String currentUid) {
    showDialog(
      context: rootContext,
      builder: (confirmCtx) => AlertDialog(
        backgroundColor: Theme.of(rootContext).brightness == Brightness.dark
            ? const Color(0xFF1E162B)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Status?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this status? It will be removed immediately for all contacts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(confirmCtx);
              Navigator.pop(dialogCtx);
              await _dbService.deleteStatus(status.statusId, currentUid);
              if (rootContext.mounted) {
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(content: Text('Status deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateReplyBar(
    BuildContext rootContext,
    BuildContext viewerCtx,
    StatusModel status,
    String currentUid,
  ) {
    return Container(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: 16,
      ),
      color: Colors.black45,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: () => _openPrivateReplyDialog(rootContext, viewerCtx, status, currentUid),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              children: [
                Icon(Icons.reply_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'Reply privately...',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPrivateReplyDialog(
    BuildContext rootContext,
    BuildContext viewerCtx,
    StatusModel status,
    String currentUid,
  ) {
    final replyController = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Theme.of(rootContext).brightness == Brightness.dark
          ? const Color(0xFF1E162B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Status reference preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C223D) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: const Border(left: BorderSide(color: Color(0xFFD4AF37), width: 3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_stories_rounded, size: 18, color: Color(0xFFD4AF37)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Replying to ${status.userName}\'s Status',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFD4AF37)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              status.text.isNotEmpty ? status.text : (status.caption.isNotEmpty ? status.caption : 'Status update'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Text field + send button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: replyController,
                        autofocus: true,
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Type your private reply...',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0E0B16) : Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: isSending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)))
                          : const Icon(Icons.send_rounded, color: Color(0xFFD4AF37), size: 28),
                      onPressed: isSending
                          ? null
                          : () async {
                              final text = replyController.text.trim();
                              if (text.isEmpty) return;

                              setSheetState(() => isSending = true);
                              final authVM = Provider.of<AuthViewModel>(rootContext, listen: false);
                              final chatVM = Provider.of<ChatViewModel>(rootContext, listen: false);
                              final currentUser = authVM.currentUserModel;
                              if (currentUser == null) return;

                              try {
                                final otherUser = await DatabaseService().getUserProfile(status.userId);
                                if (otherUser == null) {
                                  throw Exception('Recipient user profile not found');
                                }

                                final chatId = await chatVM.startDirectChat(
                                  currentUser: currentUser,
                                  otherUser: otherUser,
                                );

                                final preview = status.text.isNotEmpty
                                    ? status.text
                                    : (status.caption.isNotEmpty ? status.caption : 'Status');

                                String textToSend = text;
                                bool isEncrypted = false;
                                try {
                                  final cipher = await E2eeService().encryptMessage(
                                    chatId: chatId,
                                    otherUid: status.userId,
                                    plaintext: text,
                                  );
                                  if (E2eeService.isPayloadEncrypted(cipher)) {
                                    textToSend = cipher;
                                    isEncrypted = true;
                                    E2eeService().cacheDecrypted(cipher, text);
                                  }
                                } catch (e) {
                                  debugPrint('E2EE private reply encryption fallback: $e');
                                }

                                await chatVM.sendTextMessage(
                                  chatId: chatId,
                                  senderId: currentUser.uid,
                                  senderName: currentUser.displayName,
                                  text: textToSend,
                                  isEncrypted: isEncrypted,
                                  replyToMessageId: 'status_${status.statusId}',
                                  replyToText: '[Status] $preview',
                                  replyToSenderId: status.userId,
                                  replyToSenderName: status.userName,
                                );

                                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                if (rootContext.mounted) {
                                  ScaffoldMessenger.of(rootContext).showSnackBar(
                                    SnackBar(content: Text('Private reply sent to ${status.userName}')),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isSending = false);
                                if (rootContext.mounted) {
                                  ScaffoldMessenger.of(rootContext).showSnackBar(
                                    SnackBar(content: Text('Error sending reply: $e')),
                                  );
                                }
                              }
                            },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authVM = Provider.of<AuthViewModel>(context);
    final currentUser = authVM.currentUserModel;
    final currentUid = currentUser?.uid ?? '';

    return StreamBuilder<List<StatusModel>>(
      stream: _dbService.streamActiveStatuses(),
      builder: (context, snapshot) {
        final allStatuses = snapshot.data ?? [];
        final myStatuses = allStatuses.where((s) => s.userId == currentUid).toList();
        final otherStatuses = allStatuses.where((s) => s.userId != currentUid).toList();
        final recentUpdates = otherStatuses.where((s) => !s.viewedBy.contains(currentUid)).toList();
        final viewedUpdates = otherStatuses.where((s) => s.viewedBy.contains(currentUid)).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          children: [
            // Mood Status Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6A1B9A).withValues(alpha: 0.3),
                    const Color(0xFF1E162B).withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black38,
                      border: Border.all(
                        color: Color(currentUser?.moodColor ?? 0xFFD4AF37),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        currentUser?.moodEmoji?.isNotEmpty == true ? currentUser!.moodEmoji! : '✨',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Mood',
                          style: TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentUser?.moodEmoji?.isNotEmpty == true
                              ? '${currentUser!.moodEmoji} ${MoodModel.presetMoods.firstWhere((m) => m.emoji == currentUser.moodEmoji, orElse: () => const MoodModel(emoji: '', label: 'Active', colorValue: 0xFFFFC107)).label}'
                              : 'What\'s your vibe right now?',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFD4AF37),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: () => _showMoodPicker(context, currentUid, currentUser?.moodEmoji ?? ''),
                    child: Text(currentUser?.moodEmoji?.isNotEmpty == true ? 'Change' : 'Set Mood'),
                  ),
                ],
              ),
            ),

            // My Status Section
            ListTile(
              leading: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: myStatuses.isNotEmpty ? const Color(0xFFD4AF37) : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFF6A1B9A),
                      backgroundImage: currentUser?.photoUrl != null && currentUser!.photoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(currentUser.photoUrl)
                          : null,
                      child: currentUser?.photoUrl == null || currentUser!.photoUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD4AF37),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.black),
                    ),
                  ),
                ],
              ),
              title: const Text('My Status', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                myStatuses.isNotEmpty
                    ? '${myStatuses.length} status update(s) • Tap to view'
                    : 'Tap to add status update',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
              trailing: myStatuses.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFD4AF37)),
                      tooltip: 'Add another status',
                      onPressed: () => UpdatesTab.openAddStatusComposer(context),
                    )
                  : null,
              onTap: () {
                if (myStatuses.isNotEmpty) {
                  _openStatusViewer(context, myStatuses.first, currentUid);
                } else {
                  UpdatesTab.openAddStatusComposer(context);
                }
              },
            ),

            const Divider(height: 24, thickness: 0.5),

            // Recent Updates
            if (recentUpdates.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Recent updates',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              ...recentUpdates.map((status) => ListTile(
                    leading: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF6A1B9A), width: 2.5),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundImage: status.userPhotoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(status.userPhotoUrl)
                            : null,
                        child: status.userPhotoUrl.isEmpty
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                    ),
                    title: Text(status.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(DateFormat('jm').format(status.createdAt)),
                    onTap: () => _openStatusViewer(context, status, currentUid),
                  )),
            ],

            // Viewed Updates
            if (viewedUpdates.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Viewed updates',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
              ...viewedUpdates.map((status) => ListTile(
                    leading: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade600, width: 1.5),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundImage: status.userPhotoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(status.userPhotoUrl)
                            : null,
                        child: status.userPhotoUrl.isEmpty
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                    ),
                    title: Text(status.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(DateFormat('jm').format(status.createdAt)),
                    onTap: () => _openStatusViewer(context, status, currentUid),
                  )),
            ],

            if (recentUpdates.isEmpty && viewedUpdates.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No status updates from contacts yet',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
