import 'dart:async';
import 'package:flutter/material.dart';
import 'package:velza/services/database_service.dart';

/// Application-level presence service managing real-time online/offline state
class PresenceService with WidgetsBindingObserver {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  final DatabaseService _dbService = DatabaseService();
  String? _currentUid;
  Timer? _heartbeatTimer;
  Timer? _offlineDebounceTimer;
  bool _isOnline = false;

  void initialize(String uid) {
    if (uid.isEmpty) return;
    final wasSameUid = _currentUid == uid;
    _currentUid = uid;

    if (!wasSameUid) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
      WidgetsBinding.instance.addObserver(this);
    }

    setOnline();
    _startHeartbeat();
  }

  void setOnline() {
    _offlineDebounceTimer?.cancel();
    _offlineDebounceTimer = null;
    if (_currentUid != null && _currentUid!.isNotEmpty) {
      _isOnline = true;
      _dbService.updateUserPresence(_currentUid!, true);
    }
  }

  void setOffline({bool immediate = false}) {
    if (immediate) {
      _offlineDebounceTimer?.cancel();
      _offlineDebounceTimer = null;
      if (_currentUid != null && _currentUid!.isNotEmpty) {
        _isOnline = false;
        _dbService.updateUserPresence(_currentUid!, false);
      }
    } else {
      _offlineDebounceTimer?.cancel();
      _offlineDebounceTimer = Timer(const Duration(seconds: 5), () {
        if (_currentUid != null && _currentUid!.isNotEmpty) {
          _isOnline = false;
          _dbService.updateUserPresence(_currentUid!, false);
        }
      });
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Periodically update lastSeen while user actively uses the app
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_isOnline && _currentUid != null && _currentUid!.isNotEmpty) {
        _dbService.updateUserPresence(_currentUid!, true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        setOnline();
        break;
      case AppLifecycleState.inactive:
        // Temporary lifecycle pause (e.g. notification shade, route transition)
        setOffline(immediate: false);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App backgrounded or closed
        setOffline(immediate: true);
        break;
      default:
        break;
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _offlineDebounceTimer?.cancel();
    if (_currentUid != null && _currentUid!.isNotEmpty) {
      _dbService.updateUserPresence(_currentUid!, false);
    }
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _currentUid = null;
    _isOnline = false;
  }
}
