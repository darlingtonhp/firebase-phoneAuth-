import 'package:authentication_repository/authentication_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_authentication_project/login/cubit/login_cubit.dart';

class _FakeAuthenticationRepository extends AuthenticationRepository {
  _FakeAuthenticationRepository({
    this.verifyCodeResult = true,
    this.signInResult = true,
    this.signInException,
    this.verifyError,
  }) : super();

  final bool verifyCodeResult;
  final bool signInResult;
  final SignInWithCredentialFailure? signInException;
  final firebase_auth.FirebaseAuthException? verifyError;

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(firebase_auth.FirebaseAuthException e) onVerificationFailed,
    Function(User user)? onVerificationCompleted,
    Function(String verificationId)? onCodeAutoRetrievalTimeout,
  }) async {
    if (!verifyCodeResult) {
      final error = verifyError ??
          firebase_auth.FirebaseAuthException(
            code: 'invalid-phone-number',
            message: 'The provided phone number is invalid.',
          );
      onVerificationFailed(error);
      return;
    }

    onCodeSent('verification-id', 1234);
  }

  @override
  Future<bool> loginWithSmsVerificationCode({
    required String smsVerificationCode,
    required String verificationCode,
  }) async {
    if (signInException != null) {
      throw signInException!;
    }
    return signInResult;
  }
}

void main() {
  group('LoginCubit', () {
    test('emits loading and code sent when phone verification is successful', () async {
      final repository = _FakeAuthenticationRepository();
      final cubit = LoginCubit(repository);
      final emitted = <LoginState>[];
      final subscription = cubit.stream.listen(emitted.add);

      await cubit.verifyPhoneNumber('+1234567890');

      expect(
        emitted,
        containsAllInOrder([
          isA<LoginLoading>(),
          isA<LoginCodeSent>(),
        ]),
      );

      await subscription.cancel();
      await cubit.close();
    });

    test('emits loading and failure when verification callback returns an auth exception',
        () async {
      final repository = _FakeAuthenticationRepository(
        verifyCodeResult: false,
        verifyError: firebase_auth.FirebaseAuthException(
          code: 'invalid-phone-number',
          message: 'The provided phone number is invalid.',
        ),
      );
      final cubit = LoginCubit(repository);
      final emitted = <LoginState>[];
      final subscription = cubit.stream.listen(emitted.add);

      await cubit.verifyPhoneNumber('+1234567890');

      expect(emitted.first, isA<LoginLoading>());
      expect(
        emitted[1],
        isA<LoginFailure>(),
      );

      await subscription.cancel();
      await cubit.close();
    });

    test('emits loading and success when SMS code verification succeeds', () async {
      final repository = _FakeAuthenticationRepository(signInResult: true);
      final cubit = LoginCubit(repository);
      final emitted = <LoginState>[];
      final subscription = cubit.stream.listen(emitted.add);

      await cubit.verifySmsCode('123456', 'verification-id');

      expect(
        emitted,
        containsAllInOrder([
          isA<LoginLoading>(),
          isA<LoginSuccess>(),
        ]),
      );

      await subscription.cancel();
      await cubit.close();
    });

    test('emits loading and failure when SMS code verification returns false', () async {
      final repository = _FakeAuthenticationRepository(signInResult: false);
      final cubit = LoginCubit(repository);
      final emitted = <LoginState>[];
      final subscription = cubit.stream.listen(emitted.add);

      await cubit.verifySmsCode('123456', 'verification-id');

      expect(emitted, containsAllInOrder([
        isA<LoginLoading>(),
        isA<LoginFailure>(),
      ]));

      await subscription.cancel();
      await cubit.close();
    });

    test('emits loading and failure when SMS code verification throws', () async {
      final repository = _FakeAuthenticationRepository(
        signInException: const SignInWithCredentialFailure('Invalid verification code'),
      );
      final cubit = LoginCubit(repository);
      final emitted = <LoginState>[];
      final subscription = cubit.stream.listen(emitted.add);

      await cubit.verifySmsCode('123456', 'verification-id');

      expect(emitted, containsAllInOrder([
        isA<LoginLoading>(),
        isA<LoginFailure>(),
      ]));

      await subscription.cancel();
      await cubit.close();
    });

    test('emits validation failure when OTP is not six digits', () async {
      final repository = _FakeAuthenticationRepository();
      final cubit = LoginCubit(repository);
      final emitted = <LoginState>[];
      final subscription = cubit.stream.listen(emitted.add);

      await cubit.verifySmsCode('123', 'verification-id');

      expect(emitted.single, isA<LoginFailure>());
      await subscription.cancel();
      await cubit.close();
    });
  });
}
