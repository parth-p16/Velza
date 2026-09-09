import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:velza/models/chat_model.dart';
import 'package:velza/models/user_model.dart';
import 'package:velza/viewmodels/auth_viewmodel.dart';
import 'package:velza/viewmodels/chat_viewmodel.dart';
import 'package:velza/views/chat/chat_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatListTab extends StatefulWidget {
  const ChatListTab({super.key});

  @override
  State<ChatListTab> createState() => _ChatListTabState();
}

class _ChatListTabState extends State<ChatListTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUid = Provider.of<AuthViewModel>(context, listen: false).currentUserModel?.uid ?? '';
      if (currentUid.isNotEmpty) {
        Provider.of<ChatViewModel>(context, listen: false).initNicknames(currentUid);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper to extract the single other user out of the chat model memberIds list
  String _getOtherUserId(ChatModel chat, String currentUid) {
    return chat.memberIds.firstWhere((id) => id != currentUid, orElse: () => '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authVM = Provider.of<AuthViewModel>(context);
    final chatVM = Provider.of<ChatViewModel>(context);
    final isDark = theme.brightness == Brightness.dark;

    final String currentUid = authVM.currentUserModel?.uid ?? '';

    return Column(
      children: [
        // Premium Local Chat Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.toLowerCase().trim();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search chats...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1E162B) : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Live Chat list stream
        Expanded(
          child: StreamBuilder<List<ChatModel>>(
            stream: chatVM.streamUserChats(currentUid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final chats = snapshot.data ?? [];
              
              // Filter chats locally based on search input
              final filteredChats = chats.where((chat) {
                if (_searchQuery.isEmpty) return true;
                final otherUserId = _getOtherUserId(chat, currentUid);
                final effectiveName = chatVM.getEffectiveName(otherUserId, chat.name).toLowerCase();
                return chat.name.toLowerCase().contains(_searchQuery) ||
                    effectiveName.contains(_searchQuery) ||
                    chat.lastMessageText.toLowerCase().contains(_searchQuery);
              }).toList();

              if (filteredChats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty ? 'No active conversations' : 'No chats match "$_searchQuery"',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: filteredChats.length,
                separatorBuilder: (context, index) => Divider(
                  indent: 72,
                  endIndent: 16,
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final chat = filteredChats[index];
                  final int unreadCount = chat.unreadCounts[currentUid] ?? 0;
                  final String lastMsgTimeStr = DateFormat('jm').format(chat.lastMessageTime);

                  if (chat.isGroup) {
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFD4AF37),
                        backgroundImage: chat.photoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(chat.photoUrl)
                            : null,
                        child: chat.photoUrl.isEmpty
                            ? const Icon(Icons.group_rounded, color: Colors.white)
                            : null,
                      ),
                      title: Text(
                        chat.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        chat.lastMessageText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unreadCount > 0 ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                          fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(lastMsgTimeStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          if (unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6A1B9A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        chatVM.clearUnreadCount(chat.id, currentUid);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(chat: chat),
                          ),
                        );
                      },
                    );
                  } else {
                    // Single 1-1 Chat: Use cached user profile tile to prevent duplicate streams & rebuilds
                    final String otherUserId = _getOtherUserId(chat, currentUid);
                    return _UserChatTile(
                      key: ValueKey(chat.id),
                      chat: chat,
                      otherUserId: otherUserId,
                      currentUid: currentUid,
                      unreadCount: unreadCount,
                      lastMsgTimeStr: lastMsgTimeStr,
                      isDark: isDark,
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserChatTile extends StatefulWidget {
  final ChatModel chat;
  final String otherUserId;
  final String currentUid;
  final int unreadCount;
  final String lastMsgTimeStr;
  final bool isDark;

  const _UserChatTile({
    super.key,
    required this.chat,
    required this.otherUserId,
    required this.currentUid,
    required this.unreadCount,
    required this.lastMsgTimeStr,
    required this.isDark,
  });

  @override
  State<_UserChatTile> createState() => _UserChatTileState();
}

class _UserChatTileState extends State<_UserChatTile> {
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void didUpdateWidget(covariant _UserChatTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.otherUserId != widget.otherUserId) {
      _loadUser();
    }
  }

  void _loadUser() {
    final chatVM = Provider.of<ChatViewModel>(context, listen: false);
    final cached = chatVM.getCachedUser(widget.otherUserId);
    if (cached != null) {
      _user = cached;
    } else {
      chatVM.fetchUserCached(widget.otherUserId).then((u) {
        if (mounted && u != null) {
          setState(() {
            _user = u;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatVM = Provider.of<ChatViewModel>(context);
    final fallbackName = (_user != null && _user!.displayName.isNotEmpty)
        ? _user!.displayName
        : widget.chat.name;
    final displayName = chatVM.getEffectiveName(widget.otherUserId, fallbackName);
    final photoUrl = _user?.photoUrl ?? '';
    final isOnline = _user?.isOnline ?? false;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFF6A1B9A),
            backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
            child: photoUrl.isEmpty
                ? const Icon(Icons.person_rounded, color: Colors.white)
                : null,
          ),
          if (isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isDark ? const Color(0xFF0E0B16) : Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        displayName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        widget.chat.lastMessageText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: widget.unreadCount > 0 ? (widget.isDark ? Colors.white : Colors.black87) : Colors.grey,
          fontWeight: widget.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(widget.lastMsgTimeStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          if (widget.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6A1B9A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      onTap: () {
        chatVM.clearUnreadCount(widget.chat.id, widget.currentUid);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(chat: widget.chat),
          ),
        );
      },
    );
  }
}
