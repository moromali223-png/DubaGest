import '../entities/agenda.dart';

/// Agenda et notifications : écriture locale (hors-ligne) puis synchronisation.
abstract interface class AgendaRepository {
  Stream<List<Echeance>> watchEcheances(String entrepriseId);
  Stream<List<NotificationApp>> watchNotifications(String entrepriseId, String userId);
  Future<void> creer(Echeance echeance);
  Future<void> modifier(Echeance avant, Echeance apres);
  Future<void> marquerLue(NotificationApp notification);
  Future<void> retirerRefusee(String id);
}
