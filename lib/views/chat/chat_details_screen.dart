import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:velza/models/chat_model.dart';
import 'package:velza/models/user_model.dart';
import 'package:velza/models/relationship_model.dart';
import 'package:velza/models/mood_model.dart';
import 'package:velza/services/database_service.dart';
import 'package:velza/viewmodels/chat_viewmodel.dart';
import 'package:velza/viewmodels/settings_viewmodel.dart';
import 'package:velza/views/chat/wallpaper_picker_dialog.dart';
import 'package:velza/views/chat/nickname_dialog.dart';

class ChatDetailsScreen extends StatelessWidget {
  final ChatModel chat;
  final String otherUid;
  final String currentUid;
  final UserModel? initialUser;

  const ChatDetailsScreen({
    super.key,
    required this.chat,
    required this.otherUid,
    required this.currentUid,
    this.initialUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chatVM = Provider.of<ChatViewModel>(context);
    final settingsVM = Provider.of<SettingsViewModel>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Contact Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? const Color(0xFF1E162B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<UserModel>(
        stream: chatVM.streamUserProfile(otherUid),
        initialData: initialUser,
        builder: (context, userSnap) {
          final user = userSnap.data ?? initialUser;
          final displayName = user?.displayName.isNotEmpty == true
              ? user!.displayName
              : chat.name;
          final isOnline = user?.isOnline ?? false;

          String presenceText = isOnline ? 'Online' : 'Offline';
          if (user != null && !isOnline) {
            final diff = DateTime.now().difference(user.lastSeen);
            if (diff.inDays == 0) {
              presenceText = 'Last seen today at ${DateFormat('jm').format(user.lastSeen)}';
            } else {
              presenceText = 'Last seen ${DateFormat('MMM d, jm').format(user.lastSeen)}';
            }
          }

          return StreamBuilder<MutualNicknameInfo>(
            stream: chatVM.streamMutualNicknames(currentUid: currentUid, otherUid: otherUid, chatId: chat.id),
            builder: (context, nickSnap) {
              final myNickname = nickSnap.data?.nicknameGivenByMe ?? chatVM.getNickname(otherUid) ?? '';
              final theirNicknameForMe = nickSnap.data?.nicknameGivenToMe ?? '';

              return StreamBuilder<RelationshipModel?>(
                stream: chatVM.streamRelationship(currentUid, otherUid),
                builder: (context, relSnap) {
                  final rel = relSnap.data;
                  final sharedNickname = rel?.sharedNickname;

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    children: [
                  // --- Header Avatar & Name Card ---
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E162B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar with Mood indicator and online badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: const Color(0xFF6A1B9A),
                              backgroundImage: user?.photoUrl.isNotEmpty == true
                                  ? CachedNetworkImageProvider(user!.photoUrl)
                                  : null,
                              child: user?.photoUrl.isEmpty != false
                                  ? const Icon(Icons.person, size: 46, color: Colors.white)
                                  : null,
                            ),
                            // Online indicator dot
                            Positioned(
                              bottom: 2,
                              left: 2,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: isOnline ? Colors.green : Colors.grey,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF1E162B) : Colors.white,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                            // Mood Emoji
                            if (user?.moodEmoji != null && user!.moodEmoji!.isNotEmpty)
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E162B) : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Color(user.moodColor ?? 0xFFD4AF37),
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(user.moodEmoji!, style: const TextStyle(fontSize: 16)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Primary Name
                        Text(
                          myNickname.isNotEmpty ? myNickname : (sharedNickname?.isNotEmpty == true ? sharedNickname! : displayName),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        if (myNickname.isNotEmpty || sharedNickname?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Profile: $displayName',
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        ],
                        const SizedBox(height: 6),
                        // Presence
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: isOnline ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(
                              presenceText,
                              style: TextStyle(
                                fontSize: 13,
                                color: isOnline ? Colors.green : (isDark ? Colors.white60 : Colors.black54),
                                fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        // Phone Number
                        if (user?.phoneNumber.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(
                            user!.phoneNumber,
                            style: const TextStyle(fontSize: 13, color: Color(0xFFD4AF37), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- SECTION 1: PERSON ---
                  _buildSectionHeader('PERSON', isDark),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E162B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        // Your Nickname for this Person
                        ListTile(
                          leading: const Icon(Icons.badge_rounded, color: Color(0xFFD4AF37)),
                          title: const Text('Your nickname for this person', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            myNickname.isNotEmpty
                                ? myNickname
                                : 'No nickname set (only visible to you)',
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (myNickname.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: Colors.redAccent, size: 20),
                                  tooltip: 'Remove nickname',
                                  onPressed: () async {
                                    await chatVM.deleteNickname(currentUid: currentUid, targetUid: otherUid, chatId: chat.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Nickname removed')),
                                      );
                                    }
                                  },
                                ),
                              IconButton(
                                icon: Icon(myNickname.isNotEmpty ? Icons.edit_rounded : Icons.add_rounded, color: const Color(0xFFD4AF37), size: 20),
                                tooltip: myNickname.isNotEmpty ? 'Edit nickname' : 'Set nickname',
                                onPressed: () {
                                  NicknameDialog.show(
                                    context,
                                    targetUid: otherUid,
                                    originalName: displayName,
                                    currentNickname: myNickname,
                                    onSave: (newNick) async {
                                      await chatVM.setNickname(currentUid: currentUid, targetUid: otherUid, nickname: newNick, chatId: chat.id);
                                    },
                                    onRemove: myNickname.isNotEmpty
                                        ? () async {
                                            await chatVM.deleteNickname(currentUid: currentUid, targetUid: otherUid, chatId: chat.id);
                                          }
                                        : null,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        if (theirNicknameForMe.isNotEmpty) ...[
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.star_rounded, color: Color(0xFFD4AF37)),
                            title: Text('Nickname set for you by $displayName', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '“$theirNicknameForMe”',
                              style: TextStyle(
                                color: isDark ? const Color(0xFFFFD54F) : const Color(0xFF6A1B9A),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                        const Divider(height: 1),
                        // Shared Relationship Nickname (Mutual/Dual)
                        ListTile(
                          leading: const Icon(Icons.favorite_rounded, color: Color(0xFFD4AF37)),
                          title: const Text('Shared Relationship Nickname', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            sharedNickname != null && sharedNickname.isNotEmpty
                                ? sharedNickname
                                : 'No shared nickname (tap to set together)',
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              sharedNickname != null && sharedNickname.isNotEmpty ? Icons.edit_rounded : Icons.add_rounded,
                              color: const Color(0xFFD4AF37),
                              size: 20,
                            ),
                            tooltip: 'Set shared nickname',
                            onPressed: () => _showEditSharedNicknameDialog(context, chatVM, sharedNickname ?? ''),
                          ),
                        ),
                        const Divider(height: 1),
                        // Mood
                        ListTile(
                          leading: const Icon(Icons.mood_rounded, color: Color(0xFF6A1B9A)),
                          title: const Text('Mood Status', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            user?.moodEmoji != null && user!.moodEmoji!.isNotEmpty
                                ? '${user.moodEmoji} ${MoodModel.presetMoods.firstWhere((m) => m.emoji == user.moodEmoji, orElse: () => const MoodModel(emoji: '', label: 'Active', colorValue: 0xFFFFC107)).label}'
                                : 'No mood set',
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        const Divider(height: 1),
                        // Follow Status
                        ListTile(
                          leading: const Icon(Icons.person_add_rounded, color: Colors.blueAccent),
                          title: const Text('Follow Status', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            rel?.isAccepted == true
                                ? 'Following (Connected)'
                                : (rel?.isPending == true ? 'Request Pending' : 'Not Following'),
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                          ),
                          trailing: rel?.isAccepted == true
                              ? TextButton(
                                  onPressed: () async {
                                    await chatVM.unfollow(currentUid, otherUid);
                                  },
                                  child: const Text('Unfollow', style: TextStyle(color: Colors.redAccent)),
                                )
                              : (rel?.isPending == true
                                  ? const Text('Requested', style: TextStyle(color: Colors.orangeAccent))
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6A1B9A),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () async {
                                        await chatVM.sendFollowRequest(currentUid, otherUid);
                                      },
                                      child: const Text('Follow'),
                                    )),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- SECTION 2: CHAT & MEDIA ---
                  _buildSectionHeader('CHAT', isDark),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E162B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.search_rounded, color: Color(0xFFD4AF37)),
                          title: const Text('Search Messages', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Filter by keyword, date, or sender'),
                          onTap: () {
                            Navigator.pop(context); // Return to chat to open search
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.wallpaper_rounded, color: Colors.purpleAccent),
                          title: const Text('Chat Wallpaper & Theme', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Choose personal luxury theme or custom gallery photo'),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => WallpaperPickerDialog(
                                chatId: chat.id,
                                currentWallpaper: chatVM.getPersonalWallpaper(currentUid, chat.id),
                                onWallpaperSelected: (wp) {
                                  chatVM.setPersonalWallpaper(
                                    uid: currentUid,
                                    chatId: chat.id,
                                    wallpaper: wp,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.delete_sweep_rounded, color: Colors.amber),
                          title: const Text('Clear Chat', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Clear message history for yourself'),
                          onTap: () => _showClearChatDialog(context, chatVM),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- SECTION 3: PRIVACY & SAFETY ---
                  _buildSectionHeader('PRIVACY', isDark),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E162B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.done_all_rounded, color: Color(0xFFD4AF37)),
                          title: const Text('Read Receipts', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Show double blue/gold ticks when messages are read'),
                          value: settingsVM.readReceiptsEnabled,
                          activeThumbColor: const Color(0xFFD4AF37),
                          onChanged: (val) {
                            settingsVM.toggleReadReceipts(val);
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.block_rounded, color: Colors.redAccent),
                          title: const Text('Block User', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent)),
                          subtitle: const Text('Blocked contacts cannot call or message you'),
                          onTap: () => _showBlockUserDialog(context, chatVM),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.report_problem_rounded, color: Colors.orangeAccent),
                          title: const Text('Report User', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orangeAccent)),
                          subtitle: const Text('Report spam or inappropriate content'),
                          onTap: () => _showReportUserDialog(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              );
            },
          );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF6A1B9A),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showEditSharedNicknameDialog(BuildContext context, ChatViewModel chatVM, String currentNickname) {
    final controller = TextEditingController(text: currentNickname);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E162B)
            : Colors.white,
        title: const Text('Shared Relationship Nickname', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This nickname is visible to both of you, but strictly confidential from any third user.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. Bestie ❤️, Partner ✨',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (currentNickname.isNotEmpty)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await chatVM.setSharedRelationshipNickname(currentUid, otherUid, '');
              },
              child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newNick = controller.text.trim();
              Navigator.pop(ctx);
              await chatVM.setSharedRelationshipNickname(currentUid, otherUid, newNick);
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showClearChatDialog(BuildContext context, ChatViewModel chatVM) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E162B)
            : Colors.white,
        title: const Text('Clear Chat?'),
        content: const Text('Messages will be cleared for you only. The other participant will still have their message history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await chatVM.clearChatForUser(chat.id, currentUid);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat history cleared for you')),
                );
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showBlockUserDialog(BuildContext context, ChatViewModel chatVM) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E162B)
            : Colors.white,
        title: const Text('Block User?'),
        content: const Text('Blocked users will not be able to send you messages or view your presence.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await chatVM.blockUserRelationship(currentUid, otherUid);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked')));
              }
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _showReportUserDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E162B)
            : Colors.white,
        title: const Text('Report User'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Enter reason for report...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted. Thank you.')));
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }
}
