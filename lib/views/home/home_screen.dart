import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:velza/viewmodels/auth_viewmodel.dart';
import 'package:velza/viewmodels/settings_viewmodel.dart';
import 'package:velza/views/home/chat_list_tab.dart';
import 'package:velza/views/home/updates_tab.dart';
import 'package:velza/views/home/communities_tab.dart';
import 'package:velza/views/home/calls_tab.dart';
import 'package:velza/views/home/contact_list_screen.dart';
import 'package:velza/views/settings/settings_screen.dart';
import 'package:velza/services/presence_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    ChatListTab(),
    UpdatesTab(),
    CommunitiesTab(),
    CallsTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVM = Provider.of<AuthViewModel>(context, listen: false);
      if (authVM.currentUserModel != null) {
        PresenceService().initialize(authVM.currentUserModel!.uid);
      }
    });
  }

  String get _appBarTitle {
    switch (_currentIndex) {
      case 0:
        return 'Velza';
      case 1:
        return 'Updates';
      case 2:
        return 'Communities';
      case 3:
        return 'Calls';
      default:
        return 'Velza';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsVM = Provider.of<SettingsViewModel>(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF8E24AA), Color(0xFFD4AF37)],
                ),
              ),
              child: const Icon(Icons.insights, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text(
              _appBarTitle,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 0.8),
            ),
          ],
        ),
        actions: [
          // Search & Find Users
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search & Find Users',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactListScreen()),
              );
            },
          ),
          // Theme Toggler
          IconButton(
            icon: Icon(
              settingsVM.isDarkMode ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
              color: settingsVM.isDarkMode ? const Color(0xFFFFD700) : const Color(0xFF6A1B9A),
            ),
            onPressed: () => settingsVM.toggleTheme(!settingsVM.isDarkMode),
          ),
          // Overflow Menu
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              } else if (val == 'new_chat') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactListScreen()),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'new_chat',
                child: Row(
                  children: [
                    Icon(Icons.person_add_outlined, size: 20, color: Color(0xFFD4AF37)),
                    SizedBox(width: 10),
                    Text('New chat / Contacts'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 20, color: Color(0xFFD4AF37)),
                    SizedBox(width: 10),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: isDark ? const Color(0xFFBB86FC) : const Color(0xFF6A1B9A),
          unselectedItemColor: Colors.grey.shade500,
          backgroundColor: isDark ? const Color(0xFF150F22) : Colors.white,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          elevation: 10,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.update_rounded),
              activeIcon: Icon(Icons.update_rounded),
              label: 'Updates',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              activeIcon: Icon(Icons.groups_rounded),
              label: 'Communities',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.call_outlined),
              activeIcon: Icon(Icons.call_rounded),
              label: 'Calls',
            ),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              heroTag: 'new_chat_fab',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactListScreen()),
                );
              },
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add_comment_outlined),
            )
          : (_currentIndex == 1
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'text_status_fab',
                      onPressed: () => UpdatesTab.openAddStatusComposer(context),
                      backgroundColor: isDark ? const Color(0xFF2D223E) : Colors.grey.shade200,
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      child: const Icon(Icons.edit_rounded, size: 18),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton(
                      heroTag: 'camera_status_fab',
                      onPressed: () => UpdatesTab.openAddStatusComposer(context),
                      backgroundColor: const Color(0xFF6A1B9A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.camera_alt_rounded),
                    ),
                  ],
                )
              : null),
    );
  }
}
