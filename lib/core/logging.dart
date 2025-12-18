import 'dart:developer' as developer;

void logInfo(String message) => developer.log(message, name: 'app');

void logError(String message, [Object? error, StackTrace? stackTrace]) {
  developer.log(message, name: 'app', error: error, stackTrace: stackTrace);
}
