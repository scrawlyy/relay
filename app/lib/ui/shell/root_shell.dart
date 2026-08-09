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
    return Scaffold(
      body: TweenAnimationBuilder<double>(
        key: ValueKey(navigationShell.currentIndex),
        tween: Tween(begin: 0, end: 1),
        duration: AppTokens.durationMed,
        curve: AppTokens.easeEmphasized,
        builder: (context, t, child) =>
            Opacity(opacity: 0.25 + 0.75 * t, child: child),
        child: navigationShell,
      ),
      bottomNavigationBar: _NavBar(
        currentIndex: navigationShell.currentIndex,
        onSelect: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
          AppHaptics.select();
        },
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
            height: 66,
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
            child: Row(
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
      child: AnimatedContainer(
        duration: AppTokens.durationMed,
        curve: AppTokens.easeEmphasized,
        decoration: BoxDecoration(
          color: selected ? AppTokens.surfaceInteractive : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        ),
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
