import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';
import 'failure.dart';

/// Traduit toute erreur technique (Supabase, réseau, base locale) en [Failure].
/// Seul point du code qui connaît les formats d'erreur des dépendances.
class ErrorMapper {
  const ErrorMapper._();

  /// SQLSTATE des refus métier levés par `app.refuser()` côté PostgreSQL.
  static const businessRuleSqlState = 'DGL01';

  static Failure map(Object error, [StackTrace? stackTrace]) {
    if (error is Failure) return error;
    final failure = _map(error, stackTrace);
    AppLogger.warning('Erreur ${failure.kind}', tag: 'error', error: error);
    return failure;
  }

  static Failure _map(Object error, StackTrace? stackTrace) {
    if (error is AuthException) return _mapAuth(error, stackTrace);
    if (error is PostgrestException) return _mapPostgrest(error, stackTrace);
    if (error is TimeoutException || _isNetworkError(error)) {
      return Failure(FailureKind.network, cause: error, stackTrace: stackTrace);
    }
    return Failure(FailureKind.unknown, cause: error, stackTrace: stackTrace);
  }

  static Failure _mapAuth(AuthException e, StackTrace? st) {
    if (e is AuthRetryableFetchException) {
      return Failure(FailureKind.network, cause: e, stackTrace: st);
    }
    final kind = switch (e.code) {
      'invalid_credentials' => FailureKind.invalidCredentials,
      'email_not_confirmed' => FailureKind.emailNotConfirmed,
      'user_already_exists' || 'email_exists' => FailureKind.accountExists,
      'weak_password' => FailureKind.weakPassword,
      'provider_disabled' => FailureKind.oauthUnavailable,
      'over_request_rate_limit' || 'over_email_send_rate_limit' => FailureKind.rateLimited,
      'session_expired' || 'session_not_found' || 'refresh_token_not_found' =>
        FailureKind.sessionExpired,
      _ => switch (e.statusCode) {
          '400' when e.message.toLowerCase().contains('invalid login') =>
            FailureKind.invalidCredentials,
          '401' || '403' => FailureKind.sessionExpired,
          '429' => FailureKind.rateLimited,
          final s? when s.startsWith('5') => FailureKind.server,
          _ => FailureKind.unknown,
        },
    };
    return Failure(kind, cause: e, stackTrace: st);
  }

  static Failure _mapPostgrest(PostgrestException e, StackTrace? st) {
    if (e.code == businessRuleSqlState) {
      return Failure(
        FailureKind.businessRule,
        ruleCode: e.message,
        params: _decodeDetails(e.details),
        cause: e,
        stackTrace: st,
      );
    }
    final kind = switch (e.code) {
      '42501' => FailureKind.forbidden,
      '23505' => FailureKind.duplicate,
      'PGRST116' => FailureKind.notFound,
      'PGRST301' || 'PGRST303' => FailureKind.sessionExpired,
      final c? when c.startsWith('08') || c.startsWith('57') || c.startsWith('53') =>
        FailureKind.server,
      _ => FailureKind.unknown,
    };
    return Failure(kind, cause: e, stackTrace: st);
  }

  static Map<String, Object?> _decodeDetails(Object? details) {
    if (details is Map) return details.cast<String, Object?>();
    if (details is String && details.isNotEmpty) {
      try {
        final decoded = jsonDecode(details);
        if (decoded is Map) return decoded.cast<String, Object?>();
      } on FormatException {
        return const {};
      }
    }
    return const {};
  }

  /// Détection par nom de type ou message : `dart:io` (SocketException) n'existe pas sur
  /// le web, et `ClientException` vient d'un paquet transitif.
  static bool _isNetworkError(Object error) {
    if (error is TimeoutException) return true;
    final type = error.runtimeType.toString();
    final str = error.toString().toLowerCase();
    return type.contains('SocketException') ||
        type.contains('ClientException') ||
        type.contains('HandshakeException') ||
        type.contains('HttpException') ||
        type.contains('TimeoutException') ||
        str.contains('socketexception') ||
        str.contains('clientexception') ||
        str.contains('timeoutexception') ||
        str.contains('failed host lookup') ||
        str.contains('network is unreachable') ||
        str.contains('connection refused') ||
        str.contains('connection reset') ||
        str.contains('connection timed out') ||
        str.contains('software caused connection abort') ||
        str.contains('os error:') ||
        str.contains('errno =');
  }
}
