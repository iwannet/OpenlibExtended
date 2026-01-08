// Dart imports:
import 'dart:collection';
import 'dart:io';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Log entry class to store individual log messages
class LogEntry {
  final DateTime timestamp;
  final String level;
  final String message;
  final String? tag;
  final dynamic error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}] ');
    buffer.write('[$level] ');
    if (tag != null) {
      buffer.write('[$tag] ');
    }
    buffer.write(message);
    if (error != null) {
      buffer.write('\nError: $error');
    }
    if (stackTrace != null) {
      buffer.write('\nStack trace:\n$stackTrace');
    }
    return buffer.toString();
  }
}

/// Logger service to capture and export app logs
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  // Store logs for the past 5 minutes
  final Queue<LogEntry> _logs = Queue<LogEntry>();
  static const Duration _logRetentionDuration = Duration(minutes: 5);
  static const int _maxLogEntries = 1000; // Limit to prevent memory issues

  /// Add a log entry
  void _addLog(String level, String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );

    _logs.addLast(entry);
    
    // Also print to console in debug mode
    if (kDebugMode) {
      debugPrint(entry.toString());
    }

    // Remove old logs
    _cleanOldLogs();
    
    // Limit log size
    while (_logs.length > _maxLogEntries) {
      _logs.removeFirst();
    }
  }

  /// Remove logs older than 5 minutes
  void _cleanOldLogs() {
    final cutoffTime = DateTime.now().subtract(_logRetentionDuration);
    while (_logs.isNotEmpty && _logs.first.timestamp.isBefore(cutoffTime)) {
      _logs.removeFirst();
    }
  }

  /// Log debug message
  void debug(String message, {String? tag}) {
    _addLog('DEBUG', message, tag: tag);
  }

  /// Log info message
  void info(String message, {String? tag}) {
    _addLog('INFO', message, tag: tag);
  }

  /// Log warning message
  void warning(String message, {String? tag, dynamic error}) {
    _addLog('WARNING', message, tag: tag, error: error);
  }

  /// Log error message
  void error(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    _addLog('ERROR', message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Get all logs as a formatted string
  String getAllLogs() {
    _cleanOldLogs();
    
    final buffer = StringBuffer();
    buffer.writeln('=== Openlib App Logs ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Log retention: Last ${_logRetentionDuration.inMinutes} minutes');
    buffer.writeln('Total entries: ${_logs.length}');
    buffer.writeln('');
    buffer.writeln('=== System Information ===');
    buffer.writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    buffer.writeln('Dart version: ${Platform.version}');
    buffer.writeln('');
    buffer.writeln('=== Log Entries ===');
    
    for (final log in _logs) {
      buffer.writeln(log.toString());
      buffer.writeln('');
    }
    
    return buffer.toString();
  }

  /// Export logs to a file and share
  Future<void> exportLogs() async {
    try {
      final logsContent = getAllLogs();
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final file = File('${tempDir.path}/openlib_logs_$timestamp.txt');
      
      // Write logs to file
      await file.writeAsString(logsContent);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Openlib App Logs - $timestamp',
        text: 'Openlib app logs for the past ${_logRetentionDuration.inMinutes} minutes',
      );
      
      info('Logs exported successfully', tag: 'AppLogger');
    } catch (e, stackTrace) {
      error('Failed to export logs', tag: 'AppLogger', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Clear all logs
  void clearLogs() {
    _logs.clear();
    info('Logs cleared', tag: 'AppLogger');
  }

  /// Get log count
  int get logCount {
    _cleanOldLogs();
    return _logs.length;
  }
}
