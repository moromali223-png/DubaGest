import '../../../core/utils/recherche.dart';
import '../../agenda/domain/entities/agenda.dart';
import '../../contacts/domain/entities/contact.dart';
import '../../documents/domain/entities/document.dart';
import '../../finances/domain/entities/finances.dart';
import '../../finances/domain/services/etat_finances.dart';

sealed class Resultat {
  const Resultat();
}

class ResultatContact extends Resultat {
  const ResultatContact(this.contact);
  final Contact contact;
}

class ResultatSommeDue extends Resultat {
  const ResultatSommeDue(this.suivi, this.contact);
  final EngagementSuivi suivi;
  final Contact? contact;
}

class ResultatPaiement extends Resultat {
  const ResultatPaiement(this.paiement, this.contact, {required this.annule});
  final Paiement paiement;
  final Contact? contact;
  final bool annule;
}

class ResultatDepense extends Resultat {
  const ResultatDepense(this.depense);
  final Depense depense;
}

class ResultatDocument extends Resultat {
  const ResultatDocument(this.document);
  final Document document;
}

class ResultatEcheance extends Resultat {
  const ResultatEcheance(this.echeance);
  final Echeance echeance;
}

/// Résultats regroupés par type, dans l'ordre d'affichage.
class ResultatsRecherche {
  const ResultatsRecherche({
    this.contacts = const [],
    this.sommesDues = const [],
    this.paiements = const [],
    this.depenses = const [],
    this.documents = const [],
    this.echeances = const [],
  });

  final List<ResultatContact> contacts;
  final List<ResultatSommeDue> sommesDues;
  final List<ResultatPaiement> paiements;
  final List<ResultatDepense> depenses;
  final List<ResultatDocument> documents;
  final List<ResultatEcheance> echeances;

  bool get vide =>
      contacts.isEmpty &&
      sommesDues.isEmpty &&
      paiements.isEmpty &&
      depenses.isEmpty &&
      documents.isEmpty &&
      echeances.isEmpty;
}

/// Recherche dans les données de l'appareil (déjà filtrées par la RLS et
/// disponibles hors-ligne). Insensible aux accents et aux variantes de
/// l'arabe ; un nombre trouve aussi un téléphone, un montant ou un numéro.
/// Chaque source n'est fournie que si l'utilisateur a le droit de la voir.
abstract final class RechercheGlobale {
  static const parType = 5;

  static ResultatsRecherche chercher(
    String texte, {
    List<Contact> contacts = const [],
    EtatFinances? finances,
    bool sommesDues = false,
    bool paiements = false,
    bool depenses = false,
    List<Document> documents = const [],
    List<Echeance> echeances = const [],
  }) {
    final mots = normaliserRecherche(texte).split(' ').where((m) => m.isNotEmpty).toList();
    if (mots.isEmpty) return const ResultatsRecherche();
    final chiffres = chiffresSeuls(texte);
    final montant = RegExp(r'^[\d\s.,]+$').hasMatch(texte.trim()) ? int.tryParse(chiffres) : null;

    bool correspond(Iterable<String?> champs) {
      final cle = normaliserRecherche(champs.whereType<String>().join(' '));
      return mots.every(cle.contains);
    }

    bool telephone(Contact? c) =>
        c != null && chiffres.length >= 3 && chiffresSeuls('${c.telephone ?? ''} ${c.whatsapp ?? ''}').contains(chiffres);

    final parId = {for (final c in contacts) c.id: c};
    List<T> limiter<T>(Iterable<T> source) => source.take(parType).toList();

    return ResultatsRecherche(
      contacts: limiter([
        for (final c in contacts)
          if (correspond([c.prenom, c.nom, c.email, c.ville]) || telephone(c)) ResultatContact(c),
      ]),
      sommesDues: finances == null || !sommesDues
          ? const []
          : limiter([
              for (final s in finances.suivis)
                if (!s.engagement.refuse &&
                    (correspond([s.engagement.libelle, parId[s.engagement.contactId]?.nomAffiche]) ||
                        telephone(parId[s.engagement.contactId]) ||
                        s.engagement.montantTotal == montant))
                  ResultatSommeDue(s, parId[s.engagement.contactId]),
            ]),
      paiements: finances == null || !paiements
          ? const []
          : limiter([
              for (final p in finances.paiements)
                if (!p.refuse &&
                    (correspond([p.reference, p.note, parId[p.contactId]?.nomAffiche]) || p.montant == montant))
                  ResultatPaiement(p, parId[p.contactId], annule: finances.estAnnule(p)),
            ]),
      depenses: finances == null || !depenses
          ? const []
          : limiter([
              for (final d in finances.depenses)
                if (correspond([d.libelle, d.reference, d.note]) || d.montant == montant) ResultatDepense(d),
            ]),
      documents: limiter([
        for (final d in documents)
          if (correspond([d.numero, (d.contenu['contact'] as Map?)?['nom'] as String?]) ||
              (chiffres.length >= 3 && chiffresSeuls(d.numero).endsWith(chiffres)) ||
              d.montant == montant)
            ResultatDocument(d),
      ]),
      echeances: limiter([
        for (final e in echeances)
          if (!e.refusee && correspond([e.titre, e.note, e.responsableNom])) ResultatEcheance(e),
      ]),
    );
  }
}
