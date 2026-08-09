import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_tokens.dart';
import '../providers/onboarding_providers.dart';
import '../providers/profiles_providers.dart';
import 'dashboard/dashboard_screen.dart';
import 'diagnostics/diagnostics_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'profiles/profiles_screen.dart';
import 'settings/settings_screen.dart';
import 'shell/root_shell.dart';

/// Route-level entrance: fade + gentle rise, shared by every page.
Page<void> _fadeSlidePage(Widget child) => CustomTransitionPage<void>(
      transitionDuration: AppTokens.durationMed,
      reverseTransitionDuration: AppTokens.durationFast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: child,
    );

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(onboardedProvider, (_, __) => refresh.value++);
  ref.listen(profilesProvider, (_, __) => refresh.value++);
  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/',
    redirect: (context, state) {
      final onboarded = ref.read(onboardedProvider);
      final profiles = ref.read(profilesProvider);
      final location = state.matchedLocation;
      if (!onboarded && location != '/onboarding') {
        return '/onboarding';
      }
      if (onboarded && profiles.isEmpty && location != '/profiles') {
        return '/profiles';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _fadeSlidePage(const OnboardingScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            RootShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) => _fadeSlidePage(const DashboardScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profiles',
              pageBuilder: (context, state) => _fadeSlidePage(const ProfilesScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/diagnostics',
              pageBuilder: (context, state) => _fadeSlidePage(const DiagnosticsScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => _fadeSlidePage(const SettingsScreen()),
            ),
          ]),
        ],
      ),
    ],
  );
});
