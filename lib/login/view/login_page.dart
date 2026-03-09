import 'package:authentication_repository/authentication_repository.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phone_authentication_project/login/cubit/login_cubit.dart';
import 'package:phone_authentication_project/login/view/login_form.dart';

@RoutePage()
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(context.read<AuthenticationRepository>()),
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEFFCFB),
                Color(0xFFE5F4FF),
                Color(0xFFF6F9FF),
              ],
            ),
          ),
          child: const SafeArea(
            child: LoginForm(),
          ),
        ),
      ),
    );
  }
}
