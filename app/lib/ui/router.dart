import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/onboarding_providers.dart';
import '../providers/profiles_providers.dart';
import 'dashboard/dashboard_screen.dart';
import 'diagnostics/diagnostics_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'profiles/profiles_screen.dart';
import 'settings/settings_screen.dart';
import 'shell/root_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
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
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            RootShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profiles',
              builder: (context, state) => const ProfilesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/diagnostics',
              builder: (context, state) => const DiagnosticsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});
