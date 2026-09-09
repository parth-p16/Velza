import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:velza/viewmodels/auth_viewmodel.dart';
import 'package:velza/viewmodels/settings_viewmodel.dart';
import 'package:velza/views/settings/profile_edit_screen.dart';
import 'package:velza/views/settings/app_lock_settings_screen.dart';
import 'package:velza/views/auth/login_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authVM = Provider.of<AuthViewModel>(context);
    final settingsVM = Provider.of<SettingsViewModel>(context);
    final isDark = theme.brightness == Brightness.dark;

    final user = authVM.currentUserModel;
    final String displayName = user?.displayName ?? 'Velza User';
    final String phoneNumber = user?.phoneNumber ?? (user?.email ?? 'No contact info');
    final String photoUrl = user?.photoUrl ?? '';

    return Scaffold(
      body: ListView(
        children: [
          // Profile header section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E162B) : Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFF6A1B9A),
                  backgroundImage: photoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(photoUrl)
                      : null,
                  child: photoUrl.isEmpty
                      ? const Icon(Icons.person, size: 36, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phoneNumber,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Color(0xFFD4AF37)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileEditScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Settings Options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  // Dark Mode toggle
                  SwitchListTile(
                    title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Toggle light and dark aesthetics'),
                    secondary: Icon(
                      settingsVM.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: const Color(0xFF6A1B9A),
                    ),
                    activeThumbColor: const Color(0xFFD4AF37),
                    value: settingsVM.isDarkMode,
                    onChanged: (val) => settingsVM.toggleTheme(val),
                  ),
                  const Divider(height: 1, indent: 56),

                  // Read Receipts toggle
                  SwitchListTile(
                    title: const Text('Read Receipts', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Send and receive blue ticks when messages are read'),
                    secondary: const Icon(
                      Icons.done_all_rounded,
                      color: Color(0xFF6A1B9A),
                    ),
                    activeThumbColor: const Color(0xFFD4AF37),
                    value: settingsVM.readReceiptsEnabled,
                    onChanged: (val) => settingsVM.toggleReadReceipts(val),
                  ),
                  const Divider(height: 1, indent: 56),

                  // Edit profile action
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded, color: Color(0xFF6A1B9A)),
                    title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Modify name and profile picture'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfileEditScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),

                  // Blocked users
                  ListTile(
                    leading: const Icon(Icons.block_flipped, color: Color(0xFF6A1B9A)),
                    title: const Text('Blocked Contacts', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Manage your blocked users list'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Blocked list managed under individual chats.')),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),

                  // App Lock (Privacy & Security)
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded, color: Color(0xFF6A1B9A)),
                    title: const Text('App Lock', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('PIN and biometric security lock'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AppLockSettingsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Chat Appearance Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.text_fields_rounded, color: Color(0xFFD4AF37), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chat & Text Appearance',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Adjust font size and style for chat bubbles',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Message Font Size',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ChatFontSize.values.map((size) {
                        final isSelected = settingsVM.chatFontSize == size;
                        return ChoiceChip(
                          label: Text(size.label),
                          selected: isSelected,
                          selectedColor: const Color(0xFF6A1B9A),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          onSelected: (selected) {
                            if (selected) settingsVM.updateChatFontSize(size);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Message Font Style',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E162B) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ChatFontStyle>(
                          value: settingsVM.chatFontStyle,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFD4AF37)),
                          dropdownColor: isDark ? const Color(0xFF1E162B) : Colors.white,
                          items: ChatFontStyle.values.map((style) {
                            return DropdownMenuItem<ChatFontStyle>(
                              value: style,
                              child: Text(
                                style.label,
                                style: TextStyle(
                                  fontFamily: style.fontFamily,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (newStyle) {
                            if (newStyle != null) {
                              settingsVM.updateChatFontStyle(newStyle);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Live Preview',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFFD4AF37)),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 280),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
                          ),
                          borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(4)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'The quick brown fox jumps over the lazy dog ✨',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: settingsVM.chatFontSizeValue,
                                fontFamily: settingsVM.chatFontFamily,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('12:00 PM', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                SizedBox(width: 4),
                                Icon(Icons.done_all_rounded, size: 14, color: Color(0xFFD4AF37)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Logout Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                subtitle: const Text('Sign out of your current session'),
                onTap: () async {
                  await authVM.signOut();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
