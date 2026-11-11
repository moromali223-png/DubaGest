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

  /// Clé publique par défaut du projet Supabase zqvfksqfjsdfrykokpsd.
  static const _defaultPublishableKey = 'sb_publishable_7K7N1LDRynPSG0Lm8v27cg_Uj7Ttq_a';
  static const _defaultSupabaseUrl = 'https://zqvfksqfjsdfrykokpsd.supabase.co';
  static const _localAppUrl = 'http://127.0.0.1:3000';
  static const _prodAppUrl = 'https://dubagest-app.pages.dev';

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_KEY');
    const appUrl = String.fromEnvironment('APP_URL');
    const redirect = String.fromEnvironment('AUTH_REDIRECT_URL');

    final effectiveAppUrl = appUrl.isNotEmpty
        ? appUrl
        : (kIsWeb
            ? (Uri.base.origin.isNotEmpty && !Uri.base.origin.startsWith('null')
                ? Uri.base.origin
                : _prodAppUrl)
            : (kReleaseMode ? _prodAppUrl : _localAppUrl));

    // Détermination de l'URL de retour OAuth :
    // - Sur Web/PWA : toujours privilégier l'origine courante du navigateur
    //   (ex: https://dubagest-app.pages.dev ou http://localhost:3000) afin que
    //   le code_verifier PKCE stocké dans le localStorage de cette origine soit
    //   retrouvé au retour de Google.
    // - Sur Android/iOS (APK/IPA) : toujours utiliser le schéma profond mobile
    //   (io.dubagest://auth-callback) et jamais une URL http(s) issue de prod.json.
    final String? effectiveRedirect;
    if (kIsWeb) {
      final hasValidBrowserOrigin = (Uri.base.scheme == 'http' || Uri.base.scheme == 'https') &&
          Uri.base.origin.isNotEmpty &&
          !Uri.base.origin.startsWith('null');
      if (hasValidBrowserOrigin) {
        effectiveRedirect = Uri.base.origin;
      } else if (redirect.isNotEmpty && !redirect.startsWith('io.dubagest://')) {
        effectiveRedirect = redirect;
      } else {
        effectiveRedirect = _prodAppUrl;
      }
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      effectiveRedirect = (redirect.isNotEmpty &&
              !redirect.startsWith('http://') &&
              !redirect.startsWith('https://'))
          ? redirect
          : mobileRedirect;
    } else {
      effectiveRedirect = redirect.isNotEmpty ? redirect : _defaultRedirect(effectiveAppUrl);
    }


    return AppConfig(
      supabaseUrl: url.isNotEmpty ? url : _defaultSupabaseUrl,
      supabaseKey: key.isNotEmpty ? key : _defaultPublishableKey,
      publicAppUrl: effectiveAppUrl,
      authRedirectUrl: effectiveRedirect,
    );
  }

  static String? _defaultRedirect([String? fallbackUrl]) {
    if (kIsWeb) return Uri.base.origin;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => mobileRedirect,
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux =>
        fallbackUrl ?? _localAppUrl,
      _ => null,
    };
  }

  String invitationLink(String token) =>
      Uri.parse(publicAppUrl).replace(path: '/join-company', queryParameters: {'token': token}).toString();
}
