part of 'login_cubit.dart';

sealed class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object> get props => [];
}

final class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {
  const LoginLoading({this.message});

  final String? message;

  @override
  List<Object> get props => [if (message != null) message!];
}

class LoginCodeSent extends LoginState {
  final String verificationId;
  final int? resendToken;

  const LoginCodeSent(this.verificationId, [this.resendToken]);

  @override
  List<Object> get props => [verificationId];
}

class LoginFailure extends LoginState {
  final String errorMessage;

  const LoginFailure({required this.errorMessage});

  @override
  List<Object> get props => [errorMessage];
}

class LoginSuccess extends LoginState {}
