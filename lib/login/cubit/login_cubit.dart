import 'package:authentication_repository/authentication_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final AuthenticationRepository _authenticationRepository;
  SharedPreferences? _prefs;
  LoginCubit(this._authenticationRepository) : super(LoginInitial()) {
    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
    });
  }
  // Event handlers
  Future<void> verifyPhoneNumber(String phoneNumber) async {
    try {
      // Save phone number
      await _savePhoneNumber(phoneNumber);

      await _authenticationRepository.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          emit(LoginSmsCodeSent(verificationId));
        },
        onVerificationFailed: (exception) {
          emit(LoginFailure(errorMessage: exception.toString()));
        },
      );
    } catch (e) {
      emit(LoginFailure(errorMessage: e.toString()));
    }
  }

  Future<void> verifySmsCode(String smsCode, String verificationId) async {
    try {
      await _authenticationRepository.loginWithSmsVerificationCode(
        smsVerificationcode: smsCode,
        verificationCode: verificationId,
      );
      emit(LoginSuccess());
    } on SignInWithCredentialFailure catch (e) {
      emit(LoginFailure(errorMessage: e.message));
    } catch (_) {
      emit(const LoginFailure());
    }
  }

  // Save phone number
  Future<void> _savePhoneNumber(String phoneNumber) async {
    await _prefs?.setString('phoneNumber', phoneNumber);
  }

  // load saved phone number
  Future<String?> getSavedPhoneNumber() async {
    return _prefs?.getString('phoneNumber');
  }
}
