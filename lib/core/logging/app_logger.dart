import 'dart:developer' as dev;

enum LogCategory {
  auth,
  backup,
  sync,
  restore,
  database,
  camera,
  editor,
  general,
}

class AppLogger {
  AppLogger._();

  static void info(LogCategory category, String message) {
    _log('INFO', category, message);
  }

  static void warning(LogCategory category, String message, [Object? error, StackTrace? stackTrace]) {
    _log('WARNING', category, message, error, stackTrace);
  }

  static void error(LogCategory category, String message, [Object? error, StackTrace? stackTrace]) {
    _log('ERROR', category, message, error, stackTrace);
  }

  static void _log(String level, LogCategory category, String message, [Object? error, StackTrace? stackTrace]) {
    // Basic structural safety check to avoid logging private user paths or tokens
    final sanitizedMessage = _sanitize(message);
    
    dev.log(
      '[$level] [${category.name.toUpperCase()}] $sanitizedMessage',
      name: 'video_journal',
      time: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static String _sanitize(String input) {
    // Basic filter to ensure we don't accidentally log absolute user paths
    // e.g. replacing direct files paths or token strings with placeholders.
    var sanitized = input;
    if (sanitized.contains('/data/user/') || sanitized.contains('C:\\') || sanitized.contains('/Users/')) {
      sanitized = sanitized.replaceAll(RegExp(r'(/data/user/\d+/[^/]+/files/[^\s]+)|(C:\\Users\\[^\s]+)|(/Users/[^\s]+)'), '[LOCAL_PATH_REDACTED]');
    }
    // Simple check for access token logs
    if (sanitized.toLowerCase().contains('token') || sanitized.toLowerCase().contains('bearer')) {
      sanitized = '[CREDENTIAL_DATA_REDACTED]';
    }
    return sanitized;
  }
}
