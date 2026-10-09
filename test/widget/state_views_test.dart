import 'package:dubagest/core/errors/failure.dart';
import 'package:dubagest/shared/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  Widget view(AsyncValue<List<int>> value, {VoidCallback? onRetry}) => Scaffold(
        body: AsyncValueView<List<int>>(
          value: value,
          isEmpty: (l) => l.isEmpty,
          emptyMessage: 'Vide',
          onRetry: onRetry,
          data: (l) => Text('${l.length} éléments'),
        ),
      );

  testWidgets('loading', (tester) async {
    await pumpApp(tester, view(const AsyncLoading()), settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('empty', (tester) async {
    await pumpApp(tester, view(const AsyncData([])));
    expect(find.text('Vide'), findsOneWidget);
  });

  testWidgets('data', (tester) async {
    await pumpApp(tester, view(const AsyncData([1, 2])));
    expect(find.text('2 éléments'), findsOneWidget);
  });

  testWidgets('error : message traduit + réessai', (tester) async {
    var retried = false;
    await pumpApp(
      tester,
      view(AsyncError(const Failure(FailureKind.network), StackTrace.empty), onRetry: () => retried = true),
    );
    expect(find.text('Connexion impossible. Vérifiez votre réseau.'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    expect(retried, isTrue);
  });
}
