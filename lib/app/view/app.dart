import 'package:authentication_repository/authentication_repository.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phone_authentication_project/app/bloc/app_bloc.dart';
import 'package:phone_authentication_project/app/routes/routes.dart';

class App extends StatelessWidget {
  const App({
    required AuthenticationRepository authenticationRepository,
    super.key,
  }) : _authenticationRepository = authenticationRepository;

  final AuthenticationRepository _authenticationRepository;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: _authenticationRepository,
      child: BlocProvider(
        create: (_) => AppBloc(
          authenticationRepository: _authenticationRepository,
        ),
        child: AppView(),
      ),
    );
  }
}

class AppView extends StatefulWidget {
  const AppView({super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(context.read<AppBloc>());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppBloc, AppState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, currentState) {
        if (currentState.status == AppStatus.authenticated) {
          _appRouter.replaceAll([const HomeRoute()]);
        } else {
          _appRouter.replaceAll([const LoginRoute()]);
        }
      },
      child: MaterialApp.router(
        title: 'Phone Authentication',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0B7A75),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F8FC),
          useMaterial3: true,
        ),
        routerConfig: _appRouter.config(
          navigatorObservers: () => [AutoRouteObserver()],
        ),
      ),
    );
  }
}
