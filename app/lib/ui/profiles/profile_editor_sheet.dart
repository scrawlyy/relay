import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:vpn_platform/vpn_platform.dart' as vpn;

import '../../core/haptics/haptics.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../domain/profile.dart';
import '../../platform/profile_adapter.dart';
import '../../providers/profiles_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/vpn_providers.dart';

/// Bottom-sheet editor with live validation and an inline FUNCTIONAL proxy
/// test (full handshake + probe request through the proxy).
class ProfileEditorSheet extends ConsumerStatefulWidget {
  const ProfileEditorSheet({super.key, this.profile});

  final Profile? profile;

  @override
  ConsumerState<ProfileEditorSheet> createState() => _ProfileEditorSheetState();
}

class _ProfileEditorSheetState extends ConsumerState<ProfileEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;

  late ProxyProtocol _protocol;
  late bool _obscurePassword;

  bool _testing = false;
  vpn.ProbeOutcome? _testResult;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _protocol = profile?.protocol ?? ProxyProtocol.socks5;
    _obscurePassword = true;
    _name = TextEditingController(text: profile?.name ?? '');
    _host = TextEditingController(text: profile?.host ?? '');
    final port = profile?.port ?? 0;
    _port = TextEditingController(text: port != 0 ? '$port' : '');
    _username = TextEditingController(text: profile?.username ?? '');
    _password = TextEditingController(text: profile?.password ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Profile _draft({String? id}) => Profile(
        id: id ?? widget.profile?.id ?? const Uuid().v4(),
        name: _name.text.trim(),
        protocol: _protocol,
        host: _host.text.trim(),
        port: int.tryParse(_port.text.trim()) ?? 0,
        username: _username.text.trim().isEmpty
            ? null
            : _username.text.trim(),
        password: _password.text.isEmpty ? null : _password.text,
        createdAt: widget.profile?.createdAt ?? DateTime.now(),
      );

  Future<void> _runTest() async {
    final validation = ProfileValidation.validate(_draft());
    if (!validation.isValid) {
      AppHaptics.error();
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final vpn = ref.read(vpnPlatformProvider);
    final probeUrl = ref.read(settingsProvider).probeUrl;
    final outcome = await vpn.probeProxy(
      _draft().toVpnProfile(),
      probeUrl: probeUrl,
    );
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = outcome;
    });
    outcome.ok ? AppHaptics.connected() : AppHaptics.connectFailed();
  }

  Future<void> _save() async {
    final draft = _draft();
    final validation = ProfileValidation.validate(draft);
    if (!validation.isValid) {
      AppHaptics.error();
      return;
    }
    setState(() => _saving = true);
    await ref.read(profilesProvider.notifier).upsert(
          draft,
          password: draft.password,
        );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.profile == null;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTokens.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isNew ? 'New profile' : 'Edit profile',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (_) => _nameError(),
              ),
              const SizedBox(height: 12),
              SegmentedButton<ProxyProtocol>(
                segments: const [
                  ButtonSegment(
                    value: ProxyProtocol.socks5,
                    label: Text('SOCKS5'),
                    icon: Icon(Icons.route),
                  ),
                  ButtonSegment(
                    value: ProxyProtocol.http,
                    label: Text('HTTP'),
                    icon: Icon(Icons.language),
                  ),
                ],
                selected: {_protocol},
                onSelectionChanged: (selection) =>
                    setState(() => _protocol = selection.first),
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppTokens.surfaceElevated,
                  foregroundColor: AppTokens.textSecondary,
                  selectedBackgroundColor: AppTokens.accentSoft,
                  selectedForegroundColor: AppTokens.accent,
                  side: const BorderSide(color: AppTokens.hairline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _host,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Server host'),
                validator: (_) => _hostError(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _port,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Port'),
                validator: (_) => _portError(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _username,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Username (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Password (optional)',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                      color: AppTokens.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _TestResultBanner(result: _testResult, testing: _testing),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testing ? null : _runTest,
                      icon: _testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check, size: 18),
                      label: Text(_testing ? 'Testing…' : 'Test proxy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTokens.accent,
                        side: const BorderSide(color: AppTokens.hairline),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTokens.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_saving ? 'Saving…' : 'Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _firstError() => ProfileValidation.validate(_draft()).errors.firstOrNull;

  List<String> _fieldErrors() => ProfileValidation.validate(_draft()).errors;

  String? _nameError() {
    final errors = _fieldErrors();
    return errors.where((e) => e.contains('name') || e.contains('Name')).firstOrNull;
  }

  String? _hostError() {
    final errors = _fieldErrors();
    return errors.where((e) => e.contains('IP') || e.contains('hostname')).firstOrNull;
  }

  String? _portError() {
    final errors = _fieldErrors();
    return errors.where((e) => e.contains('Port')).firstOrNull;
  }
}

class _TestResultBanner extends StatelessWidget {
  const _TestResultBanner({required this.result, required this.testing});

  final vpn.ProbeOutcome? result;
  final bool testing;

  @override
  Widget build(BuildContext context) {
    if (testing) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'Running functional check…',
              style: TextStyle(fontSize: 12, color: AppTokens.textSecondary),
            ),
          ],
        ),
      );
    }
    final r = result;
    if (r == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Sends a real probe request through the proxy and verifies the response.',
          style: TextStyle(fontSize: 12, color: AppTokens.textTertiary),
        ),
      );
    }
    final ok = r.ok;
    final color = ok ? AppTokens.success : AppTokens.danger;
    return AnimatedContainer(
      duration: AppTokens.durationMed,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTokens.radiusInner),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ok
                  ? 'Proxy is working — probe returned HTTP ${r.httpStatus} '
                      'in ${formatLatency(r.totalRttMs)}'
                  : 'Proxy check failed: ${r.error ?? 'no response'}',
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
