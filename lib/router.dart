import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/feature_flags.dart';
import 'core/navigation_keys.dart';
import 'features/auth/auth_providers.dart';
import 'features/auth/login_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/main_shell.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._ref) {
    _sub1 = _ref.listen<AsyncValue<dynamic>>(authStateProvider, (
      previous,
      next,
    ) {
      notifyListeners();
    });
    if (kOnboardingFlowEnabled) {
      _sub2 = _ref.listen<AsyncValue<dynamic>>(onboardingCompletedProvider, (
        previous,
        next,
      ) {
        notifyListeners();
      });
    }
  }

  final Ref _ref;
  late final ProviderSubscription _sub1;
  ProviderSubscription? _sub2;

  @override
  void dispose() {
    _sub1.close();
    _sub2?.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: refresh,
    routes: [_loginRoute(), _onboardingRoute(), _mainShellRoute()],
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final user = auth.value;

      final loggingIn = state.matchedLocation == '/login';
      final onboarding = state.matchedLocation == '/onboarding';

      // While auth is loading, stay put.
      if (auth.isLoading) return null;

      // Not signed in -> go to login.
      if (user == null) {
        return loggingIn ? null : '/login';
      }

      // Onboarding flow disabled: go straight to home after sign-in.
      if (!kOnboardingFlowEnabled) {
        if (loggingIn || onboarding) {
          return '/';
        }
        return null;
      }

      // Signed in -> decide onboarding vs main shell.
      final onboardingCompletedAsync = ref.read(onboardingCompletedProvider);
      final onboardingCompleted = onboardingCompletedAsync.when(
        data: (v) => v,
        loading: () => false,
        error: (error, stackTrace) => false,
      );

      // If we don't know yet (loading/error), keep user off login page.
      final onboardingUnknown =
          onboardingCompletedAsync.isLoading ||
          onboardingCompletedAsync.hasError;
      if (onboardingUnknown) {
        return loggingIn ? '/' : null;
      }

      if (!onboardingCompleted) {
        return onboarding ? null : '/onboarding';
      }

      // Onboarded: keep off login/onboarding.
      if (loggingIn || onboarding) {
        return '/';
      }

      return null;
    },
  );
});

GoRoute _loginRoute() => GoRoute(
  path: '/login',
  name: 'login',
  builder: (context, state) => const LoginScreen(),
);

GoRoute _onboardingRoute() => GoRoute(
  path: '/onboarding',
  name: 'onboarding',
  // Kept for when kOnboardingFlowEnabled is true again.
  builder: (context, state) => const OnboardingScreen(),
);

GoRoute _mainShellRoute() => GoRoute(
  path: '/',
  name: 'shell',
  builder: (context, state) => const MainShell(),
);
