import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/profile.dart';

const _kProfilesKey = 'profiles.v1';
const _kActiveProfileId = 'active_profile_id.v1';
const _kOnboardedKey = 'onboarded.v1';
const _kHapticsEnabledKey = 'haptics_enabled.v1';
const _kProbeUrlKey = 'probe_url.v1';

/// Persistence for profile metadata (JSON in shared prefs) and secrets
/// (Keychain/Keystore via flutter_secure_storage).
class ProfileRepository {
  ProfileRepository(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static Future<ProfileRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ProfileRepository(prefs, const FlutterSecureStorage());
  }

  List<Profile> loadProfiles() {
    final raw = _prefs.getString(_kProfilesKey);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Profile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveProfiles(List<Profile> profiles) async {
    final encoded = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await _prefs.setString(_kProfilesKey, encoded);
  }

  String? get activeProfileId => _prefs.getString(_kActiveProfileId);

  Future<void> setActiveProfileId(String? id) async {
    if (id == null) {
      await _prefs.remove(_kActiveProfileId);
    } else {
      await _prefs.setString(_kActiveProfileId, id);
    }
  }

  bool get onboarded => _prefs.getBool(_kOnboardedKey) ?? false;

  Future<void> setOnboarded() => _prefs.setBool(_kOnboardedKey, true);

  bool loadHapticsEnabled() => _prefs.getBool(_kHapticsEnabledKey) ?? true;

  Future<void> saveHapticsEnabled(bool enabled) =>
      _prefs.setBool(_kHapticsEnabledKey, enabled);

  String loadProbeUrl() =>
      _prefs.getString(_kProbeUrlKey) ?? 'https://www.gstatic.com/generate_204';

  Future<void> saveProbeUrl(String url) => _prefs.setString(_kProbeUrlKey, url);

  Future<String?> readPassword(String profileId) =>
      _secure.read(key: 'pw_$profileId');

  Future<void> writePassword(String profileId, String password) =>
      _secure.write(key: 'pw_$profileId', value: password);

  Future<void> deletePassword(String profileId) =>
      _secure.delete(key: 'pw_$profileId');
}
