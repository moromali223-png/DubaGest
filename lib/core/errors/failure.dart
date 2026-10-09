/// Catégorie d'erreur exploitable par l'interface. Les détails techniques
/// restent dans [Failure.cause] pour les logs, jamais affichés tels quels.
enum FailureKind {
  network,
  invalidCredentials,
  emailNotConfirmed,
  accountExists,
  weakPassword,

  /// Connexion via un fournisseur externe (Google) annulée ou indisponible.
  oauthUnavailable,
  rateLimited,
  sessionExpired,
  forbidden,
  notFound,
  conflict,
  duplicate,

  /// Règle métier refusée (limite d'abonnement, dernier administrateur…).
  /// Le code stable est dans [Failure.ruleCode], identique côté serveur.
  businessRule,
  server,
  localStorage,
  unknown,
}

class Failure implements Exception {
  const Failure(
    this.kind, {
    this.ruleCode,
    this.params = const {},
    this.cause,
    this.stackTrace,
  });

  const Failure.rule(String code, [Map<String, Object?> params = const {}])
      : this(FailureKind.businessRule, ruleCode: code, params: params);

  final FailureKind kind;
  final String? ruleCode;
  final Map<String, Object?> params;
  final Object? cause;
  final StackTrace? stackTrace;

  /// Une nouvelle tentative a-t-elle une chance d'aboutir ?
  bool get isTransient =>
      kind == FailureKind.network || kind == FailureKind.server || kind == FailureKind.rateLimited;

  @override
  String toString() =>
      'Failure($kind${ruleCode != null ? ', $ruleCode' : ''}${params.isNotEmpty ? ', $params' : ''})'
      '${cause != null ? ' cause: $cause' : ''}';
}
