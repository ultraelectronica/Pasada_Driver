enum AppRoute { login }

extension AppRoutePath on AppRoute {
  String get path => switch (this) {
        AppRoute.login => '/login',
      };
}
