import 'dart:async';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/prestation.dart';
import '../../domain/entities/service_catalogue.dart';
import '../../domain/repositories/services_repository.dart';
import '../datasources/services_local_data_source.dart';
import '../datasources/services_remote_data_source.dart';
import '../models/services_mappers.dart';

class ServicesRepositoryImpl implements ServicesRepository {
  ServicesRepositoryImpl({
    required ServicesRemoteDataSource remote,
    ServicesLocalDataSource? local,
  })  : _remote = remote,
        _local = local;

  final ServicesRemoteDataSource _remote;
  final ServicesLocalDataSource? _local;

  // Streams locaux pour réactivité en temps réel
  final _catalogueControllers = <String, StreamController<List<ServiceCatalogue>>>{};
  final _prestationsControllers = <String, StreamController<List<Prestation>>>{};
  final _devisControllers = <String, StreamController<List<DevisPrestation>>>{};

  final _catalogueCache = <String, List<ServiceCatalogue>>{};
  final _prestationsCache = <String, List<Prestation>>{};
  final _devisCache = <String, List<DevisPrestation>>{};

  // --- CATALOGUE ---

  @override
  Stream<List<ServiceCatalogue>> observerCatalogue(String entrepriseId) async* {
    if (_catalogueCache.containsKey(entrepriseId)) {
      yield _catalogueCache[entrepriseId]!;
    } else if (_local != null) {
      try {
        final itemsLocaux = await _local.chargerCatalogue(entrepriseId);
        _catalogueCache[entrepriseId] = itemsLocaux;
        yield itemsLocaux;
      } catch (_) {}
    }

    _catalogueControllers[entrepriseId] ??= StreamController<List<ServiceCatalogue>>.broadcast();
    unawaited(_rafraichirCatalogue(entrepriseId));
    yield* _catalogueControllers[entrepriseId]!.stream;
  }

  Future<void> _rafraichirCatalogue(String entrepriseId) async {
    // 1. Charger depuis le cache local Drift si pas encore en mémoire
    if (!_catalogueCache.containsKey(entrepriseId) && _local != null) {
      try {
        final itemsLocaux = await _local.chargerCatalogue(entrepriseId);
        _catalogueCache[entrepriseId] = itemsLocaux;
        _catalogueControllers[entrepriseId]?.add(itemsLocaux);
      } catch (_) {
        _catalogueCache[entrepriseId] ??= [];
        _catalogueControllers[entrepriseId]?.add(_catalogueCache[entrepriseId]!);
      }
    }

    // 2. Synchroniser avec le serveur
    try {
      final remoteItems = await _remote.chargerCatalogue(entrepriseId);
      final currentLocal = _catalogueCache[entrepriseId] ?? [];
      final remoteIds = remoteItems.map((s) => s.id).toSet();
      // Conserver les services locaux qui ne sont pas encore sur le serveur distant
      final localOnly = currentLocal.where((s) => !remoteIds.contains(s.id)).toList();
      final merged = [...remoteItems, ...localOnly];

      _catalogueCache[entrepriseId] = merged;
      _catalogueControllers[entrepriseId]?.add(merged);
      await _local?.sauvegarderCatalogue(entrepriseId, merged);
    } catch (_) {
      // Offline fallback : on conserve le cache local actuel
      if (_catalogueCache.containsKey(entrepriseId)) {
        _catalogueControllers[entrepriseId]?.add(_catalogueCache[entrepriseId]!);
      }
    }
  }

  @override
  Future<ServiceCatalogue> sauvegarderService(ServiceCatalogue service) => _guard(() async {
        final list = List<ServiceCatalogue>.from(_catalogueCache[service.entrepriseId] ?? []);
        final index = list.indexWhere((s) => s.id == service.id);
        if (index >= 0) {
          list[index] = service;
        } else {
          list.add(service);
        }
        _catalogueCache[service.entrepriseId] = list;
        _catalogueControllers[service.entrepriseId]?.add(list);
        await _local?.sauvegarderCatalogue(service.entrepriseId, list);

        try {
          final res = await _remote.sauvegarderServiceCatalogue(service);
          return res;
        } catch (_) {
          // Enregistrer dans la file de synchronisation
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'services_catalogue',
            recordId: service.id,
            operation: 'UPSERT',
            payload: ServicesMappers.serviceToJson(service),
          );
          return service;
        }
      });

  @override
  Future<void> archiverService(String serviceId) => _guard(() async {
        for (final entry in _catalogueCache.entries) {
          final list = entry.value.where((s) => s.id != serviceId).toList();
          _catalogueCache[entry.key] = list;
          _catalogueControllers[entry.key]?.add(list);
          _local?.sauvegarderCatalogue(entry.key, list);
        }

        try {
          await _remote.archiverServiceCatalogue(serviceId);
        } catch (_) {
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'services_catalogue',
            recordId: serviceId,
            operation: 'ARCHIVE',
            payload: {'id': serviceId},
          );
        }
      });

  // --- PRESTATIONS ---

  @override
  Stream<List<Prestation>> observerPrestations(String entrepriseId, {String? perimetreId}) async* {
    final key = '$entrepriseId:${perimetreId ?? "all"}';
    if (_prestationsCache.containsKey(key)) {
      yield _prestationsCache[key]!;
    } else if (_local != null) {
      try {
        final locaux = await _local.chargerPrestations(entrepriseId, perimetreId: perimetreId);
        _prestationsCache[key] = locaux;
        yield locaux;
      } catch (_) {}
    }

    _prestationsControllers[key] ??= StreamController<List<Prestation>>.broadcast();
    unawaited(_rafraichirPrestations(entrepriseId, perimetreId: perimetreId));
    yield* _prestationsControllers[key]!.stream;
  }

  Future<void> _rafraichirPrestations(String entrepriseId, {String? perimetreId}) async {
    final key = '$entrepriseId:${perimetreId ?? "all"}';

    // 1. Lecture locale immédiate si pas en mémoire
    if (!_prestationsCache.containsKey(key) && _local != null) {
      try {
        final locaux = await _local.chargerPrestations(entrepriseId, perimetreId: perimetreId);
        _prestationsCache[key] = locaux;
        _prestationsControllers[key]?.add(locaux);
      } catch (_) {
        _prestationsCache[key] ??= [];
        _prestationsControllers[key]?.add(_prestationsCache[key]!);
      }
    }

    // 2. Synchroniser avec le serveur
    try {
      final remoteItems = await _remote.chargerPrestations(entrepriseId, perimetreId: perimetreId);
      final currentLocal = _prestationsCache[key] ?? [];
      final remoteIds = remoteItems.map((p) => p.id).toSet();
      // Conserver les prestations locales non encore présentes sur le serveur
      final localOnly = currentLocal.where((p) => !remoteIds.contains(p.id)).toList();
      final merged = [...remoteItems, ...localOnly];

      _prestationsCache[key] = merged;
      _prestationsControllers[key]?.add(merged);
      await _local?.sauvegarderPrestations(entrepriseId, merged, perimetreId: perimetreId);
    } catch (_) {
      // Offline fallback : on conserve le cache local actuel
      if (_prestationsCache.containsKey(key)) {
        _prestationsControllers[key]?.add(_prestationsCache[key]!);
      }
    }
  }

  @override
  Future<Prestation?> getPrestation(String id) async {
    for (final list in _prestationsCache.values) {
      final found = list.where((p) => p.id == id).firstOrNull;
      if (found != null) return found;
    }
    try {
      return await _remote.getPrestation(id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Prestation> creerPrestation(Prestation prestation) => _guard(() async {
        final key = '${prestation.entrepriseId}:${prestation.perimetreId ?? "all"}';
        final allKey = '${prestation.entrepriseId}:all';

        void insererDansCache(String k, String? perimetre) {
          final list = List<Prestation>.from(_prestationsCache[k] ?? []);
          list.removeWhere((p) => p.id == prestation.id);
          list.insert(0, prestation);
          _prestationsCache[k] = list;
          _prestationsControllers[k]?.add(list);
          _local?.sauvegarderPrestations(prestation.entrepriseId, list, perimetreId: perimetre);
        }

        insererDansCache(key, prestation.perimetreId);
        if (key != allKey) {
          insererDansCache(allKey, null);
        }

        try {
          final res = await _remote.creerPrestation(prestation);
          return res;
        } catch (_) {
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'prestations',
            recordId: prestation.id,
            operation: 'INSERT',
            payload: ServicesMappers.prestationToJson(prestation),
          );
          return prestation;
        }
      });

  @override
  Future<Prestation> modifierPrestation(Prestation prestation) => _guard(() async {
        final key = '${prestation.entrepriseId}:${prestation.perimetreId ?? "all"}';
        final allKey = '${prestation.entrepriseId}:all';

        void mettreAJourCache(String k, String? perimetre) {
          final list = List<Prestation>.from(_prestationsCache[k] ?? []);
          final index = list.indexWhere((p) => p.id == prestation.id);
          if (index >= 0) {
            list[index] = prestation;
          } else {
            list.insert(0, prestation);
          }
          _prestationsCache[k] = list;
          _prestationsControllers[k]?.add(list);
          _local?.sauvegarderPrestations(prestation.entrepriseId, list, perimetreId: perimetre);
        }

        mettreAJourCache(key, prestation.perimetreId);
        if (key != allKey) {
          mettreAJourCache(allKey, null);
        }

        try {
          final res = await _remote.modifierPrestation(prestation);
          return res;
        } catch (_) {
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'prestations',
            recordId: prestation.id,
            operation: 'UPDATE',
            payload: ServicesMappers.prestationToJson(prestation),
          );
          return prestation;
        }
      });

  @override
  Future<void> changerStatutPrestation(String prestationId, StatutPrestation nouveauStatut, {String? motif}) => _guard(() async {
        _mettreAJourStatutLocal(prestationId, nouveauStatut);
        try {
          await _remote.changerStatutPrestation(prestationId, nouveauStatut, motif: motif);
        } catch (_) {
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'prestations',
            recordId: prestationId,
            operation: 'STATUS_CHANGE',
            payload: {'id': prestationId, 'nouveau_statut': nouveauStatut.code, if (motif != null) 'motif': motif},
          );
        }
      });

  void _mettreAJourStatutLocal(String prestationId, StatutPrestation statut) {
    for (final entry in _prestationsCache.entries) {
      final list = List<Prestation>.from(entry.value);
      final index = list.indexWhere((p) => p.id == prestationId);
      if (index >= 0) {
        list[index] = list[index].copyWith(statut: statut);
        _prestationsCache[entry.key] = list;
        _prestationsControllers[entry.key]?.add(list);
      }
    }
  }

  @override
  Future<void> reporterPrestation(
    String prestationId,
    DateTime nouvelleEcheanceJour,
    String? nouvelleEcheanceHeure,
    String motif,
  ) =>
      _guard(() async {
        for (final entry in _prestationsCache.entries) {
          final list = List<Prestation>.from(entry.value);
          final index = list.indexWhere((p) => p.id == prestationId);
          if (index >= 0) {
            list[index] = list[index].copyWith(
              echeanceJour: nouvelleEcheanceJour,
              echeanceHeure: nouvelleEcheanceHeure,
            );
            _prestationsCache[entry.key] = list;
            _prestationsControllers[entry.key]?.add(list);
          }
        }

        try {
          await _remote.reporterPrestation(prestationId, nouvelleEcheanceJour, nouvelleEcheanceHeure, motif);
        } catch (_) {
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'prestations',
            recordId: prestationId,
            operation: 'REPORT',
            payload: {
              'id': prestationId,
              'echeance_jour': nouvelleEcheanceJour.toIso8601String(),
              'echeance_heure': nouvelleEcheanceHeure,
              'motif': motif,
            },
          );
        }
      });

  @override
  Future<void> annulerPrestation(String prestationId, String motif) => _guard(() async {
        changerStatutPrestation(prestationId, StatutPrestation.annulee);
        try {
          await _remote.annulerPrestation(prestationId, motif);
        } catch (_) {
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'prestations',
            recordId: prestationId,
            operation: 'CANCEL',
            payload: {'id': prestationId, 'motif': motif},
          );
        }
      });

  @override
  Stream<List<PrestationHistorique>> observerHistorique(String prestationId) {
    return _remote.observerHistorique(prestationId);
  }

  // --- DEVIS ---

  @override
  Stream<List<DevisPrestation>> observerDevis(String entrepriseId, {String? perimetreId}) async* {
    final key = '$entrepriseId:${perimetreId ?? "all"}';
    if (_devisCache.containsKey(key)) {
      yield _devisCache[key]!;
    } else if (_local != null) {
      try {
        final locaux = await _local.chargerDevis(entrepriseId, perimetreId: perimetreId);
        _devisCache[key] = locaux;
        yield locaux;
      } catch (_) {}
    }

    _devisControllers[key] ??= StreamController<List<DevisPrestation>>.broadcast();
    unawaited(_rafraichirDevis(entrepriseId, perimetreId: perimetreId));
    yield* _devisControllers[key]!.stream;
  }

  Future<void> _rafraichirDevis(String entrepriseId, {String? perimetreId}) async {
    final key = '$entrepriseId:${perimetreId ?? "all"}';

    // 1. Lecture locale immédiate si pas en mémoire
    if (!_devisCache.containsKey(key) && _local != null) {
      try {
        final locaux = await _local.chargerDevis(entrepriseId, perimetreId: perimetreId);
        _devisCache[key] = locaux;
        _devisControllers[key]?.add(locaux);
      } catch (_) {
        _devisCache[key] ??= [];
        _devisControllers[key]?.add(_devisCache[key]!);
      }
    }

    // 2. Synchroniser avec le serveur
    try {
      final remoteItems = await _remote.chargerDevis(entrepriseId, perimetreId: perimetreId);
      final currentLocal = _devisCache[key] ?? [];
      final remoteIds = remoteItems.map((d) => d.id).toSet();
      final localOnly = currentLocal.where((d) => !remoteIds.contains(d.id)).toList();
      final merged = [...remoteItems, ...localOnly];

      _devisCache[key] = merged;
      _devisControllers[key]?.add(merged);
      await _local?.sauvegarderDevis(entrepriseId, merged, perimetreId: perimetreId);
    } catch (_) {
      // Offline fallback : on conserve le cache local actuel
      if (_devisCache.containsKey(key)) {
        _devisControllers[key]?.add(_devisCache[key]!);
      }
    }
  }

  @override
  Future<DevisPrestation> creerDevis(DevisPrestation devis) => _guard(() async {
        final key = '${devis.entrepriseId}:${devis.perimetreId ?? "all"}';
        final allKey = '${devis.entrepriseId}:all';

        void insererDansCache(String k, String? perimetre) {
          final list = List<DevisPrestation>.from(_devisCache[k] ?? []);
          list.removeWhere((d) => d.id == devis.id);
          list.insert(0, devis);
          _devisCache[k] = list;
          _devisControllers[k]?.add(list);
          _local?.sauvegarderDevis(devis.entrepriseId, list, perimetreId: perimetre);
        }

        insererDansCache(key, devis.perimetreId);
        if (key != allKey) {
          insererDansCache(allKey, null);
        }

        try {
          final res = await _remote.creerDevis(devis);
          return res;
        } catch (_) {
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'devis_prestations',
            recordId: devis.id,
            operation: 'INSERT',
            payload: ServicesMappers.devisToJson(devis),
          );
          return devis;
        }
      });

  @override
  Future<DevisPrestation> modifierDevis(DevisPrestation devis) => _guard(() async {
        final key = '${devis.entrepriseId}:${devis.perimetreId ?? "all"}';
        final allKey = '${devis.entrepriseId}:all';

        void mettreAJourCache(String k, String? perimetre) {
          final list = List<DevisPrestation>.from(_devisCache[k] ?? []);
          final index = list.indexWhere((d) => d.id == devis.id);
          if (index >= 0) {
            list[index] = devis;
          } else {
            list.insert(0, devis);
          }
          _devisCache[k] = list;
          _devisControllers[k]?.add(list);
          _local?.sauvegarderDevis(devis.entrepriseId, list, perimetreId: perimetre);
        }

        mettreAJourCache(key, devis.perimetreId);
        if (key != allKey) {
          mettreAJourCache(allKey, null);
        }

        try {
          final res = await _remote.modifierDevis(devis);
          return res;
        } catch (_) {
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'devis_prestations',
            recordId: devis.id,
            operation: 'UPDATE',
            payload: ServicesMappers.devisToJson(devis),
          );
          return devis;
        }
      });

  @override
  Future<void> changerStatutDevis(String devisId, StatutDevis nouveauStatut) => _guard(() async {
        for (final entry in _devisCache.entries) {
          final list = List<DevisPrestation>.from(entry.value);
          final index = list.indexWhere((d) => d.id == devisId);
          if (index >= 0) {
            list[index] = list[index].copyWith(statut: nouveauStatut);
            _devisCache[entry.key] = list;
            _devisControllers[entry.key]?.add(list);
          }
        }
        try {
          await _remote.changerStatutDevis(devisId, nouveauStatut);
        } catch (_) {
          await _local?.empilerOperationSync(
            operationId: const Uuid().v4(),
            userId: 'local',
            entityTable: 'devis_prestations',
            recordId: devisId,
            operation: 'STATUS_CHANGE',
            payload: {'id': devisId, 'nouveau_statut': nouveauStatut.code},
          );
        }
      });

  @override
  Future<Prestation> convertirDevisEnPrestation(String devisId) => _guard(() async {
        DevisPrestation? devis;
        for (final list in _devisCache.values) {
          final found = list.where((d) => d.id == devisId).firstOrNull;
          if (found != null) {
            devis = found;
            break;
          }
        }

        if (devis == null) {
          throw StateError('Devis introuvable');
        }

        final prestation = Prestation(
          id: const Uuid().v4(),
          entrepriseId: devis.entrepriseId,
          perimetreId: devis.perimetreId,
          contactId: devis.contactId,
          titre: devis.titre,
          description: devis.description,
          lignes: devis.lignes,
          remise: devis.remise,
          total: devis.total,
          statut: StatutPrestation.aFaire,
          priorite: PrioritePrestation.normale,
          note: 'Créée automatiquement depuis le devis N° ${devis.numero}',
        );

        await creerPrestation(prestation);
        await changerStatutDevis(devisId, StatutDevis.accepte);

        return prestation;
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }
}
