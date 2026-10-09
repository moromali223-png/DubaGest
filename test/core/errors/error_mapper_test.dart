import 'dart:async';

import 'package:dubagest/core/errors/error_mapper.dart';
import 'package:dubagest/core/errors/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('refus métier PostgreSQL → règle + paramètres exploitables', () {
    final f = ErrorMapper.map(const PostgrestException(
      message: 'LIMITE_PERIMETRES',
      code: 'DGL01',
      details: '{"plan": "MOYEN", "activite": "COMMERCE", "max": 2}',
    ));
    expect(f.kind, FailureKind.businessRule);
    expect(f.ruleCode, 'LIMITE_PERIMETRES');
    expect(f.params, {'plan': 'MOYEN', 'activite': 'COMMERCE', 'max': 2});
  });

  test('RLS / privilèges → interdit ; unicité → doublon', () {
    expect(ErrorMapper.map(const PostgrestException(message: 'permission denied', code: '42501')).kind,
        FailureKind.forbidden);
    expect(ErrorMapper.map(const PostgrestException(message: 'dup', code: '23505')).kind,
        FailureKind.duplicate);
  });

  test('identifiants invalides', () {
    final f = ErrorMapper.map(const AuthException('Invalid login credentials',
        statusCode: '400', code: 'invalid_credentials'));
    expect(f.kind, FailureKind.invalidCredentials);
  });

  test('réseau / délai dépassé → transitoire', () {
    final f = ErrorMapper.map(TimeoutException('lent'));
    expect(f.kind, FailureKind.network);
    expect(f.isTransient, isTrue);
  });

  test('le détail technique est conservé pour le diagnostic', () {
    const cause = PostgrestException(message: 'SQL constraint xyz', code: '23514');
    final f = ErrorMapper.map(cause);
    expect(f.kind, FailureKind.unknown);
    expect(f.cause, same(cause));
  });
}
