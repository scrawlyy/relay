import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/haptics/haptics.dart';
import '../shared/widgets.dart';

/// Root scaffold hosting the four-tab shell with a floating liquid-glass
/// pill navigation.
class RootShell extends ConsumerWidget {
  const RootShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The dock floats as an overlay (Stack), not a bottomNavigationBar.
    // bottomNavigationBar reserves its own dedicated strip of screen, so
    // there's nothing behind the frosted glass for it to actually blur, and
    // scrollable content stops dead above it instead of flowing underneath.
    // Screens add AppTokens.dockClearance() bottom padding so their content
    // still clears the dock visually.
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(navigationShell.currentIndex),
              tween: Tween(begin: 0, end: 1),
              duration: AppTokens.durationMed,
              curve: AppTokens.easeEmphasized,
              builder: (context, t, child) =>
                  Opacity(opacity: 0.25 + 0.75 * t, child: child),
              child: navigationShell,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _NavBar(
              currentIndex: navigationShell.currentIndex,
              onSelect: (index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
                AppHaptics.select();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const _tabs = [
    (icon: Icons.bolt_outlined, activeIcon: Icons.bolt, label: 'Tunnel'),
    (icon: Icons.alt_route_outlined, activeIcon: Icons.alt_route, label: 'Profiles'),
    (icon: Icons.query_stats_outlined, activeIcon: Icons.query_stats, label: 'Diagnostics'),
    (icon: Icons.tune_outlined, activeIcon: Icons.tune, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            height: AppTokens.dockHeight,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTokens.glassFill,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(color: AppTokens.glassStroke),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slotWidth = constraints.maxWidth / _tabs.length;
                return Stack(
                  children: [
                    // Sliding pill: one physical highlight that glides
                    // between tabs instead of each tab toggling its own
                    // background. This is what actually reads as "liquid"
                    // rather than a flat state swap.
                    AnimatedPositioned(
                      duration: AppTokens.durationMed,
                      curve: AppTokens.easeEmphasized,
                      left: slotWidth * currentIndex,
                      top: 0,
                      bottom: 0,
                      width: slotWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppTokens.surfaceInteractive,
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusPill),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < _tabs.length; i++)
                          Expanded(
                            child: _TabButton(
                              icon: _tabs[i].icon,
                              activeIcon: _tabs[i].activeIcon,
                              label: _tabs[i].label,
                              selected: currentIndex == i,
                              onTap: () => onSelect(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      pressedScale: 0.86,
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1.0,
              duration: AppTokens.durationMed,
              curve: AppTokens.easeEmphasized,
              child: Icon(
                selected ? activeIcon : icon,
                size: 22,
                color: selected ? AppTokens.accent : AppTokens.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: AppTokens.durationMed,
              curve: AppTokens.easeEmphasized,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? AppTokens.accent : AppTokens.textTertiary,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
