import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/diagnostics/error_surface.dart';
import 'data/profile_repository.dart';
import 'providers/profiles_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorSurface.init();
  final repository = await ProfileRepository.create();
  runApp(
    ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repository),
      ],
      child: const RelayApp(),
    ),
  );
}
