import 'package:intl/intl.dart';

final _bytesFormat = NumberFormat('#,##0');
final _rateFormat = NumberFormat('#,##0');

/// Formats byte counts (1024-based) for human display, e.g. "12.4 MB".
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${_short(kb)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${_short(mb)} MB';
  final gb = mb / 1024;
  return '${_short(gb)} GB';
}

String _short(double value) {
  if (value >= 100) return value.toStringAsFixed(0);
  if (value >= 10) return value.toStringAsFixed(1);
  return value.toStringAsFixed(1);
}

/// Formats a rate in bytes/sec, e.g. "1.2 MB/s".
String formatRate(int bytesPerSecond) => '${formatBytes(bytesPerSecond)}/s';

/// Formats a millisecond latency, e.g. "84 ms".
String formatLatency(int ms) => '$ms ms';

/// Formats a duration like "2h 14m".
String formatUptime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}

String formatCount(int value) => _bytesFormat.format(value);
String formatRateNumber(double value) => _rateFormat.format(value);
