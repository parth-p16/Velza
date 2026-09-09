import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velza/models/user_model.dart';
import 'package:velza/services/auth_service.dart';
import 'package:velza/services/database_service.dart';
import 'package:velza/services/storage_service.dart';
import 'package:velza/services/notification_service.dart';
import 'package:velza/services/presence_service.dart';
import 'package:velza/services/app_lock_service.dart';

enum AuthState { unauthenticated, authenticating, codeSent, authenticated, error }

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final StorageService _storageService = StorageService();

  AuthState _state = AuthState.unauthenticated;
  String? _pendingPhoneNumber;
  String? _pendingEmail;
  String? _verificationId;
  int? _resendToken;
  String? _errorMessage;
  UserModel? _currentUserModel;
  bool _isLoading = false;

  AuthState get state => _state;
  String? get pendingPhoneNumber => _pendingPhoneNumber;
  String? get pendingEmail => _pendingEmail;
  String? get verificationId => _verificationId;
  int? get resendToken => _resendToken;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUserModel => _currentUserModel;
  bool get isLoading => _isLoading;
  User? get firebaseUser => _authService.currentUser;
  StreamSubscription<User?>? _authSubscription;

  AuthViewModel() {
    _initSession();
  }

  void _initSession() {
    // 1. Immediately restore local session from SharedPreferences cache
    restoreSession();

    // 2. Listen to Firebase Auth state stream in real-time
    _authSubscription = _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        debugPrint("[AuthViewModel] Firebase session detected for user: ${user.uid} (${user.email ?? user.phoneNumber})");
        await _syncFirestoreProfile(user);
      } else {
        debugPrint("[AuthViewModel] Firebase user is null");
        final prefs = await SharedPreferences.getInstance();
        final savedPhone = prefs.getString('active_phone_number');
        final savedEmail = prefs.getString('active_user_email');
        if ((savedPhone == null || savedPhone.isEmpty) && (savedEmail == null || savedEmail.isEmpty)) {
          _currentUserModel = null;
          _state = AuthState.unauthenticated;
          notifyListeners();
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // Restore saved session from SharedPreferences & Firebase Auth
  Future<void> restoreSession() async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('active_phone_number');
      final savedEmail = prefs.getString('active_user_email');
      final savedUserJson = prefs.getString('active_user_profile');

      // Immediate local session load from cache (zero delay/flicker)
      if (savedUserJson != null && savedUserJson.isNotEmpty) {
        try {
          final Map<String, dynamic> map = jsonDecode(savedUserJson);
          _currentUserModel = UserModel.fromMap(map);
          _state = AuthState.authenticated;
          notifyListeners();
          PresenceService().initialize(_currentUserModel!.uid);
        } catch (_) {}
      }

      // Verify and sync with Firebase Auth / Firestore
      final currentAuthUser = firebaseUser;
      if (currentAuthUser != null) {
        await _syncFirestoreProfile(currentAuthUser);
      } else if (savedEmail != null && savedEmail.isNotEmpty) {
        final existingProfile = await _dbService.getUserByEmail(savedEmail);
        if (existingProfile != null) {
          _currentUserModel = existingProfile;
          _state = AuthState.authenticated;
          await prefs.setString('active_user_profile', jsonEncode(existingProfile.toMap()));
          notifyListeners();
        }
      } else if (savedPhone != null && savedPhone.isNotEmpty) {
        final existingProfile = await _dbService.getUserByPhoneNumber(savedPhone);
        if (existingProfile != null) {
          _currentUserModel = existingProfile;
          _state = AuthState.authenticated;
          await prefs.setString('active_user_profile', jsonEncode(existingProfile.toMap()));
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("[AuthViewModel] restoreSession error: $e");
    } finally {
      _setLoading(false);
    }
  }

  // Reload and refresh the user profile
  Future<void> loadUserProfile(String uid) async {
    final profile = await _dbService.getUserProfile(uid);
    if (profile != null) {
      _currentUserModel = profile;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_user_profile', jsonEncode(profile.toMap()));
      notifyListeners();
    }
  }

  // Internal helper to sync Firestore profile
  Future<void> _syncFirestoreProfile(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = user.phoneNumber ?? prefs.getString('active_phone_number') ?? '';
      final email = user.email ?? prefs.getString('active_user_email') ?? '';
      
      DocumentSnapshot<Map<String, dynamic>>? docSnapshot;
      try {
        docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint("[AuthViewModel] Firestore profile get timeout/network delay: $e");
      }

      if (docSnapshot != null && docSnapshot.exists && docSnapshot.data() != null) {
        final data = Map<String, dynamic>.from(docSnapshot.data()!);
        if (data['uid'] == null || (data['uid'] as String).isEmpty) {
          data['uid'] = user.uid;
        }
        final existingUser = UserModel.fromMap(data);
        final updatedUser = existingUser.copyWith(
          isOnline: true,
          lastSeen: DateTime.now(),
          searchableName: existingUser.displayName.toLowerCase().trim(),
        );
        _currentUserModel = updatedUser;
        _state = AuthState.authenticated;
        await prefs.setString('active_user_profile', jsonEncode(updatedUser.toMap()));
        if (phone.isNotEmpty) {
          await prefs.setString('active_phone_number', phone);
        }
        if (email.isNotEmpty) {
          await prefs.setString('active_user_email', email);
        }
        notifyListeners();
        // Update presence and searchableName in Firestore
        _dbService.saveUserProfile(updatedUser);
      } else {
        // Document does not exist in /users/{user.uid} yet or couldn't be fetched!
        // Automatically create and sync it to Firestore as source of truth.
        final displayName = (user.displayName != null && user.displayName!.isNotEmpty)
            ? user.displayName!
            : (email.isNotEmpty ? email.split('@').first : 'Velza User');

        final newProfile = UserModel(
          uid: user.uid,
          phoneNumber: phone,
          email: email,
          displayName: displayName,
          searchableName: displayName.toLowerCase().trim(),
          photoUrl: user.photoURL ?? '',
          isOnline: true,
          typingTo: 'none',
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
          blockedUsers: [],
        );

        _currentUserModel = newProfile;
        _state = AuthState.authenticated;
        await prefs.setString('active_user_profile', jsonEncode(newProfile.toMap()));
        if (phone.isNotEmpty) {
          await prefs.setString('active_phone_number', phone);
        }
        if (email.isNotEmpty) {
          await prefs.setString('active_user_email', email);
        }
        notifyListeners();

        debugPrint("[AuthViewModel] Creating/updating profile in /users/${user.uid} (Project: velza-5ab77)...");
        try {
          await _dbService.saveUserProfile(newProfile);
        } on FirebaseException catch (fe) {
          debugPrint("[AuthViewModel] Firestore error saving profile in _syncFirestoreProfile: [${fe.code}] ${fe.message}");
        } catch (e) {
          debugPrint("[AuthViewModel] Error saving profile in _syncFirestoreProfile: $e");
        }
      }
      NotificationService().initialize(currentUserId: user.uid);
      PresenceService().initialize(user.uid);
    } on FirebaseException catch (fe) {
      debugPrint("[AuthViewModel] Firestore error fetching profile: [${fe.code}] ${fe.message}");
      _errorMessage = "Firestore Error: [${fe.code}] ${fe.message}";
      notifyListeners();
    } catch (e) {
      debugPrint("[AuthViewModel] _syncFirestoreProfile error: $e");
    }
  }

  // Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Clear any existing error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Send SMS OTP to phone number (Web & Mobile supported)
  Future<bool> sendOtp(String phoneNumber) async {
    final cleanPhone = phoneNumber.trim();
    if (cleanPhone.isEmpty || cleanPhone.length < 6) {
      _errorMessage = "Please enter a valid phone number with country code.";
      _state = AuthState.error;
      notifyListeners();
      return false;
    }

    final formattedPhone = cleanPhone.startsWith('+') ? cleanPhone : '+$cleanPhone';

    _setLoading(true);
    _errorMessage = null;
    _pendingPhoneNumber = formattedPhone;

    final completer = Completer<bool>();

    try {
      await _authService.sendOtp(
        phoneNumber: formattedPhone,
        onCodeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _state = AuthState.codeSent;
          _setLoading(false);
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        onVerificationFailed: (FirebaseAuthException e) {
          debugPrint("[AuthViewModel] Phone verification failed: code=${e.code}, message=${e.message}");
          String detailedMessage = "";
          if (e.code == 'invalid-phone-number') {
            detailedMessage = "Invalid phone number format. Please ensure country code is included (e.g. +91XXXXXXXXXX).";
          } else if (e.code == 'too-many-requests') {
            detailedMessage = "SMS limit exceeded or too many requests. Please wait a moment and try again.";
          } else if (e.code == 'quota-exceeded') {
            detailedMessage = "Firebase SMS daily quota exceeded for this project. Check Firebase Console or use test phone numbers.";
          } else if (e.code == 'operation-not-allowed') {
            detailedMessage = "Phone Authentication is not enabled in Firebase Console (Authentication > Sign-in method > Phone).";
          } else if (e.code == 'app-not-authorized' || e.code == 'unauthorized-domain') {
            detailedMessage = "Domain not authorized in Firebase Console (Authentication > Settings > Authorized domains).";
          } else if (e.code == 'invalid-app-credential' || e.code == 'captcha-check-failed') {
            detailedMessage = "reCAPTCHA verification failed. Please check Authorized Domains (localhost) in Firebase Console.";
          } else if (e.code == 'billing-not-enabled' || e.code.contains('region') || (e.message != null && e.message!.toLowerCase().contains('region'))) {
            detailedMessage = "SMS blocked by Firebase SMS Region Policy for India (+91). Enable India in Firebase Console > Authentication > Settings > SMS Region Policy.";
          } else {
            detailedMessage = "[${e.code}] ${e.message ?? 'Authentication failed.'}";
          }
          _errorMessage = detailedMessage;
          _state = AuthState.error;
          _setLoading(false);
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
        onVerificationCompleted: (PhoneAuthCredential credential) async {
          // Instant auto-verification on Android devices
          try {
            final userCred = await _authService.signInWithCredential(credential);
            await _syncUserProfileAfterLogin(userCred);
            _state = AuthState.authenticated;
            _setLoading(false);
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          } catch (e) {
            _errorMessage = e.toString();
            _state = AuthState.error;
            _setLoading(false);
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          }
        },
        onCodeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );

      return await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          if (_state == AuthState.codeSent || _state == AuthState.authenticated) {
            return true;
          }
          _errorMessage = "Verification request timed out. Please check your internet connection and try again.";
          _state = AuthState.error;
          _setLoading(false);
          return false;
        },
      );
    } catch (e) {
      debugPrint("Error in sendOtp: $e");
      _errorMessage = "Failed to send OTP: ${e.toString()}";
      _state = AuthState.error;
      _setLoading(false);
      return false;
    }
  }

  // Verify SMS OTP
  Future<bool> verifyOtp(String smsCode) async {
    final code = smsCode.trim();
    if (code.isEmpty || code.length < 6) {
      _errorMessage = "Please enter the 6-digit OTP code.";
      _state = AuthState.error;
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      final userCred = await _authService.verifyOtp(
        smsCode: code,
        verificationId: _verificationId,
      );

      await _syncUserProfileAfterLogin(userCred);
      _state = AuthState.authenticated;
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint("verifyOtp FirebaseAuthException: ${e.code} - ${e.message}");
      if (e.code == 'invalid-verification-code') {
        _errorMessage = "Invalid OTP code. Please check and try again.";
      } else if (e.code == 'session-expired') {
        _errorMessage = "OTP has expired. Please request a new code.";
      } else {
        _errorMessage = e.message ?? "Verification failed (${e.code}).";
      }
      _state = AuthState.error;
      _setLoading(false);
      return false;
    } catch (e) {
      debugPrint("verifyOtp error: $e");
      _errorMessage = "Verification failed: ${e.toString()}";
      _state = AuthState.error;
      _setLoading(false);
      return false;
    }
  }

  // Phone + Password Authentication (Persistent Firebase Auth Session)
  Future<bool> signInWithPhonePassword({
    required String phoneNumber,
    required String password,
    String? displayName,
  }) async {
    final cleanPhone = phoneNumber.trim();
    if (cleanPhone.isEmpty || cleanPhone.length < 6) {
      _errorMessage = "Please enter a valid mobile number.";
      _state = AuthState.error;
      notifyListeners();
      return false;
    }

    if (password.trim().isEmpty || password.length < 6) {
      _errorMessage = "Password must be at least 6 characters.";
      _state = AuthState.error;
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    final formattedPhone = cleanPhone.startsWith('+') ? cleanPhone : '+$cleanPhone';
    _pendingPhoneNumber = formattedPhone;

    try {
      final userCred = await _authService.signInWithPhonePassword(
        phoneNumber: formattedPhone,
        password: password.trim(),
      );

      await _syncUserProfileAfterLogin(userCred, preferredName: displayName);
      _state = AuthState.authenticated;
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint("[AuthViewModel] signInWithPhonePassword error: ${e.code} - ${e.message}");
      if (e.code == 'wrong-password') {
        _errorMessage = "Incorrect password for this mobile number.";
      } else if (e.code == 'weak-password') {
        _errorMessage = "Password is too weak. Please use at least 6 characters.";
      } else {
        _errorMessage = e.message ?? "Authentication failed (${e.code}).";
      }
      _state = AuthState.error;
      _setLoading(false);
      return false;
    } catch (e) {
      debugPrint("[AuthViewModel] signInWithPhonePassword general error: $e");
      _errorMessage = "Authentication failed: ${e.toString()}";
      _state = AuthState.error;
      _setLoading(false);
      return false;
    }
  }

  // Standard Firebase Email + Password Authentication
  Future<bool> signInWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      _errorMessage = "Please enter a valid email address.";
      _state = AuthState.error;
      notifyListeners();
      return false;
    }

    if (password.trim().isEmpty || password.length < 6) {
      _errorMessage = "Password must be at least 6 characters.";
      _state = AuthState.error;
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _errorMessage = null;
    _pendingEmail = cleanEmail;

    try {
      final userCred = await _authService.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password.trim(),
      );

      await _syncUserProfileAfterLogin(userCred, preferredName: displayName, preferredEmail: cleanEmail);
      _state = AuthState.authenticated;
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint("[AuthViewModel] signInWithEmailPassword error: ${e.code} - ${e.message}");
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        _errorMessage = "No account found for $cleanEmail. Please click 'Sign Up' below to create one.";
      } else if (e.code == 'wrong-password') {
        _errorMessage = "Incorrect password. Please try again.";
      } else if (e.code == 'invalid-email') {
        _errorMessage = "The email address is badly formatted.";
      } else if (e.code == 'user-disabled') {
        _errorMessage = "This user account has been disabled.";
      } else if (e.code == 'too-many-requests') {
        _errorMessage = "Too many failed attempts. Please try again later.";
      } else {
        _errorMessage = e.message ?? "Authentication failed (${e.code}).";
      }
      _state = AuthState.error;
      _setLoading(false);
      return false;
    } catch (e) {
      debugPrint("[AuthViewModel] signInWithEmailPassword general error: $e");
      _errorMessage = "Authentication failed: ${e.toString()}";
      _state = AuthState.error;
      _setLoading(false);
      return false;
    }
  }

  // Register New User with Email + Password
  Future<bool> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
    File? profileImageFile,
  }) async {
    final cleanEmail = email.trim();
    final cleanName = displayName.trim();

    if (cleanName.isEmpty) {
      _errorMessage = "Please enter your display name.";
      _state = AuthState.error;
      notifyListeners();
      return false;
    }

    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      _errorMessage = "Please enter a valid email address.";
      _state = AuthState.error;
      notifyListeners();
      return false;
    }

    if (password.trim().isEmpty || password.length < 6) {
      _errorMessage = "Password must be at least 6 characters.";
      _state = AuthState.error;
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _errorMessage = null;
    _pendingEmail = cleanEmail;

    try {
      final userCred = await _authService.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password.trim(),
      );

      final user = userCred.user;
      if (user == null) {
        throw Exception("Failed to get authenticated user.");
      }

      final uid = user.uid;
      String photoUrl = '';
      if (profileImageFile != null) {
        try {
          photoUrl = await _storageService.uploadProfilePhoto(uid, profileImageFile);
        } catch (e) {
          debugPrint("[AuthViewModel] Photo upload error during registration: $e");
        }
      }

      final newProfile = UserModel(
        uid: uid,
        phoneNumber: user.phoneNumber ?? '',
        email: cleanEmail,
        displayName: cleanName,
        searchableName: cleanName.toLowerCase().trim(),
        photoUrl: photoUrl,
        isOnline: true,
        typingTo: 'none',
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
        blockedUsers: [],
      );

      _currentUserModel = newProfile;
      _state = AuthState.authenticated;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_user_email', cleanEmail);
      await prefs.setString('active_user_profile', jsonEncode(newProfile.toMap()));

      debugPrint("[AuthViewModel] Registering profile to Firestore /users/$uid (Project: velza-5ab77)...");
      try {
        await _dbService.saveUserProfile(newProfile);
      } on FirebaseException catch (fe) {
        debugPrint("[AuthViewModel] Firestore error in registration: [${fe.code}] ${fe.message}");
        // Non-blocking for auth session, but log diagnostic info
      } catch (e) {
        debugPrint("[AuthViewModel] Non-fatal error saving new profile: $e");
      }

      notifyListeners();
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint("[AuthViewModel] registerWithEmailPassword error: ${e.code} - ${e.message}");
      if (e.code == 'email-already-in-use') {
        _errorMessage = "This email is already in use. Please sign in instead.";
      } else if (e.code == 'invalid-email') {
        _errorMessage = "The email address is invalid.";
      } else if (e.code == 'weak-password') {
        _errorMessage = "The password provided is too weak.";
      } else {
        _errorMessage = e.message ?? "Registration failed (${e.code}).";
      }
      _state = AuthState.error;
      _setLoading(false);
      return false;
    } catch (e) {
      debugPrint("[AuthViewModel] registerWithEmailPassword general error: $e");
      _errorMessage = "Registration failed: ${e.toString()}";
      _state = AuthState.error;
      _setLoading(false);
      return false;
    }
  }

  // Send Password Reset Email
  Future<bool> sendPasswordReset(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      _errorMessage = "Please enter a valid email address.";
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.sendPasswordResetEmail(cleanEmail);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint("[AuthViewModel] sendPasswordReset error: ${e.code} - ${e.message}");
      _errorMessage = e.message ?? "Could not send password reset email (${e.code}).";
      _state = AuthState.error;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _state = AuthState.error;
      _setLoading(false);
      return false;
    }
  }

  // Resend SMS OTP
  Future<bool> resendOtp() async {
    if (_pendingPhoneNumber == null || _pendingPhoneNumber!.isEmpty) {
      _errorMessage = "No phone number available to resend OTP.";
      notifyListeners();
      return false;
    }
    return await sendOtp(_pendingPhoneNumber!);
  }

  // Internal helper to synchronize Firestore profile after successful authentication
  Future<void> _syncUserProfileAfterLogin(UserCredential userCred, {String? preferredName, String? preferredEmail}) async {
    final user = userCred.user;
    if (user == null) return;

    final phone = _pendingPhoneNumber ?? user.phoneNumber ?? '';
    final email = preferredEmail ?? _pendingEmail ?? user.email ?? '';
    final uid = user.uid;

    final String derivedName = (preferredName != null && preferredName.trim().isNotEmpty)
        ? preferredName.trim()
        : (user.displayName != null && user.displayName!.trim().isNotEmpty)
            ? user.displayName!.trim()
            : (email.isNotEmpty
                ? email.split('@').first
                : (phone.length > 4 ? 'User ${phone.substring(phone.length - 4)}' : 'Velza User'));

    debugPrint("[Velza Auth] Current Firebase UID: $uid");
    debugPrint("[Velza Auth] Checking if document users/$uid exists in Firestore...");

    UserModel? existingProfile;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 12));

      if (snapshot.exists && snapshot.data() != null) {
        final data = Map<String, dynamic>.from(snapshot.data()!);
        if (data['uid'] == null || (data['uid'] as String).isEmpty) {
          data['uid'] = uid;
        }
        existingProfile = UserModel.fromMap(data);
      }
    } catch (e) {
      debugPrint("[Velza Auth] Note: Firestore lookup for users/$uid: $e");
    }

    final UserModel finalProfile;
    if (existingProfile != null) {
      debugPrint("[Velza Auth] Existing profile found in Firestore for UID $uid: '${existingProfile.displayName}'. Updating presence & searchableName...");
      finalProfile = existingProfile.copyWith(
        displayName: existingProfile.displayName.isNotEmpty ? existingProfile.displayName : derivedName,
        searchableName: (existingProfile.displayName.isNotEmpty ? existingProfile.displayName : derivedName).toLowerCase().trim(),
        email: email.isNotEmpty ? email : existingProfile.email,
        phoneNumber: phone.isNotEmpty ? phone : existingProfile.phoneNumber,
        isOnline: true,
        lastSeen: DateTime.now(),
      );
    } else {
      debugPrint("[Velza Auth] Profile document users/$uid was missing in Firestore! Automatically creating it (repairing account)...");
      finalProfile = UserModel(
        uid: uid,
        phoneNumber: phone,
        email: email,
        displayName: derivedName,
        searchableName: derivedName.toLowerCase().trim(),
        photoUrl: user.photoURL ?? '',
        isOnline: true,
        typingTo: 'none',
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
        blockedUsers: [],
      );
    }

    _currentUserModel = finalProfile;
    _state = AuthState.authenticated;

    debugPrint("[Velza Auth] Profile synchronized: UID: $uid | Name: '${finalProfile.displayName}' | Email: '${finalProfile.email}' | Searchable: '${finalProfile.searchableName}'");

    // Save session locally immediately
    try {
      final prefs = await SharedPreferences.getInstance();
      if (email.isNotEmpty) await prefs.setString('active_user_email', email);
      if (phone.isNotEmpty) await prefs.setString('active_phone_number', phone);
      await prefs.setString('active_user_profile', jsonEncode(finalProfile.toMap()));
    } catch (e) {
      debugPrint("[Velza Auth] Error saving session to prefs: $e");
    }

    // Always create or update user profile document in Firestore
    try {
      debugPrint("[Velza Auth] Writing/syncing profile document to Firestore users/$uid...");
      await _dbService.saveUserProfile(finalProfile);
      debugPrint("[Velza Auth] Document users/$uid confirmed created/updated in Firestore.");
    } on FirebaseException catch (fe) {
      debugPrint("[Velza Auth] Firestore write users/$uid note: [${fe.code}] ${fe.message}");
    } catch (e) {
      debugPrint("[Velza Auth] Firestore write users/$uid note: $e");
    }
  }

  void updateCurrentUserModel(UserModel updatedModel) {
    _currentUserModel = updatedModel;
    notifyListeners();
  }

  // Sign In with Google
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final userCred = await _authService.signInWithGoogle();
      if (userCred != null) {
        await _syncUserProfileAfterLogin(userCred);
        _state = AuthState.authenticated;
      } else {
        _state = AuthState.unauthenticated;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _state = AuthState.error;
    }
    _setLoading(false);
  }

  // Register or create user profile
  Future<bool> registerUserProfile({
    required String displayName,
    required File? profileImageFile,
  }) async {
    _setLoading(true);
    try {
      final phone = _pendingPhoneNumber ?? firebaseUser?.phoneNumber ?? '';
      final email = _pendingEmail ?? firebaseUser?.email ?? '';
      final uid = firebaseUser?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}';

      String photoUrl = '';
      if (profileImageFile != null) {
        photoUrl = await _storageService.uploadProfilePhoto(uid, profileImageFile);
      }

      final newProfile = UserModel(
        uid: uid,
        phoneNumber: phone,
        email: email,
        displayName: displayName,
        searchableName: displayName.toLowerCase().trim(),
        photoUrl: photoUrl,
        isOnline: true,
        typingTo: 'none',
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
        blockedUsers: [],
      );

      await _dbService.saveUserProfile(newProfile);
      
      final prefs = await SharedPreferences.getInstance();
      if (email.isNotEmpty) {
        await prefs.setString('active_user_email', email);
      }
      if (phone.isNotEmpty) {
        await prefs.setString('active_phone_number', phone);
      }
      await prefs.setString('active_user_profile', jsonEncode(newProfile.toMap()));

      _currentUserModel = newProfile;
      _state = AuthState.authenticated;
      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    _setLoading(true);
    AppLockService().onUserSignOut();
    PresenceService().dispose();
    if (_currentUserModel != null) {
      await _dbService.updateUserPresence(_currentUserModel!.uid, false);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_user_email');
    await prefs.remove('active_phone_number');
    await prefs.remove('active_user_profile');
    await _authService.signOut();
    _state = AuthState.unauthenticated;
    _currentUserModel = null;
    _pendingEmail = null;
    _pendingPhoneNumber = null;
    _verificationId = null;
    _resendToken = null;
    _setLoading(false);
  }
}

