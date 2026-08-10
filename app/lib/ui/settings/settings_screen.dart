import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics/haptics.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/settings_providers.dart';
import '../shared/widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _probeUrl;

  @override
  void initState() {
    super.initState();
    _probeUrl = TextEditingController(
      text: ref.read(settingsProvider).probeUrl,
    );
  }

  @override
  void dispose() {
    _probeUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppTokens.space,
            AppTokens.space,
            AppTokens.space,
            AppTokens.dockClearance(context),
          ),
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: AppTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            const SectionHeader(title: 'Behaviour'),
            SectionCard(
              child: Column(
                children: [
                  _SwitchRow(
                    icon: Icons.vibration,
                    title: 'Haptics',
                    subtitle: 'Taptic Engine / vibration feedback',
                    value: settings.hapticsEnabled,
                    onChanged: (v) =>
                        ref.read(settingsProvider.notifier).setHapticsEnabled(v),
                  ),
                ],
              ),
            ),

            const SectionHeader(title: 'Diagnostics'),
            SectionCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Probe endpoint',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Used by the functional proxy check and tunnel latency '
                    'measurement. Must respond with a 2xx/3xx status.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _probeUrl,
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    onSubmitted: _saveProbeUrl,
                    decoration: const InputDecoration(
                      hintText: 'https://www.gstatic.com/generate_204',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _saveProbeUrl(_probeUrl.text),
                      child: const Text('Save endpoint'),
                    ),
                  ),
                ],
              ),
            ),

            const SectionHeader(title: 'About'),
            SectionCard(
              child: Column(
                children: [
                  _AboutRow(label: 'Version', value: '0.1.0'),
                  const Divider(),
                  _AboutRow(label: 'Engine', value: 'sing-box (GPL-3.0)'),
                  const Divider(),
                  _AboutRow(label: 'Secrets storage', value: 'Keychain / Keystore'),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'Relay is free software. The embedded sing-box engine is licensed '
              'under GPL-3.0; the app must be distributed GPL-compatible.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppTokens.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _saveProbeUrl(String value) {
    final url = value.trim();
    if (url.isEmpty) return;
    ref.read(settingsProvider.notifier).setProbeUrl(url);
    AppHaptics.tap();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Probe endpoint saved')),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTokens.accent),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppTokens.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
