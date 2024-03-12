part of 'login_cubit.dart';

sealed class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object> get props => [];
}

final class LoginInitial extends LoginState {}

class LoginSmsCodeSent extends LoginState {
  final String verificationId;

  const LoginSmsCodeSent(this.verificationId);

  @override
  List<Object> get props => [verificationId];
}

class LoginFailure extends LoginState {
  final String? errorMessage;

  const LoginFailure({this.errorMessage});

  @override
  List<Object> get props => [];
}

class LoginSuccess extends LoginState {}
