import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/haptics/haptics.dart';
import '../data/profile_repository.dart';

class AppSettings {
  const AppSettings({
    required this.hapticsEnabled,
    required this.probeUrl,
  });

  final bool hapticsEnabled;
  final String probeUrl;

  static const defaults = AppSettings(
    hapticsEnabled: true,
    probeUrl: 'https://www.gstatic.com/generate_204',
  );

  AppSettings copyWith({bool? hapticsEnabled, String? probeUrl}) =>
      AppSettings(
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        probeUrl: probeUrl ?? this.probeUrl,
      );
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final prefs = ref.watch(profileRepositoryProvider);
    return AppSettings(
      hapticsEnabled: prefs.loadHapticsEnabled(),
      probeUrl: prefs.loadProbeUrl(),
    );
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    state = state.copyWith(hapticsEnabled: enabled);
    await AppHaptics.setEnabled(enabled);
    await ref.read(profileRepositoryProvider).saveHapticsEnabled(enabled);
  }

  Future<void> setProbeUrl(String url) async {
    state = state.copyWith(probeUrl: url.trim());
    await ref
        .read(profileRepositoryProvider)
        .saveProbeUrl(state.probeUrl);
  }
}
