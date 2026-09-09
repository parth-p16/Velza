import 'package:flutter/material.dart';

class CallsTab extends StatelessWidget {
  const CallsTab({super.key});

  void _showCallPlaceholder(BuildContext context, String callType) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              callType == 'Video' ? Icons.videocam_rounded : Icons.phone_rounded,
              color: const Color(0xFF6A1B9A),
            ),
            const SizedBox(width: 8),
            Text('$callType Call'),
          ],
        ),
        content: Text(
          '$callType calling infrastructure is prepared and will connect in an upcoming release.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Color(0xFFD4AF37))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      children: [
        // Create Call Link
        ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.link_rounded, color: Color(0xFF6A1B9A)),
          ),
          title: const Text(
            'Create call link',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text('Share a link for your Velza audio or video call'),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Call link copied to clipboard'),
                backgroundColor: Color(0xFF6A1B9A),
              ),
            );
          },
        ),

        const Divider(height: 24, thickness: 0.5),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Recent',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),

        // Clean sample call history demonstration
        ListTile(
          leading: const CircleAvatar(
            radius: 24,
            backgroundColor: Color(0xFF6A1B9A),
            child: Icon(Icons.person, color: Colors.white),
          ),
          title: const Text('Velza Concierge', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Row(
            children: [
              Icon(Icons.call_received_rounded, size: 16, color: Colors.green),
              SizedBox(width: 4),
              Text('Yesterday, 6:45 PM'),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.phone_outlined, color: Color(0xFF6A1B9A)),
            onPressed: () => _showCallPlaceholder(context, 'Audio'),
          ),
        ),

        ListTile(
          leading: const CircleAvatar(
            radius: 24,
            backgroundColor: Color(0xFF0E0B16),
            child: Icon(Icons.person, color: Colors.white),
          ),
          title: const Text('Velza Support', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Row(
            children: [
              Icon(Icons.call_missed_rounded, size: 16, color: Colors.red),
              SizedBox(width: 4),
              Text('September 2, 2:15 PM'),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Color(0xFF6A1B9A)),
            onPressed: () => _showCallPlaceholder(context, 'Video'),
          ),
        ),
      ],
    );
  }
}
