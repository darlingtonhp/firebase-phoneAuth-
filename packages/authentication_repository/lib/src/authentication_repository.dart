import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';

import 'models/models.dart';

class SignInWithCredentialFailure implements Exception {
  static const String defaultMessage =
      'Unable to complete authentication. Please try again.';

  final String message;

  const SignInWithCredentialFailure([
    this.message = defaultMessage,
  ]);

  factory SignInWithCredentialFailure.fromCode(String code) {
    final normalizedCode = _normalizeCode(code);

    switch (normalizedCode) {
      case 'invalid-credential':
        return const SignInWithCredentialFailure(
          'The authentication credential is invalid. Request a new code.',
        );
      case 'sms-code-expired':
      case 'session-expired':
      case 'code-expired':
        return const SignInWithCredentialFailure(
          'The SMS code has expired. Request a new one.',
        );
      case 'invalid-verification-code':
        return const SignInWithCredentialFailure(
          'The SMS verification code is invalid.',
        );
      case 'missing-verification-code':
        return const SignInWithCredentialFailure(
          'Enter the 6-digit SMS verification code.',
        );
      case 'invalid-verification-id':
        return const SignInWithCredentialFailure(
          'The verification session is invalid. Request a new code.',
        );
      case 'missing-verification-id':
        return const SignInWithCredentialFailure(
          'The verification session is missing. Request a new code.',
        );
      case 'invalid-phone-number':
        return const SignInWithCredentialFailure(
          'The phone number format is invalid.',
        );
      case 'missing-phone-number':
        return const SignInWithCredentialFailure(
          'Please enter a phone number.',
        );
      case 'operation-not-allowed':
        return const SignInWithCredentialFailure(
          'Phone authentication is not enabled in Firebase.',
        );
      case 'app-not-authorized':
      case 'invalid-app-credential':
        return const SignInWithCredentialFailure(
          'This app is not authorized for phone authentication.',
        );
      case 'quota-exceeded':
        return const SignInWithCredentialFailure(
          'SMS quota exceeded. Please try again later.',
        );
      case 'too-many-requests':
        return const SignInWithCredentialFailure(
          'Too many requests. Please wait and try again.',
        );
      case 'captcha-check-failed':
        return const SignInWithCredentialFailure(
          'Security verification failed. Please try again.',
        );
      case 'network-request-failed':
        return const SignInWithCredentialFailure(
          'Network error. Check your connection and retry.',
        );
      case 'missing-client-identifier':
        return const SignInWithCredentialFailure(
          'This app build is missing phone auth configuration.',
        );
      default:
        return const SignInWithCredentialFailure();
    }
  }

  factory SignInWithCredentialFailure.fromException(
    firebase_auth.FirebaseAuthException exception,
  ) {
    final normalizedCode = _normalizeCode(exception.code);
    final exceptionMessage = exception.message?.trim();

    if (normalizedCode == 'internal-error' || normalizedCode == 'unknown') {
      if (exceptionMessage != null && exceptionMessage.isNotEmpty) {
        return SignInWithCredentialFailure(
          'Authentication failed ($normalizedCode): $exceptionMessage',
        );
      }
      return const SignInWithCredentialFailure(
        'Authentication service is currently unavailable. Please try again shortly.',
      );
    }

    final mapped = SignInWithCredentialFailure.fromCode(exception.code);
    if (mapped.message != defaultMessage) {
      return mapped;
    }

    if (exceptionMessage != null && exceptionMessage.isNotEmpty) {
      return SignInWithCredentialFailure(
        'Authentication failed ($normalizedCode): $exceptionMessage',
      );
    }

    if (normalizedCode.isNotEmpty) {
      return SignInWithCredentialFailure(
        'Authentication failed with code: $normalizedCode',
      );
    }

    return mapped;
  }

  static String _normalizeCode(String code) {
    var normalized = code.trim().toLowerCase();
    if (normalized.startsWith('auth/')) {
      normalized = normalized.substring(5);
    }
    if (normalized.startsWith('error_')) {
      normalized = normalized.substring(6);
    }
    if (normalized.startsWith('error-')) {
      normalized = normalized.substring(6);
    }
    normalized = normalized.replaceAll('_', '-');
    return normalized;
  }
}

class InvalidVerificationCodeException extends SignInWithCredentialFailure {
  final String verificationId;

  InvalidVerificationCodeException(this.verificationId);

  @override
  String get message =>
      'Invalid verification code for verification ID: $verificationId';
}

class UserNotLoggedInException extends LogOutFailure {
  String get message => 'User is not logged in. Cannot log out.';
}

class LogOutFailure implements Exception {}

class AuthenticationRepository {
  final firebase_auth.FirebaseAuth _firebaseAuth;
  final String userCacheKey = 'user';
  SharedPreferences? _prefs;
  User? _cachedUser;

  AuthenticationRepository({
    firebase_auth.FirebaseAuth? firebaseAuth,
    SharedPreferences? sharedPreferences,
  })  : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
        _prefs = sharedPreferences {
    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
      _cachedUser = _readCachedUser(prefs);
    });
  }

  Stream<User> get user {
    return _firebaseAuth.authStateChanges().map((firebaseUser) {
      final user = firebaseUser == null ? User.empty : firebaseUser.toUser;
      _cachedUser = user;
      _prefs?.setString(userCacheKey, jsonEncode(user.toJson()));
      return user;
    });
  }

  User get currentUser {
    final cachedUser = _cachedUser;
    if (cachedUser != null) {
      return cachedUser;
    }

    final cachedFromPrefs = _prefs != null ? _readCachedUser(_prefs!) : null;
    if (cachedFromPrefs != null) {
      _cachedUser = cachedFromPrefs;
      return cachedFromPrefs;
    }
    return User.empty;
  }

  Future<void> logOut() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw UserNotLoggedInException();
    }
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      if (e is firebase_auth.FirebaseAuthException) {
        if (e.code == 'ERROR_USER_NOT_FOUND' || e.code == 'user-not-found') {
          throw UserNotLoggedInException();
        } else {
          throw SignInWithCredentialFailure.fromException(e);
        }
      } else {
        rethrow; // Rethrow any other unknown exceptions
      }
    }
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(firebase_auth.FirebaseAuthException e)
        onVerificationFailed,
    Function(User user)? onVerificationCompleted,
    Function(String verificationId)? onCodeAutoRetrievalTimeout,
  }) async {
    if (phoneNumber.trim().isEmpty) {
      throw const SignInWithCredentialFailure('Please enter a phone number.');
    }

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted:
            (firebase_auth.PhoneAuthCredential credential) async {
          try {
            final result = await _firebaseAuth.signInWithCredential(credential);
            onVerificationCompleted?.call(result.user?.toUser ?? User.empty);
          } on firebase_auth.FirebaseAuthException catch (e) {
            onVerificationFailed(e);
          }
        },
        verificationFailed: onVerificationFailed,
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout:
            onCodeAutoRetrievalTimeout ?? (String verificationId) {},
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw SignInWithCredentialFailure.fromException(e);
    } catch (_) {
      throw const SignInWithCredentialFailure(
        'Unable to start phone verification. Please try again.',
      );
    }
  }

  Future<bool> loginWithSmsVerificationCode(
      {required String smsVerificationCode,
      required String verificationCode}) async {
    try {
      // final firebase_auth.PhoneAuthCredential credential =
      //     firebase_auth.PhoneAuthProvider.credential(
      //         verificationId: verificationCode, smsCode: smsVerificationcode);
      // await _firebaseAuth.signInWithCredential(credential).then((value) {
      //   final user = firebase_auth.FirebaseAuth.instance.currentUser;
      //   if (user != null) {
      //     return user;
      //   } else {
      //     return null;
      //   }
      // });
      final credentials = await _firebaseAuth.signInWithCredential(
          firebase_auth.PhoneAuthProvider.credential(
              verificationId: verificationCode, smsCode: smsVerificationCode));
      return credentials.user != null ? true : false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw SignInWithCredentialFailure.fromException(e);
    } catch (_) {
      throw const SignInWithCredentialFailure();
    }
  }

  User? _readCachedUser(SharedPreferences prefs) {
    final cachedJson = prefs.getString(userCacheKey);
    if (cachedJson == null || cachedJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(cachedJson);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return User.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}

extension on firebase_auth.User {
  User get toUser {
    return User(
      userId: uid,
      phoneNumber: phoneNumber,
      userName: displayName ?? '',
    );
  }
}
