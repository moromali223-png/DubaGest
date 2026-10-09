import '../entities/contact.dart';

/// Contacts : écriture locale d'abord (fonctionne hors-ligne), puis
/// synchronisation ; la sécurité réelle est assurée par la RLS.
abstract interface class ContactRepository {
  Stream<List<Contact>> watch(String entrepriseId, FiltreContacts filtre);
  Stream<Contact?> watchUn(String id);

  /// Fiches existantes ressemblant à un nouveau contact (même téléphone, ou
  /// même nom et prénom) — pour éviter de créer deux fois la même personne.
  Future<List<Contact>> doublonsPotentiels(String entrepriseId,
      {String? telephone, required String nom, String? prenom, String? saufId});

  Future<Contact> creer(Contact contact);
  Future<void> modifier(Contact avant, Contact apres);
}
