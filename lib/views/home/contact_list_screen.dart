import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:velza/models/user_model.dart';
import 'package:velza/models/chat_model.dart';
import 'package:velza/viewmodels/auth_viewmodel.dart';
import 'package:velza/viewmodels/chat_viewmodel.dart';
import 'package:velza/views/chat/chat_screen.dart';
import 'package:velza/views/chat/nickname_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:velza/models/relationship_model.dart';

class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key});

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  final TextEditingController _queryController = TextEditingController();
  int _streamKey = 0; // Increment to force stream reconnection on Retry

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
    _queryController.dispose();
    super.dispose();
  }

  void _openNicknameDialog(UserModel user, ChatViewModel chatVM, String currentUid) {
    showDialog(
      context: context,
      builder: (ctx) => NicknameDialog(
        targetUid: user.uid,
        originalName: user.displayName,
        currentNickname: chatVM.getNickname(user.uid) ?? '',
        onSave: (newNick) async {
          if (currentUid.isNotEmpty) {
            await chatVM.setNickname(currentUid: currentUid, targetUid: user.uid, nickname: newNick);
          }
        },
        onRemove: () async {
          if (currentUid.isNotEmpty) {
            await chatVM.deleteNickname(currentUid: currentUid, targetUid: user.uid);
          }
        },
      ),
    );
  }

  void _retryConnection() {
    setState(() {
      _streamKey++;
    });
  }

  void _openChat(ChatViewModel chatVM, UserModel currentUser, UserModel otherUser) async {
    try {
      final bool canChat = await chatVM.canUserChat(currentUser.uid, otherUser.uid);
      if (!canChat) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Follow to Chat'),
            content: Text(
              'To protect privacy on Velza, you must follow ${otherUser.displayName} and have your follow request accepted before starting a chat.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await chatVM.sendFollowRequest(currentUser.uid, otherUser.uid);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Follow request sent to ${otherUser.displayName}')),
                    );
                  }
                },
                child: const Text('Send Follow Request'),
              ),
            ],
          ),
        );
        return;
      }

      final String chatId = await chatVM.startDirectChat(
        currentUser: currentUser,
        otherUser: otherUser,
      );

      final chat = ChatModel(
        id: chatId,
        name: otherUser.displayName,
        photoUrl: otherUser.photoUrl,
        isGroup: false,
        memberIds: [currentUser.uid, otherUser.uid],
        lastMessageText: 'No messages yet',
        lastMessageTime: DateTime.now(),
        unreadCounts: {currentUser.uid: 0, otherUser.uid: 0},
        typingStatus: {currentUser.uid: 'none', otherUser.uid: 'none'},
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(chat: chat),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authVM = Provider.of<AuthViewModel>(context);
    final chatVM = Provider.of<ChatViewModel>(context);
    final isDark = theme.brightness == Brightness.dark;

    final String currentUid = authVM.currentUserModel?.uid ?? authVM.firebaseUser?.uid ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Search & Find Users', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? const Color(0xFF1E162B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Contacts',
            onPressed: _retryConnection,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _retryConnection();
            await Future.delayed(const Duration(milliseconds: 600));
          },
          color: const Color(0xFF6A1B9A),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                // Search Input with search & refresh buttons
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        onChanged: (_) {
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by name, email, or phone...',
                          prefixIcon: const Icon(Icons.person_search_rounded),
                          suffixIcon: _queryController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 20),
                                  onPressed: () {
                                    _queryController.clear();
                                    setState(() {});
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
                  ],
                ),
                const SizedBox(height: 12),

                // Incoming Follow Requests Banner
                StreamBuilder<List<RelationshipModel>>(
                  stream: chatVM.streamIncomingFollowRequests(currentUid),
                  builder: (context, reqSnap) {
                    final requests = reqSnap.data ?? [];
                    if (requests.isEmpty) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A1938) : const Color(0xFFF3E5F5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF8E24AA), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_add_rounded, color: Color(0xFFD4AF37), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Follow Requests (${requests.length})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...requests.map((req) {
                            return FutureBuilder<UserModel?>(
                              future: chatVM.fetchUserCached(req.fromUid),
                              builder: (context, userSnap) {
                                final senderName = userSnap.data?.displayName ??
                                    (req.fromUid.length > 8 ? '${req.fromUid.substring(0, 8)}...' : req.fromUid);

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          senderName,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                                            tooltip: 'Accept',
                                            onPressed: () => chatVM.acceptFollowRequest(req.fromUid, currentUid),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                                            tooltip: 'Reject',
                                            onPressed: () => chatVM.rejectFollowRequest(req.fromUid, currentUid),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.block_rounded, color: Colors.grey, size: 20),
                                            tooltip: 'Block',
                                            onPressed: () => chatVM.blockUserRelationship(currentUid, req.fromUid),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),

            // Real-time Firestore Registered Users Stream
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                key: ValueKey('users_stream_$_streamKey'),
                stream: chatVM.streamRegisteredUsers(currentUid),
                builder: (context, snapshot) {
                  // 1. Error State: NEVER show "No registered users" when an error occurred
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    String errorMessage = error.toString();
                    String helpText = 'Please check your connection and ensure Firestore is reachable.';
                    
                    if (error is FirebaseException) {
                      errorMessage = "[${error.code}] ${error.message ?? 'Firestore operation failed.'}";
                      if (error.code == 'permission-denied') {
                        helpText = 'Firebase Security Rules in "velza-5ab77" are restricting access.\nEnsure rules allow authenticated reads:\nallow read, write: if request.auth != null;';
                      } else if (error.code == 'unavailable') {
                        helpText = 'Cloud Firestore service is currently unavailable or disabled in Firebase project "velza-5ab77".';
                      }
                    } else if (errorMessage.contains('TimeoutException') || errorMessage.contains('timeout')) {
                      helpText = 'Cloud Firestore for project "velza-5ab77" did not respond.\nEnsure Cloud Firestore Database is created and active at:\nhttps://console.firebase.google.com/project/velza-5ab77/firestore';
                    }

                    return Center(
                      child: SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2A1526) : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.shade400, width: 1.2),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              const Text(
                                'Firestore Connection / Query Error',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                errorMessage,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black26 : Colors.white60,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Project ID: velza-5ab77\nAuth UID: ${currentUid.isNotEmpty ? currentUid : "(not authenticated)"}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                helpText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _retryConnection,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry Connection'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6A1B9A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // 2. Loading State
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF6A1B9A)),
                          SizedBox(height: 16),
                          Text(
                            'Connecting to Cloud Firestore (velza-5ab77)...',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  // 3. Data Processed: Filter locally based on query input
                  final allUsers = snapshot.data ?? [];
                  final queryTrimmed = _queryController.text.trim();
                  final List<UserModel> filteredUsers;

                  if (queryTrimmed.isEmpty) {
                    filteredUsers = allUsers;
                  } else {
                    final queryLower = queryTrimmed.toLowerCase();
                    final queryDigits = queryTrimmed.replaceAll(RegExp(r'\D'), '');

                    filteredUsers = allUsers.where((user) {
                      final effectiveName = chatVM.getEffectiveName(user.uid, user.displayName);
                      final nameMatch = user.displayName.toLowerCase().contains(queryLower) ||
                          effectiveName.toLowerCase().contains(queryLower) ||
                          user.searchableName.contains(queryLower);
                      final emailMatch = user.email.toLowerCase().contains(queryLower);
                      final userPhoneDigits = user.phoneNumber.replaceAll(RegExp(r'\D'), '');
                      final phoneMatch = (queryDigits.isNotEmpty &&
                              (userPhoneDigits.contains(queryDigits) || queryDigits.contains(userPhoneDigits))) ||
                          user.phoneNumber.contains(queryTrimmed);
                      return nameMatch || emailMatch || phoneMatch;
                    }).toList();
                  }

                  debugPrint("[Velza FindUsers UI] Total registered users in stream: ${allUsers.length} | Query: '$queryTrimmed' | Filtered results: ${filteredUsers.length} user(s)");

                  // 4. Empty State: Only shown when query actually succeeded and returned 0 users
                  if (filteredUsers.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              queryTrimmed.isNotEmpty
                                  ? 'No registered Velza users matching "$queryTrimmed".'
                                  : 'No other registered Velza users found in project velza-5ab77.',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(
                                'Tip: When any second user logs in on another device or signs up, they will appear here automatically in real time.',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _retryConnection,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Refresh'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF6A1B9A)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // 5. Success List: Display registered users
                  return ListView.separated(
                    itemCount: filteredUsers.length,
                    separatorBuilder: (context, index) => Divider(
                      indent: 72,
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final nickname = chatVM.getNickname(user.uid);
                      final effectiveName = chatVM.getEffectiveName(user.uid, user.displayName);
                      final String contactInfo = user.email.isNotEmpty
                          ? user.email
                          : (user.phoneNumber.isNotEmpty ? user.phoneNumber : 'Velza User');

                      return ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF6A1B9A),
                              backgroundImage: user.photoUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(user.photoUrl)
                                  : null,
                              child: user.photoUrl.isEmpty
                                  ? const Icon(Icons.person_rounded, color: Colors.white)
                                  : null,
                            ),
                            if (user.isOnline)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent.shade400,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF121212) : Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                effectiveName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (nickname != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '(${user.displayName})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          contactInfo,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                nickname != null ? Icons.badge_rounded : Icons.badge_outlined,
                                color: const Color(0xFFD4AF37),
                                size: 20,
                              ),
                              tooltip: nickname != null ? 'Edit Nickname ($nickname)' : 'Set Nickname',
                              onPressed: () => _openNicknameDialog(user, chatVM, currentUid),
                            ),
                            StreamBuilder<RelationshipModel?>(
                              stream: chatVM.streamRelationship(currentUid, user.uid),
                              builder: (context, relSnap) {
                                final rel = relSnap.data;
                                final isAccepted = rel?.isAccepted == true;
                                final isPending = rel?.isPending == true;
                                final isBlocked = rel?.isBlocked == true;

                                if (isAccepted) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          color: Colors.green.withValues(alpha: 0.15),
                                        ),
                                        child: const Text('Following', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                                        onSelected: (action) async {
                                          if (action == 'unfollow') {
                                            await chatVM.unfollow(currentUid, user.uid);
                                          } else if (action == 'block') {
                                            await chatVM.blockUserRelationship(currentUid, user.uid);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'unfollow',
                                            child: Row(
                                              children: [
                                                Icon(Icons.person_remove_rounded, size: 18, color: Colors.orange),
                                                SizedBox(width: 8),
                                                Text('Unfollow'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'block',
                                            child: Row(
                                              children: [
                                                Icon(Icons.block_rounded, size: 18, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Block'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                } else if (isPending) {
                                  if (rel?.fromUid == currentUid) {
                                    // I sent the request -> Requested
                                    return TextButton(
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.orange.withValues(alpha: 0.15),
                                        foregroundColor: Colors.orange,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        minimumSize: const Size(50, 28),
                                      ),
                                      onPressed: () async {
                                        await chatVM.unfollow(currentUid, user.uid);
                                      },
                                      child: const Text('Requested', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    );
                                  } else {
                                    // Sent to me -> Accept / Reject
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                                          tooltip: 'Accept',
                                          onPressed: () => chatVM.acceptFollowRequest(user.uid, currentUid),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cancel_rounded, color: Colors.red, size: 22),
                                          tooltip: 'Reject',
                                          onPressed: () => chatVM.rejectFollowRequest(user.uid, currentUid),
                                        ),
                                      ],
                                    );
                                  }
                                } else if (isBlocked) {
                                  if (rel?.blockedBy == currentUid) {
                                    return TextButton(
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.red.withValues(alpha: 0.15),
                                        foregroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        minimumSize: const Size(50, 28),
                                      ),
                                      onPressed: () async {
                                        await chatVM.unblockUserRelationship(currentUid, user.uid);
                                      },
                                      child: const Text('Blocked', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    );
                                  } else {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: Colors.grey.withValues(alpha: 0.15),
                                      ),
                                      child: const Text('Unavailable', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    );
                                  }
                                } else {
                                  return TextButton(
                                    style: TextButton.styleFrom(
                                      backgroundColor: const Color(0xFF6A1B9A).withValues(alpha: 0.12),
                                      foregroundColor: const Color(0xFF6A1B9A),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                      minimumSize: const Size(50, 28),
                                    ),
                                    onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      final targetName = user.displayName;
                                      await chatVM.sendFollowRequest(currentUid, user.uid);
                                      if (mounted) {
                                        messenger.showSnackBar(
                                          SnackBar(content: Text('Follow request sent to $targetName')),
                                        );
                                      }
                                    },
                                    child: const Text('Follow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          final currentUser = authVM.currentUserModel ??
                              UserModel(
                                uid: currentUid,
                                phoneNumber: authVM.firebaseUser?.phoneNumber ?? '',
                                email: authVM.currentUserModel?.email ?? authVM.firebaseUser?.email ?? '',
                                displayName: authVM.firebaseUser?.displayName ?? 'Velza User',
                                photoUrl: authVM.firebaseUser?.photoURL ?? '',
                                isOnline: true,
                                typingTo: 'none',
                                createdAt: DateTime.now(),
                                lastSeen: DateTime.now(),
                                blockedUsers: [],
                              );
                          _openChat(chatVM, currentUser, user);
                        },
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
  ),
);
  }
}
