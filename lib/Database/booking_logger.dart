import 'dart:io' show File, Directory, Platform, FileMode;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'booking_constants.dart';

/// Class to handle comprehensive logging to both console and file
class BookingLogger {
  static bool _isInitialized = false;
  static late Directory _logDirectory;
  static late File _logFile;

  /// Initialize the logger
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      _logDirectory = await _getLogDirectory();
      _logFile = File('${_logDirectory.path}/${BookingConstants.logFileName}');
      _isInitialized = true;

      // Add logger initialization log
      await log('BookingLogger initialized. Log path: ${_logFile.path}');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize BookingLogger: $e');
      }
    }
  }

  /// Get the appropriate log directory based on platform
  static Future<Directory> _getLogDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      // For desktop platforms
      return await getApplicationSupportDirectory();
    }
  }

  /// Log a message with timestamp to both console and file
  static Future<void> log(String message, {String? type}) async {
    final timestamp = _formatTimestamp();
    final logType = type ?? BookingConstants.defaultLogType;
    final formattedMessage = '[$timestamp] [$logType] $message';

    // Always log to console in debug mode
    if (kDebugMode) {
      debugPrint(formattedMessage);
    }

    // Try to log to file if initialized
    if (_isInitialized) {
      await _writeToFile(formattedMessage);
    }
  }

  /// Format the current timestamp
  static String _formatTimestamp() {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
  }

  /// Write message to file with error handling
  static Future<void> _writeToFile(String formattedMessage) async {
    try {
      await _logFile.writeAsString('$formattedMessage\n',
          mode: FileMode.append);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to write to log file: $e');
      }
    }
  }

  /// Log an error with stack trace
  static Future<void> logError(String message,
      {Object? error, StackTrace? stackTrace}) async {
    final errorMessage = error != null ? '$message: $error' : message;
    await log(errorMessage, type: 'ERROR');

    if (stackTrace != null && kDebugMode) {
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Log with different severity levels
  static Future<void> logInfo(String message) => log(message, type: 'INFO');
  static Future<void> logWarning(String message) =>
      log(message, type: 'WARNING');
  static Future<void> logDebug(String message) => log(message, type: 'DEBUG');
  static Future<void> logSuccess(String message) =>
      log(message, type: 'SUCCESS');

  /// Check if logger is initialized
  static bool get isInitialized => _isInitialized;

  /// Get log file path (useful for debugging)
  static String? get logFilePath => _isInitialized ? _logFile.path : null;
}
