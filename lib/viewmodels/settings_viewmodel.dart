import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velza/models/user_model.dart';
import 'package:velza/services/database_service.dart';

enum ChatFontSize {
  small(13.0, 'Small'),
  medium(15.0, 'Medium'),
  large(17.0, 'Large'),
  extraLarge(19.0, 'Extra Large');

  final double size;
  final String label;
  const ChatFontSize(this.size, this.label);
}

enum ChatFontStyle {
  defaultFont('Default', null),
  modernSans('Modern Sans', 'sans-serif'),
  luxuryOutfit('Luxury Outfit', 'Outfit'),
  classicSerif('Classic Serif', 'serif'),
  monospace('Monospace', 'monospace');

  final String label;
  final String? fontFamily;
  const ChatFontStyle(this.label, this.fontFamily);
}

class SettingsViewModel extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  ThemeMode _themeMode = ThemeMode.system;
  ChatFontSize _chatFontSize = ChatFontSize.medium;
  ChatFontStyle _chatFontStyle = ChatFontStyle.defaultFont;
  bool _readReceiptsEnabled = true;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ChatFontSize get chatFontSize => _chatFontSize;
  ChatFontStyle get chatFontStyle => _chatFontStyle;
  double get chatFontSizeValue => _chatFontSize.size;
  String? get chatFontFamily => _chatFontStyle.fontFamily;
  bool get readReceiptsEnabled => _readReceiptsEnabled;

  SettingsViewModel() {
    _loadSettingsFromPrefs();
  }

  // Load saved theme and chat appearance from shared preferences
  Future<void> _loadSettingsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode');
    if (isDark != null) {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    }

    final savedSize = prefs.getString('chat_font_size');
    if (savedSize != null) {
      _chatFontSize = ChatFontSize.values.firstWhere(
        (s) => s.name == savedSize,
        orElse: () => ChatFontSize.medium,
      );
    }

    final savedStyle = prefs.getString('chat_font_style');
    if (savedStyle != null) {
      _chatFontStyle = ChatFontStyle.values.firstWhere(
        (s) => s.name == savedStyle,
        orElse: () => ChatFontStyle.defaultFont,
      );
    }

    _readReceiptsEnabled = prefs.getBool('read_receipts_enabled') ?? true;

    notifyListeners();
  }

  // Toggle read receipts setting
  Future<void> toggleReadReceipts(bool enabled) async {
    _readReceiptsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('read_receipts_enabled', enabled);
    notifyListeners();
  }

  // Toggle between Light and Dark mode
  Future<void> toggleTheme(bool isOn) async {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isOn);
    notifyListeners();
  }

  // Update chat font size
  Future<void> updateChatFontSize(ChatFontSize newSize) async {
    _chatFontSize = newSize;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_font_size', newSize.name);
    notifyListeners();
  }

  // Update chat font style
  Future<void> updateChatFontStyle(ChatFontStyle newStyle) async {
    _chatFontStyle = newStyle;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_font_style', newStyle.name);
    notifyListeners();
  }

  // Stream current user's blocked users models
  Stream<List<UserModel>> streamBlockedUsers(List<String> blockedUids) {
    // For each blocked user, stream their user profile
    // In practice, we query the users collection matching blockedUids
    // For simplicity, we listen to all users and filter in-memory, or query directly
    // Let's write a simple stream mapper
    return DatabaseService().streamUserChats('').map((_) => []).cast<List<UserModel>>(); // Placeholder
  }

  // Future to update user display name and profile picture URL
  Future<UserModel> updateProfile({
    required UserModel currentUser,
    required String newName,
    required String newPhotoUrl,
  }) async {
    final updatedUser = currentUser.copyWith(
      displayName: newName,
      searchableName: newName.toLowerCase().trim(),
      photoUrl: newPhotoUrl,
    );
    await _dbService.saveUserProfile(updatedUser);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_user_profile', jsonEncode(updatedUser.toMap()));
    return updatedUser;
  }
}
