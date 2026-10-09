import 'package:dubagest/features/agenda/domain/entities/agenda.dart';
import 'package:dubagest/features/agenda/presentation/pages/agenda_page.dart';
import 'package:dubagest/features/agenda/presentation/pages/notifications_page.dart';
import 'package:dubagest/features/agenda/presentation/providers/agenda_providers.dart';
import 'package:dubagest/features/entreprise/presentation/providers/contexte_providers.dart';
import 'package:dubagest/features/finances/domain/services/etat_finances.dart';
import 'package:dubagest/features/finances/presentation/providers/finances_providers.dart';
import 'package:dubagest/features/finances/presentation/widgets/finances_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contexte_fixtures.dart';
import '../helpers/pump_app.dart';

final _maintenant = DateTime.now();

List<Echeance> _echeances() => [
      Echeance(id: 'retard', entrepriseId: entrepriseId, type: TypeEcheance.relance, titre: 'Relancer Amadou',
          dateHeure: _maintenant.subtract(const Duration(days: 2)), createdBy: userId),
      Echeance(id: 'confiee', entrepriseId: entrepriseId, type: TypeEcheance.tache, titre: 'Inventaire',
          dateHeure: _maintenant.add(const Duration(days: 2)), responsableId: userId, responsableNom: 'Awa Diallo',
          createdBy: 'u-chef'),
    ];

List<Object> _overrides({String role = 'ADMINISTRATEUR', List<NotificationApp> notifications = const []}) => [
      contexteActifProvider.overrideWithValue(contexte(role: role)),
      echeancesProvider.overrideWith((ref) => Stream.value(_echeances())),
      notificationsProvider.overrideWith((ref) => Stream.value(notifications)),
      etatFinancesProvider.overrideWith((ref) => Stream.value(EtatFinances())),
      contactsParIdProvider.overrideWith((ref) => Stream.value(const {})),
    ];

void main() {
  testWidgets('agenda : sections par période, bouton d\'ajout pour qui gère l\'agenda', (tester) async {
    await pumpApp(tester, const AgendaPage(), overrides: _overrides().cast(), size: const Size(420, 1200));
    expect(find.text('En retard · 1'), findsOneWidget);
    expect(find.text('7 prochains jours · 1'), findsOneWidget);
    expect(find.text('Relancer Amadou'), findsOneWidget);
    expect(find.textContaining('Confié à Awa Diallo'), findsOneWidget);
    expect(find.byKey(const Key('echeance-add')), findsOneWidget);
  });

  testWidgets('vendeur : pas d\'ajout, mais coche la tâche qui lui est confiée', (tester) async {
    await pumpApp(tester, const AgendaPage(), overrides: _overrides(role: 'VENDEUR').cast(), size: const Size(420, 1200));
    expect(find.byKey(const Key('echeance-add')), findsNothing);
    expect(find.byKey(const Key('echeance-fait-confiee')), findsOneWidget);
    expect(find.byKey(const Key('echeance-fait-retard')), findsNothing);
  });

  testWidgets('cloche : compteur = notifications non lues + alertes', (tester) async {
    final notif = NotificationApp(
      id: 'n1', type: TypeNotification.echeanceConfiee, parametres: const {'titre': 'Inventaire'},
      createdAt: _maintenant, auteurNom: 'Moussa Traoré',
    );
    await pumpApp(
      tester,
      const Scaffold(body: Center(child: ClocheNotifications())),
      overrides: _overrides(notifications: [notif]).cast(),
    );
    // 1 non lue + 1 échéance en retard créée par l'utilisateur.
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('centre de notifications : à traiter, puis messages traduits', (tester) async {
    final notif = NotificationApp(
      id: 'n1', type: TypeNotification.echeanceConfiee, parametres: const {'titre': 'Inventaire'},
      createdAt: _maintenant, auteurNom: 'Moussa Traoré',
    );
    await pumpApp(tester, const NotificationsPage(),
        overrides: _overrides(notifications: [notif]).cast(), size: const Size(420, 1200));
    expect(find.text('À traiter'), findsOneWidget);
    expect(find.text('Relancer Amadou'), findsOneWidget);
    expect(find.text('Moussa Traoré vous a confié une tâche'), findsOneWidget);
    expect(find.byKey(const Key('notifications-tout-lu')), findsOneWidget);
  });
}
