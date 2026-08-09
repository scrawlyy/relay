import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/profile.dart';

/// Bootstrapped in main() with the real repository.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => throw UnimplementedError('profileRepositoryProvider must be overridden'),
);

/// All saved profiles, ordered by creation.
final profilesProvider =
    NotifierProvider<ProfilesNotifier, List<Profile>>(ProfilesNotifier.new);

class ProfilesNotifier extends Notifier<List<Profile>> {
  @override
  List<Profile> build() {
    return ref.watch(profileRepositoryProvider).loadProfiles();
  }

  /// Upsert a profile. Pass [password] to persist a (new) secret, or
  /// [clearPassword] to remove the stored secret.
  Future<void> upsert(
    Profile profile, {
    String? password,
    bool clearPassword = false,
  }) async {
    final repo = ref.read(profileRepositoryProvider);
    if (password != null) {
      await repo.writePassword(profile.id, password);
    } else if (clearPassword) {
      await repo.deletePassword(profile.id);
    }
    final list = [
      ...state.where((p) => p.id != profile.id),
      profile.copyWith(password: null),
    ]..sort((a, b) => (a.createdAt ?? DateTime(0))
        .compareTo(b.createdAt ?? DateTime(0)));
    state = list;
    await repo.saveProfiles(list);
  }

  Future<void> remove(String profileId) async {
    final repo = ref.read(profileRepositoryProvider);
    await repo.deletePassword(profileId);
    final list = state.where((p) => p.id != profileId).toList();
    state = list;
    await repo.saveProfiles(list);
    if (ref.read(activeProfileProvider)?.id == profileId) {
      await ref.read(activeProfileProvider.notifier).selectFirst();
    }
  }

  /// Loads the profile with its decrypted password (for connect/probe).
  Future<Profile> withPassword(Profile profile) async {
    final repo = ref.read(profileRepositoryProvider);
    final password = await repo.readPassword(profile.id);
    return profile.copyWith(password: password);
  }
}

/// The currently selected profile.
final activeProfileProvider =
    NotifierProvider<ActiveProfileNotifier, Profile?>(ActiveProfileNotifier.new);

class ActiveProfileNotifier extends Notifier<Profile?> {
  @override
  Profile? build() {
    final repo = ref.watch(profileRepositoryProvider);
    final profiles = ref.watch(profilesProvider);
    if (profiles.isEmpty) return null;
    final id = repo.activeProfileId;
    if (id != null) {
      final match = profiles.where((p) => p.id == id).firstOrNull;
      if (match != null) return match;
    }
    return profiles.first;
  }

  Future<void> select(Profile profile) async {
    final repo = ref.read(profileRepositoryProvider);
    await repo.setActiveProfileId(profile.id);
    ref.invalidateSelf();
  }

  Future<void> selectFirst() async {
    final repo = ref.read(profileRepositoryProvider);
    await repo.setActiveProfileId(null);
    ref.invalidateSelf();
  }
}
