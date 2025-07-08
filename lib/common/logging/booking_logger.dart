import 'dart:io' show File, Directory, Platform, FileMode;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/booking_constants.dart';

/// Handles logging to console and a device file.
class BookingLogger {
  static bool _isInitialized = false;
  static late Directory _logDirectory;
  static late File _logFile;

  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      _logDirectory = await _getLogDirectory();
      _logFile = File('${_logDirectory.path}/${BookingConstants.logFileName}');
      _isInitialized = true;
      await log('BookingLogger initialized. Log path: ${_logFile.path}');
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to initialize BookingLogger: $e');
    }
  }

  static Future<Directory> _getLogDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      return await getApplicationSupportDirectory();
    }
  }

  static Future<void> log(String message, {String? type}) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final logType = type ?? BookingConstants.defaultLogType;
    final formatted = '[$timestamp] [$logType] $message';
    if (kDebugMode) debugPrint(formatted);
    if (_isInitialized) {
      await _writeToFile(formatted);
    }
  }

  static Future<void> _writeToFile(String msg) async {
    try {
      await _logFile.writeAsString('$msg\n', mode: FileMode.append);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to write to log file: $e');
    }
  }

  static Future<void> logError(String m,
      {Object? error, StackTrace? stackTrace}) async {
    await log(error != null ? '$m: $error' : m, type: 'ERROR');
    if (stackTrace != null && kDebugMode)
      debugPrint('Stack trace: $stackTrace');
  }

  static Future<void> logInfo(String m) => log(m, type: 'INFO');
  static Future<void> logWarning(String m) => log(m, type: 'WARNING');
  static Future<void> logDebug(String m) => log(m, type: 'DEBUG');
  static Future<void> logSuccess(String m) => log(m, type: 'SUCCESS');

  static bool get isInitialized => _isInitialized;
  static String? get logFilePath => _isInitialized ? _logFile.path : null;
}
