import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  ConfirmationResult? _webConfirmationResult;
  String? _nativeVerificationId;
  int? _resendToken;

  // Stream of auth state changes
  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  // Get current user
  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  // Phone Authentication: Send OTP (Web & Native Support)
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(FirebaseAuthException e) onVerificationFailed,
    required Function(PhoneAuthCredential credential) onVerificationCompleted,
    Function(String verificationId)? onCodeAutoRetrievalTimeout,
  }) async {
    if (kIsWeb) {
      try {
        debugPrint("[AuthService Web] Calling _auth.signInWithPhoneNumber for $phoneNumber...");
        _webConfirmationResult = await _auth.signInWithPhoneNumber(phoneNumber);
        debugPrint("[AuthService Web] ConfirmationResult received successfully for $phoneNumber");
        onCodeSent('web_confirmation', null);
      } on FirebaseAuthException catch (e) {
        debugPrint("[AuthService Web] FirebaseAuthException: [${e.code}] ${e.message} (plugin: ${e.plugin})");
        onVerificationFailed(e);
      } catch (e, stack) {
        debugPrint("[AuthService Web] General exception during sendOtp: $e\n$stack");
        onVerificationFailed(
          FirebaseAuthException(
            code: 'web-error',
            message: e.toString(),
          ),
        );
      }
    } else {
      try {
        await _auth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          forceResendingToken: _resendToken,
          verificationCompleted: onVerificationCompleted,
          verificationFailed: onVerificationFailed,
          codeSent: (String verificationId, int? resendToken) {
            _nativeVerificationId = verificationId;
            _resendToken = resendToken;
            onCodeSent(verificationId, resendToken);
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _nativeVerificationId = verificationId;
            if (onCodeAutoRetrievalTimeout != null) {
              onCodeAutoRetrievalTimeout(verificationId);
            }
          },
          timeout: const Duration(seconds: 60),
        );
      } catch (e) {
        rethrow;
      }
    }
  }

  // Phone Authentication: Verify OTP (Web & Native Support)
  Future<UserCredential> verifyOtp({
    required String smsCode,
    String? verificationId,
  }) async {
    if (kIsWeb) {
      if (_webConfirmationResult == null) {
        throw FirebaseAuthException(
          code: 'no-session',
          message: 'No active confirmation session found for web. Please request OTP again.',
        );
      }
      return await _webConfirmationResult!.confirm(smsCode);
    } else {
      final String id = verificationId ?? _nativeVerificationId ?? '';
      if (id.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-verification-id',
          message: 'Verification ID not found. Please request OTP again.',
        );
      }
      final AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: id,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
    }
  }

  // Sign In with Credential (e.g. for auto-retrieval completed on native)
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    try {
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  // Google Sign-In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  // Phone + Password Authentication (Maps phone to Firebase Auth account)
  Future<UserCredential> signInWithPhonePassword({
    required String phoneNumber,
    required String password,
  }) async {
    final cleanDigits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final syntheticEmail = 'phone_$cleanDigits@velza.internal';

    try {
      // Attempt login
      return await _auth.signInWithEmailAndPassword(
        email: syntheticEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // If user does not exist, automatically create new user account
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        try {
          return await _auth.createUserWithEmailAndPassword(
            email: syntheticEmail,
            password: password,
          );
        } on FirebaseAuthException catch (regError) {
          if (regError.code == 'email-already-in-use') {
            // Password was wrong for existing user
            throw FirebaseAuthException(
              code: 'wrong-password',
              message: 'Incorrect password for this mobile number.',
            );
          }
          rethrow;
        }
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // Standard Firebase Email + Password Sign In
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } catch (e) {
      rethrow;
    }
  }

  // Standard Firebase Email + Password Sign Up / Registration
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } catch (e) {
      rethrow;
    }
  }

  // Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      _webConfirmationResult = null;
      _nativeVerificationId = null;
      _resendToken = null;
    } catch (e) {
      rethrow;
    }
  }
}
