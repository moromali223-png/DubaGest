import 'package:flutter/foundation.dart';

/// Configuration d'environnement, injectée à la compilation :
///   flutter run --dart-define-from-file=config/local.json
/// Sans valeur, le Supabase Local de développement est utilisé (debug uniquement).
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseKey,
    required this.publicAppUrl,
    this.authRedirectUrl,
  });

  final String supabaseUrl;

  /// Clé publique (publishable / anon). Jamais la clé secrète / service_role.
  final String supabaseKey;

  /// Adresse publique de la PWA, utilisée dans les liens d'invitation partagés.
  final String publicAppUrl;

  /// Retour après Google, confirmation d'e-mail ou réinitialisation :
  /// l'origine web, ou le lien profond `io.dubagest://auth-callback` sur mobile.
  final String? authRedirectUrl;

  static const mobileRedirect = 'io.dubagest://auth-callback';

  /// Clé publique de démonstration fournie par `supabase start` (PUBLISHABLE_KEY).
  static const _localPublishableKey = 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';
  static const _localAppUrl = 'http://127.0.0.1:3000';

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_KEY');
    const appUrl = String.fromEnvironment('APP_URL');
    const redirect = String.fromEnvironment('AUTH_REDIRECT_URL');

    if (kReleaseMode && (url.isEmpty || key.isEmpty || appUrl.isEmpty)) {
      throw StateError('SUPABASE_URL, SUPABASE_KEY et APP_URL sont obligatoires en release.');
    }
    return AppConfig(
      supabaseUrl: url.isNotEmpty ? url : _localUrl(),
      supabaseKey: key.isNotEmpty ? key : _localPublishableKey,
      publicAppUrl: appUrl.isNotEmpty ? appUrl : (kIsWeb ? Uri.base.origin : _localAppUrl),
      authRedirectUrl: redirect.isNotEmpty ? redirect : _defaultRedirect(),
    );
  }

  static String? _defaultRedirect() {
    if (kIsWeb) return Uri.base.origin;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => mobileRedirect,
      // Desktop : pas de lien profond enregistré en V1 (URL du site par défaut).
      _ => null,
    };
  }

  /// L'émulateur Android joint la machine hôte via 10.0.2.2.
  static String _localUrl() => !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:54321'
      : 'http://127.0.0.1:54321';

  String invitationLink(String token) =>
      Uri.parse(publicAppUrl).replace(path: '/join-company', queryParameters: {'token': token}).toString();
}
