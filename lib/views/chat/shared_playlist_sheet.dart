import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SharedPlaylistSheet extends StatefulWidget {
  final String chatId;
  final String currentUid;
  final String currentUserName;

  const SharedPlaylistSheet({
    super.key,
    required this.chatId,
    required this.currentUid,
    required this.currentUserName,
  });

  static void show(
    BuildContext context, {
    required String chatId,
    required String currentUid,
    required String currentUserName,
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
      builder: (_) => SharedPlaylistSheet(
        chatId: chatId,
        currentUid: currentUid,
        currentUserName: currentUserName,
      ),
    );
  }

  @override
  State<SharedPlaylistSheet> createState() => _SharedPlaylistSheetState();
}

class _SharedPlaylistSheetState extends State<SharedPlaylistSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  CollectionReference get _playlistRef => FirebaseFirestore.instance
      .collection('chats')
      .doc(widget.chatId)
      .collection('playlists');

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _showAddTrackDialog() {
    _titleController.clear();
    _artistController.clear();
    _linkController.clear();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Song to Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Song Title', hintText: 'e.g. Starboy'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _artistController,
              decoration: const InputDecoration(labelText: 'Artist', hintText: 'e.g. The Weeknd'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _linkController,
              decoration: const InputDecoration(labelText: 'Music Link (Optional)', hintText: 'Spotify/Apple Music/YouTube URL'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final title = _titleController.text.trim();
              final artist = _artistController.text.trim();
              if (title.isEmpty) return;

              Navigator.pop(dialogCtx);

              await _playlistRef.add({
                'title': title,
                'artist': artist.isNotEmpty ? artist : 'Unknown Artist',
                'link': _linkController.text.trim(),
                'addedBy': widget.currentUserName,
                'addedByUid': widget.currentUid,
                'addedAt': FieldValue.serverTimestamp(),
              });
            },
            child: const Text('Add Song'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
            child: Row(
              children: [
                const Icon(Icons.playlist_play_rounded, color: Color(0xFFD4AF37), size: 26),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shared Playlist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('Collaborative music queue for this chat', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFD4AF37), size: 28),
                  tooltip: 'Add Song',
                  onPressed: _showAddTrackDialog,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _playlistRef.orderBy('addedAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.queue_music_rounded, size: 54, color: Colors.grey.shade600),
                        const SizedBox(height: 10),
                        const Text('No songs added yet', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'Tap + above to add a favorite song',
                          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: scrollController,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final title = (data['title'] ?? '').toString();
                    final artist = (data['artist'] ?? '').toString();
                    final addedBy = (data['addedBy'] ?? '').toString();
                    final isMyTrack = data['addedByUid'] == widget.currentUid;

                    return ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6A1B9A).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.music_note_rounded, color: Color(0xFFD4AF37)),
                      ),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('$artist • Added by $addedBy', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      trailing: isMyTrack
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                              onPressed: () => doc.reference.delete(),
                            )
                          : null,
                    );
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
