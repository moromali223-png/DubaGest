import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Journalisation centralisée. Point unique à brancher plus tard sur un
/// service de télémétrie (Sentry, Crashlytics…).
class AppLogger {
  const AppLogger._();

  static void debug(String message, {String tag = 'app'}) {
    if (kDebugMode) developer.log(message, name: tag, level: 500);
  }

  static void info(String message, {String tag = 'app'}) =>
      developer.log(message, name: tag, level: 800);

  static void warning(String message, {String tag = 'app', Object? error}) =>
      developer.log(message, name: tag, level: 900, error: error);

  static void error(String message, {String tag = 'app', Object? error, StackTrace? stackTrace}) =>
      developer.log(message, name: tag, level: 1000, error: error, stackTrace: stackTrace);
}
