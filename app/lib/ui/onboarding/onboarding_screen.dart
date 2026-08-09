import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics/haptics.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/onboarding_providers.dart';
import '../shared/widgets.dart';

/// First-run experience: three short slides about what Relay does and how
/// privacy is handled.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    (
      icon: Icons.alt_route,
      title: 'Route everything through your proxy',
      body:
          'Relay builds a secure on-device VPN that sends all traffic through '
          'your own SOCKS5 or HTTP proxy. Nothing touches your provider’s '
          'network first.',
    ),
    (
      icon: Icons.verified_user_outlined,
      title: 'Private by design',
      body:
          'Proxy credentials are stored only in the system keychain or keystore. '
          'No accounts, no telemetry, no cloud.',
    ),
    (
      icon: Icons.query_stats,
      title: 'See it working',
      body:
          'Live throughput charts and a real functional probe — Relay verifies '
          'traffic actually flows through your proxy, not just that it responds.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: AppTokens.accentSoft,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(
                            slide.icon,
                            size: 42,
                            color: AppTokens.accent,
                          ),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.2,
                            color: AppTokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: AppTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: AppTokens.durationFast,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? AppTokens.accent
                          : AppTokens.textTertiary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
              child: PressScale(
                child: FilledButton(
                  onPressed: () {
                    if (_page < _slides.length - 1) {
                      _controller.nextPage(
                        duration: AppTokens.durationMed,
                        curve: AppTokens.easeEmphasized,
                      );
                    } else {
                      AppHaptics.tap();
                      ref.read(onboardedProvider.notifier).complete();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTokens.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: AnimatedSwitcher(
                    duration: AppTokens.durationFast,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: Text(
                      _page < _slides.length - 1 ? 'Next' : 'Get started',
                      key: ValueKey(_page < _slides.length - 1),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
