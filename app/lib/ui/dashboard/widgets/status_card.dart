import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../providers/connection_providers.dart';
import '../../../providers/profiles_providers.dart';

/// The hero card: a single large button that connects/disconnects the active
/// profile, with a clear state label and the profile endpoint underneath.
class StatusCard extends ConsumerWidget {
  const StatusCard({super.key, required this.connection});

  final ConnectionState connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeProfileProvider);
    final busy = connection.phase == ConnectionPhase.connecting ||
        connection.phase == ConnectionPhase.disconnecting;

    final (label, color) = switch (connection.phase) {
      ConnectionPhase.connected => ('Connected', AppTokens.success),
      ConnectionPhase.connecting => ('Connecting…', AppTokens.accent),
      ConnectionPhase.disconnecting => ('Disconnecting…', AppTokens.warning),
      ConnectionPhase.error => ('Connection failed', AppTokens.danger),
      ConnectionPhase.disconnected => ('Disconnected', AppTokens.textTertiary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: Column(
        children: [
          _PowerButton(
            connected: connection.phase == ConnectionPhase.connected,
            busy: busy,
            onTap: () {
              if (connection.isActive) {
                ref.read(connectionProvider.notifier).disconnect();
              } else {
                ref.read(connectionProvider.notifier).connect();
              }
            },
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: AppTokens.durationMed,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Text(
              label,
              key: ValueKey(label),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            connection.profile?.displayHost ?? active?.displayHost ?? 'No profile',
            style: const TextStyle(
              fontSize: 13,
              color: AppTokens.textSecondary,
            ),
          ),
          if (connection.errorMessage != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                connection.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTokens.danger,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PowerButton extends StatefulWidget {
  const _PowerButton({
    required this.connected,
    required this.busy,
    required this.onTap,
  });

  final bool connected;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<_PowerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final size = 132.0;
    final innerSize = 100.0;
    final ringColor = widget.connected ? AppTokens.success : AppTokens.accent;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        AppHaptics.tap();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: AppTokens.durationFast,
        curve: AppTokens.easeOut,
        child: AnimatedContainer(
          duration: AppTokens.durationMed,
          curve: AppTokens.easeEmphasized,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ringColor.withValues(alpha: widget.busy ? 0.3 : 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: ringColor.withValues(alpha: widget.busy ? 0.08 : 0.18),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Center(
            child: AnimatedContainer(
              duration: AppTokens.durationMed,
              curve: AppTokens.easeEmphasized,
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.connected
                    ? AppTokens.success
                    : AppTokens.accent,
              ),
              child: AnimatedSwitcher(
                duration: AppTokens.durationMed,
                child: Icon(
                  widget.connected ? Icons.power : Icons.power_off,
                  key: ValueKey(widget.connected),
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
