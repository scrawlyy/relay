import 'dart:async';

import 'package:flutter/material.dart';

/// Diagnostic entrypoint: pure Flutter, no plugins, no fonts, no router.
/// Blinks red/green every second so any rendered frame is visible.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _MinimalApp());
}

class _MinimalApp extends StatelessWidget {
  const _MinimalApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const _Blinker(),
    );
  }
}

class _Blinker extends StatefulWidget {
  const _Blinker();

  @override
  State<_Blinker> createState() => _BlinkerState();
}

class _BlinkerState extends State<_Blinker> {
  bool _on = false;

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _on = !_on);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _on ? Colors.green : Colors.red,
      child: Center(
        child: Text(
          _on ? 'RELAY MINIMAL OK (green)' : 'RELAY MINIMAL OK (red)',
          style: const TextStyle(fontSize: 24, color: Colors.white),
        ),
      ),
    );
  }
}