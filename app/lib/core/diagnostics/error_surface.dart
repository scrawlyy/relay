import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Captures build/layout/async errors and renders them ON SCREEN instead of a
/// blank white surface, so a release build that fails still shows the actual
/// exception text. Diagnostic aid for device-side reports.
abstract final class ErrorSurface {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static final List<String> _errors = [];

  static List<String> get errors => List.unmodifiable(_errors);

  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;

    ErrorWidget.builder = (details) => ErrorSurfaceWidget(details: details);

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      _record(details.exceptionAsString());
      previous?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _record('$error\n$stack');
      return false;
    };
  }

  static void _record(String message) {
    _errors.add(message);
    if (_errors.length > 6) _errors.removeAt(0);
    revision.value++;
  }

  static void clear() {
    _errors.clear();
    revision.value++;
  }
}

/// Renders the failing widget's exception message in place of the broken
/// subtree. Kept deliberately simple: no theme, no assets, release-safe.
class ErrorSurfaceWidget extends StatelessWidget {
  const ErrorSurfaceWidget({super.key, required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0F),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Text(
          details.exceptionAsString(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF87171),
            fontSize: 13,
            height: 1.4,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}

/// Overlay banner pinned above the app showing any captured errors.
class ErrorSurfaceBanner extends StatelessWidget {
  const ErrorSurfaceBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ErrorSurface.revision,
      builder: (context, _, __) {
        final errors = ErrorSurface.errors;
        if (errors.isEmpty) return child;
        return Stack(
          children: [
            child,
            Positioned(
              left: 12,
              right: 12,
              bottom: 96,
              child: SafeArea(
                child: Material(
                  color: const Color(0xFF2A0A0F),
                  elevation: 8,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFF87171).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 16, color: Color(0xFFF87171)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Error caught',
                                style: TextStyle(
                                  color: Color(0xFFF87171),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: ErrorSurface.clear,
                              child: const Icon(Icons.close,
                                  size: 16, color: Color(0xFFF87171)),
                            ),
                          ],
                        ),
                        for (final error in errors.take(3))
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              error,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFF4F4F6),
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
