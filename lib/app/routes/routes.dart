import 'package:auto_route/auto_route.dart';
import 'package:phone_authentication_project/app/bloc/app_bloc.dart';
import 'package:phone_authentication_project/home/view/home_page.dart';
import 'package:phone_authentication_project/login/view/login_page.dart';

part 'routes.gr.dart';

@AutoRouterConfig()
class AppRouter extends _$AppRouter {
  AppRouter(this._appBloc);

  final AppBloc _appBloc;

  @override
  List<AutoRoute> get routes => [
        AutoRoute(
          page: LoginRoute.page,
          path: '/login',
          initial: true,
          guards: [AuthRouteGuard(_appBloc)],
        ),
        AutoRoute(
          page: HomeRoute.page,
          path: '/home',
          guards: [LoginRequiredGuard(_appBloc)],
        ),
      ];
}

class LoginRequiredGuard extends AutoRouteGuard {
  LoginRequiredGuard(this._appBloc);

  final AppBloc _appBloc;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (_appBloc.state.status == AppStatus.authenticated) {
      resolver.next();
      return;
    }

    resolver.redirect(const LoginRoute());
  }
}

class AuthRouteGuard extends AutoRouteGuard {
  AuthRouteGuard(this._appBloc);

  final AppBloc _appBloc;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (_appBloc.state.status == AppStatus.authenticated) {
      resolver.redirect(const HomeRoute());
      return;
    }

    resolver.next();
  }
}
