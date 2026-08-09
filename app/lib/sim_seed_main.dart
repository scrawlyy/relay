import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/diagnostics/error_surface.dart';
import 'data/profile_repository.dart';
import 'domain/profile.dart';
import 'providers/profiles_providers.dart';

/// Simulator-only entrypoint (FLUTTER_TARGET=lib/sim_seed_main.dart) that
/// seeds onboarding + one profile from Dart, so CI launches the app straight
/// into the shell (dashboard) for screenshot/log diagnostics.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorSurface.init();
  final repository = await ProfileRepository.create();
  await repository.setOnboarded();
  await repository.saveProfiles(const [
    Profile(
      id: 'seed1',
      name: 'CI Seed',
      protocol: ProxyProtocol.socks5,
      host: '1.2.3.4',
      port: 1080,
    ),
  ]);
  await repository.setActiveProfileId('seed1');
  runApp(
    ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repository),
      ],
      child: const RelayApp(),
    ),
  );
}
