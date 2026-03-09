import 'package:authentication_repository/authentication_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final AuthenticationRepository _authenticationRepository;
  LoginCubit(this._authenticationRepository) : super(LoginInitial());

  static final RegExp _e164Regex = RegExp(r'^\+[1-9]\d{7,14}$');
  static final RegExp _otpRegex = RegExp(r'^\d{6}$');

  Future<void> verifyPhoneNumber(String phoneNumber) async {
    final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);
    if (!_e164Regex.hasMatch(normalizedPhoneNumber)) {
      _emitIfOpen(
        const LoginFailure(
          errorMessage: 'Enter a valid phone number with country code.',
        ),
      );
      return;
    }

    _emitIfOpen(const LoginLoading(message: 'Sending verification code...'));
    try {
      await _savePhoneNumber(normalizedPhoneNumber);

      await _authenticationRepository.verifyPhoneNumber(
        phoneNumber: normalizedPhoneNumber,
        onCodeSent: (verificationId, resendToken) {
          _emitIfOpen(LoginCodeSent(verificationId, resendToken));
        },
        onVerificationFailed: (exception) {
          if (_authenticationRepository.currentUser.isNotEmpty) {
            _emitIfOpen(LoginSuccess());
            return;
          }
          _emitIfOpen(
            LoginFailure(
              errorMessage:
                  SignInWithCredentialFailure.fromException(exception).message,
            ),
          );
        },
        onVerificationCompleted: (user) {
          if (user.isNotEmpty) {
            _emitIfOpen(LoginSuccess());
          }
        },
        onCodeAutoRetrievalTimeout: (_) {
          if (_authenticationRepository.currentUser.isNotEmpty) {
            _emitIfOpen(LoginSuccess());
          }
        },
      );
    } on SignInWithCredentialFailure catch (e) {
      if (_authenticationRepository.currentUser.isNotEmpty) {
        _emitIfOpen(LoginSuccess());
        return;
      }
      _emitIfOpen(LoginFailure(errorMessage: e.message));
    } catch (_) {
      if (_authenticationRepository.currentUser.isNotEmpty) {
        _emitIfOpen(LoginSuccess());
        return;
      }
      _emitIfOpen(
        const LoginFailure(
          errorMessage:
              'Unable to send verification code. Please try again.',
        ),
      );
    }
  }

  Future<void> verifySmsCode(String smsCode, String verificationId) async {
    if (_authenticationRepository.currentUser.isNotEmpty) {
      _emitIfOpen(LoginSuccess());
      return;
    }

    final normalizedSmsCode = smsCode.trim();
    if (!_otpRegex.hasMatch(normalizedSmsCode)) {
      _emitIfOpen(
        const LoginFailure(
          errorMessage: 'SMS code must be exactly 6 digits.',
        ),
      );
      return;
    }
    final normalizedVerificationId = verificationId.trim();
    if (normalizedVerificationId.isEmpty) {
      _emitIfOpen(
        const LoginFailure(
          errorMessage: 'Verification session missing. Request a new code.',
        ),
      );
      return;
    }

    _emitIfOpen(const LoginLoading(message: 'Verifying code...'));
    try {
      final isVerified =
          await _authenticationRepository.loginWithSmsVerificationCode(
        smsVerificationCode: normalizedSmsCode,
        verificationCode: normalizedVerificationId,
      );
      if (isVerified) {
        _emitIfOpen(LoginSuccess());
      } else if (_authenticationRepository.currentUser.isNotEmpty) {
        _emitIfOpen(LoginSuccess());
      } else {
        _emitIfOpen(
          const LoginFailure(
            errorMessage: 'Unable to verify SMS code. Request a new code.',
          ),
        );
      }
    } on SignInWithCredentialFailure catch (e) {
      if (_authenticationRepository.currentUser.isNotEmpty) {
        _emitIfOpen(LoginSuccess());
        return;
      }
      _emitIfOpen(LoginFailure(errorMessage: e.message));
    } catch (_) {
      if (_authenticationRepository.currentUser.isNotEmpty) {
        _emitIfOpen(LoginSuccess());
        return;
      }
      _emitIfOpen(
        const LoginFailure(
          errorMessage: 'Unable to verify SMS code. Please try again.',
        ),
      );
    }
  }

  Future<void> _savePhoneNumber(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phoneNumber', phoneNumber);
  }

  Future<String?> getSavedPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('phoneNumber');
  }

  String _normalizePhoneNumber(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('-', '')
        .replaceAll('(', '')
        .replaceAll(')', '');
  }

  void _emitIfOpen(LoginState state) {
    if (!isClosed) {
      emit(state);
    }
  }
}
