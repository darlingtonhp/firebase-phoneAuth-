import 'dart:async';
import 'dart:convert';
import 'package:authentication_repository/authentication_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';

class SignInWithCredentialFailure implements Exception {
  final String message;

  const SignInWithCredentialFailure(
      [this.message = 'An unknown exception occurred']);

  factory SignInWithCredentialFailure.fromCode(String code) {
    switch (code) {
      case 'invalid-credential':
        return const SignInWithCredentialFailure('Invalid Credential');
      case 'sms-code-expired':
        return const SignInWithCredentialFailure(
            'The sms code you provided has expired');
      case 'invalid-verification-code':
        return const SignInWithCredentialFailure('Invalid verification code');
      case 'invalid-verification-id':
        return const SignInWithCredentialFailure('Invalid verification Id');
      default:
        return const SignInWithCredentialFailure();
    }
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

  AuthenticationRepository()
      : _firebaseAuth = firebase_auth.FirebaseAuth.instance {
    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
    });
  }

  Stream<User> get user {
    return _firebaseAuth.authStateChanges().map((firebaseUser) {
      final user = firebaseUser == null ? User.empty : firebaseUser.toUser;
      _prefs?.setString(userCacheKey, jsonEncode(user.toJson()));
      return user;
    });
  }

  User get currentUser {
    if (_prefs != null) {
      String? userJson = _prefs!.getString(userCacheKey);
      if (userJson != null) {
        return User.fromJson(jsonEncode(userJson) as Map<String, dynamic>);
      } else {
        return User.empty;
      }
    } else {
      return User.empty;
    }
  }

  Future<void> logOut() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw UserNotLoggedInException();
    }
    try {
      await Future.wait([firebase_auth.FirebaseAuth.instance.signOut()]);
    } catch (e) {
      if (e is firebase_auth.FirebaseAuthException) {
        if (e.code == 'ERROR_USER_NOT_FOUND') {
          throw UserNotLoggedInException();
        } else {
          throw SignInWithCredentialFailure.fromCode(e.code);
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
  }) async {
    await firebase_auth.FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted:
          (firebase_auth.PhoneAuthCredential credential) async {},
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> loginWithSmsVerificationCode(
      {required String smsVerificationcode,
      required String verificationCode}) async {
    try {
      final firebase_auth.PhoneAuthCredential credential =
          firebase_auth.PhoneAuthProvider.credential(
              verificationId: verificationCode, smsCode: smsVerificationcode);
      await _firebaseAuth.signInWithCredential(credential).then((value) {
        final user = firebase_auth.FirebaseAuth.instance.currentUser;
        if (user != null) {
          return user;
        } else {
          return null;
        }
      });
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw SignInWithCredentialFailure.fromCode(e.code);
    } catch (_) {
      throw const SignInWithCredentialFailure();
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
