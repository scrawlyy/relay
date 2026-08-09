import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics/haptics.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/profile.dart';
import '../../providers/profiles_providers.dart';
import '../shared/widgets.dart';
import 'profile_editor_sheet.dart';

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final active = ref.watch(activeProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: profiles.isEmpty
            ? EmptyState(
                icon: Icons.alt_route,
                title: 'No profiles yet',
                message:
                    'Add your first SOCKS5 or HTTP proxy to get started.\n\n'
                    'Profiles are stored on-device; passwords live in the '
                    'system keychain.',
                actionLabel: 'Add profile',
                onAction: () => _openEditor(context, ref),
              )
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppTokens.space),
                children: [
                  const Text(
                    'Profiles',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: AppTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final profile in profiles) ...[
                    _ProfileTile(
                      profile: profile,
                      isActive: active?.id == profile.id,
                      onTap: () async {
                        await ref
                            .read(activeProfileProvider.notifier)
                            .select(profile);
                        AppHaptics.select();
                      },
                      onEdit: () => _openEditor(context, ref, profile: profile),
                      onDelete: () =>
                          _confirmDelete(context, ref, profile),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 4),
                  _AddButton(
                    onTap: () => _openEditor(context, ref),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    Profile? profile,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ProfileEditorSheet(profile: profile),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTokens.surface,
        title: Text('Delete “${profile.name}”?'),
        content: const Text('This removes the profile and its stored password.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppTokens.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(profilesProvider.notifier).remove(profile.id);
      AppHaptics.error();
    }
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Profile profile;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isActive ? AppTokens.accentSoft : AppTokens.surfaceInteractive,
              borderRadius: BorderRadius.circular(AppTokens.radiusInner),
            ),
            child: Icon(
              profile.protocol == ProxyProtocol.socks5
                  ? Icons.route
                  : Icons.language,
              size: 20,
              color: isActive ? AppTokens.accent : AppTokens.textSecondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${profile.protocol.name.toUpperCase()} · ${profile.displayHost}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: AppPill(
                label: 'Active',
                color: AppTokens.success,
              ),
            ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: AppTokens.textSecondary),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppTokens.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            border: Border.all(
              color: AppTokens.accent.withValues(alpha: 0.4),
              style: BorderStyle.solid,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 18, color: AppTokens.accent),
              SizedBox(width: 8),
              Text(
                'Add profile',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
