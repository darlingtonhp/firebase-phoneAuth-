import 'package:auto_route/auto_route.dart';
import 'package:phone_authentication_project/app/bloc/app_bloc.dart';
import 'package:phone_authentication_project/home/view/home_page.dart';
import 'package:phone_authentication_project/login/view/login_page.dart';

part 'routes.gr.dart';

@AutoRouterConfig()
class AppRouter extends _$AppRouter {
  @override
  List<AutoRoute> get routes {
    AppStatus status = AppStatus.unauthenticated;
    switch (status) {
      case AppStatus.authenticated:
        return [AutoRoute(page: HomeRoute.page)];
      case AppStatus.unauthenticated:
        return [AutoRoute(page: LoginRoute.page)];
    }
  }
}
