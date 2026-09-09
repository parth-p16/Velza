import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:velza/models/chat_model.dart';
import 'package:velza/services/database_service.dart';
import 'package:velza/views/chat/chat_screen.dart';

// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] Handling background message: ${message.messageId} data: ${message.data}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final DatabaseService _dbService = DatabaseService();
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  void Function(String chatId)? onNotificationChatTap;

  String? _currentActiveChatId;
  final Set<String> _processedNotificationIds = {};

  void setActiveChat(String? chatId) {
    _currentActiveChatId = chatId;
  }

  // Initialize FCM, permissions, and handlers
  Future<void> initialize({
    required String currentUserId,
    void Function(String chatId)? onChatSelected,
  }) async {
    if (onChatSelected != null) {
      onNotificationChatTap = onChatSelected;
    }

    try {
      // 1. Request notification permissions
      final NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('[FCM] Notification authorization status: ${settings.authorizationStatus}');

      // 2. Configure foreground notification presentation
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Retrieve and sync FCM device token
      await syncToken(currentUserId);

      // 4. Token refresh listener
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed: $newToken');
        if (currentUserId.isNotEmpty) {
          _dbService.saveUserFcmToken(currentUserId, newToken);
        }
      });

      // 5. Handle notification tap when app opened from terminated state
      final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }

      // 6. Handle notification tap when app opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleMessageTap(message);
      });

      // 7. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });
    } catch (e) {
      debugPrint('[FCM ERROR] Could not initialize notifications: $e');
    }
  }

  // Sync device token to Firestore
  Future<void> syncToken(String userId) async {
    if (userId.isEmpty) return;
    try {
      final String? token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('[FCM] Retrieved FCM device token for $userId: $token');
        await _dbService.saveUserFcmToken(userId, token);
      }
    } catch (e) {
      debugPrint('[FCM ERROR] Failed to fetch device token: $e');
    }
  }

  // Handle user tapping on a notification
  void _handleMessageTap(RemoteMessage message) {
    final String? chatId = message.data['chatId'];
    debugPrint('[FCM Tap] Tapped message with chatId: $chatId');
    if (chatId != null && chatId.isNotEmpty) {
      if (onNotificationChatTap != null) {
        onNotificationChatTap!(chatId);
      } else {
        _navigateToChat(chatId);
      }
    }
  }

  // Safe navigation directly into target conversation
  Future<void> _navigateToChat(String chatId) async {
    try {
      final doc = await _db.collection('chats').doc(chatId).get();
      if (doc.exists && doc.data() != null && navigatorKey.currentState != null) {
        final chat = ChatModel.fromMap(doc.data()!);
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)),
        );
      }
    } catch (e) {
      debugPrint('[FCM Navigation Error] Could not open chat $chatId: $e');
    }
  }

  // Handle message arriving while app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    final String? id = message.messageId;
    if (id != null && _processedNotificationIds.contains(id)) {
      return; // Deduplicate
    }
    if (id != null) {
      _processedNotificationIds.add(id);
    }

    final String? chatId = message.data['chatId'];
    // If user is currently looking at this exact chat, suppress banner
    if (chatId != null && chatId == _currentActiveChatId) {
      return;
    }

    final notification = message.notification;
    if (notification != null && navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF6A1B9A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.chat_bubble_rounded, color: Color(0xFFD4AF37)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title ?? 'New Message',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      notification.body ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          action: chatId != null
              ? SnackBarAction(
                  label: 'VIEW',
                  textColor: const Color(0xFFD4AF37),
                  onPressed: () {
                    if (onNotificationChatTap != null) {
                      onNotificationChatTap!(chatId);
                    }
                  },
                )
              : null,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // Record a notification request in Firestore securely without exposing server keys
  Future<void> queueNotification({
    required String senderId,
    required String senderName,
    required String receiverId,
    required String chatId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      await _db.collection('notifications').add({
        'senderId': senderId,
        'senderName': senderName,
        'receiverId': receiverId,
        'chatId': chatId,
        'title': title,
        'body': body,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('[FCM] Error queueing notification: $e');
    }
  }
}
