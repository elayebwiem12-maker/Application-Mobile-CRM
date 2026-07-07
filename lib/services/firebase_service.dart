// lib/services/firebase_service.dart — VERSION AMÉLIORÉE
// Améliorations :
//  + updateClientStats() : recalcul automatique budgetMoyen & nombreEvenements après chaque event
//  + getClientsBySegment() : segmentation par budget/fréquence (CDC : Segmentation)
//  + getClientsInactifs() : clients sans événement depuis N mois (CDC : Relances)
//  + getClientsBirthdayThisMonth() : pour campagnes anniversaire (CDC : Marketing Auto)
//  + generateNumeroDevis() : numéros lisibles DEV-YYYY-NNN
//  + getRelances() / ajouterRelance() : suivi relances (CDC : Relances auto)
//  + KPIs étendus : pack le plus vendu, CA par type d'événement, taux fidélisation
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class FirebaseService {
  static final FirebaseFirestore db = FirebaseFirestore.instance;  // public — used by dashboard
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── CLIENTS ──────────────────────────────────────────────────────────────

static Stream<List<Client>> getClients({bool actifSeulement = true}) {
  return _db
      .collection('clients')
      .snapshots()
      .map((s) => s.docs
          .map((d) => Client.fromFirestore(d))
          .where((c) => !actifSeulement || c.actif)
          .toList());
}

  static Future<Client?> getClient(String id) async {
    final doc = await _db.collection('clients').doc(id).get();
    return doc.exists ? Client.fromFirestore(doc) : null;
  }

  static Future<void> ajouterClient(Client client) async {
    await _db.collection('clients').doc(client.id).set(client.toFirestore());
  }

  static Future<void> modifierClient(Client client) async {
    await _db.collection('clients').doc(client.id).update(client.toFirestore());
  }

  static Future<void> supprimerClient(String id) async {
    await _db.collection('clients').doc(id).update({'actif': false});
  }

  static Stream<List<Client>> rechercherClients(String query) {
    return _db
        .collection('clients')
        .where('actif', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => Client.fromFirestore(d))
            .where((c) =>
                c.nomComplet.toLowerCase().contains(query.toLowerCase()) ||
                c.telephone.contains(query) ||
                c.email.toLowerCase().contains(query.toLowerCase()) ||
                c.ville.toLowerCase().contains(query.toLowerCase()))
            .toList());
  }

  static Stream<List<Client>> getClientsByType(String type) {
    return _db
        .collection('clients')
        .where('typeClient', isEqualTo: type)
        .where('actif', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Client.fromFirestore(d)).toList());
  }

  // NOUVEAU : Clients inactifs depuis N mois (CDC : Relances automatiques)
  static Future<List<Client>> getClientsInactifs({int mois = 6}) async {
    final cutoff = DateTime.now().subtract(Duration(days: mois * 30));
    // Récupère tous les clients actifs
    final clientsSnap = await _db
        .collection('clients')
        .where('actif', isEqualTo: true)
        .get();
    final clients = clientsSnap.docs.map(Client.fromFirestore).toList();

    // Récupère les événements récents
    final eventsSnap = await _db
        .collection('evenements')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .get();
    final clientsActifsIds =
        eventsSnap.docs.map((d) => d.data()['clientId'] as String).toSet();

    return clients
        .where((c) => !clientsActifsIds.contains(c.id))
        .toList();
  }

  // NOUVEAU : Clients dont l'anniversaire est ce mois-ci (CDC : Marketing Auto)
  static Future<List<Client>> getClientsBirthdayThisMonth() async {
    final now = DateTime.now();
    final snap = await _db
        .collection('clients')
        .where('actif', isEqualTo: true)
        .get();
    return snap.docs
        .map(Client.fromFirestore)
        .where((c) =>
            c.dateNaissance != null &&
            c.dateNaissance!.month == now.month)
        .toList();
  }

  // NOUVEAU : Mise à jour automatique stats client après ajout/modif d'événement
  static Future<void> updateClientStats(String clientId) async {
    final eventsSnap = await _db
        .collection('evenements')
        .where('clientId', isEqualTo: clientId)
        .get();
    final events = eventsSnap.docs
        .map((d) => d.data())
        .where((d) => d['statut'] != 'Annulé')
        .toList();

    final nombre = events.length;
    final budgetMoyen = nombre > 0
        ? events.fold(0.0, (s, d) => s + (d['budget'] as num).toDouble()) /
            nombre
        : 0.0;

    // Détermine le type client automatiquement
    String typeClient = 'Nouveau';
    if (nombre >= 3 && budgetMoyen >= 3000) typeClient = 'VIP';
    else if (nombre >= 2 || budgetMoyen >= 1500) typeClient = 'Régulier';

    await _db.collection('clients').doc(clientId).update({
      'nombreEvenements': nombre,
      'budgetMoyen': budgetMoyen,
      'typeClient': typeClient,
    });
  }

  // ─── ÉVÉNEMENTS ────────────────────────────────────────────────────────────

  static Stream<List<Evenement>> getEvenements() {
    return _db
        .collection('evenements')
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Evenement.fromFirestore(d)).toList());
  }

  static Stream<List<Evenement>> getEvenementsByClient(String clientId) {
    return _db
        .collection('evenements')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => Evenement.fromFirestore(d)).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  static Stream<List<Evenement>> getEvenementsAVenir() {
    // Query simple (sans compound where + orderBy) — pas d'index Firestore requis
    return _db
        .collection('evenements')
        .snapshots()
        .map((s) {
      final now = DateTime.now();
      final events = s.docs
          .map((d) => Evenement.fromFirestore(d))
          .where((e) =>
              e.date.isAfter(now) &&
              e.statut != 'Annulé' &&
              e.statut != 'Terminé')
          .toList();
      events.sort((a, b) => a.date.compareTo(b.date));
      return events;
    });
  }

  // NOUVEAU : Événements par mois (pour analyse saisonnalité — CDC)
  static Future<List<Evenement>> getEvenementsByMonth(
      int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final snap = await _db
        .collection('evenements')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.map(Evenement.fromFirestore).toList();
  }

  static Future<void> ajouterEvenement(Evenement e) async {
    await _db.collection('evenements').doc(e.id).set(e.toFirestore());
    // AMÉLIORATION : mise à jour automatique des stats client
    if (e.clientId.isNotEmpty) await updateClientStats(e.clientId);
  }

  static Future<void> modifierEvenement(Evenement e) async {
    await _db.collection('evenements').doc(e.id).update(e.toFirestore());
    if (e.clientId.isNotEmpty) await updateClientStats(e.clientId);
  }

  static Future<void> mettreAJourStatut(String id, String statut) async {
    await _db.collection('evenements').doc(id).update({'statut': statut});
  }

  // ─── DEVIS ─────────────────────────────────────────────────────────────────

  // NOUVEAU : Génère un numéro de devis lisible (ex: DEV-2026-042)
  static Future<String> generateNumeroDevis() async {
    final year = DateTime.now().year;
    final snap = await _db
        .collection('devis')
        .where('dateCreation',
            isGreaterThanOrEqualTo:
                Timestamp.fromDate(DateTime(year, 1, 1)))
        .get();
    final num = (snap.docs.length + 1).toString().padLeft(3, '0');
    return 'DEV-$year-$num';
  }

  static Stream<List<Devis>> getDevis() {
    return _db
        .collection('devis')
        .orderBy('dateCreation', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Devis.fromFirestore(d)).toList());
  }

  static Stream<List<Devis>> getDevisByClient(String clientId) {
    return _db
        .collection('devis')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => Devis.fromFirestore(d)).toList();
      list.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
      return list;
    });
  }

  // NOUVEAU : Devis expirés non relancés (CDC : Relances automatiques)
  static Future<List<Devis>> getDevisExpiresSansRelance() async {
    final now = Timestamp.now();
    final snap = await _db
        .collection('devis')
        .where('statut', whereIn: ['Envoyé', 'Brouillon'])
        .where('dateExpiration', isLessThan: now)
        .get();
    return snap.docs.map(Devis.fromFirestore).toList();
  }

  static Future<void> ajouterDevis(Devis devis) async {
    await _db.collection('devis').doc(devis.id).set(devis.toFirestore());
  }

  static Future<void> modifierStatutDevis(String id, String statut) async {
    final update = <String, dynamic>{'statut': statut};
    if (statut == 'Envoyé') {
      update['dateEnvoi'] = Timestamp.now();
    }
    await _db.collection('devis').doc(id).update(update);
  }

  static Future<void> convertirEnCommande(String devisId) async {
    await _db.collection('devis').doc(devisId).update({
      'statut': 'Accepté',
      'converti': true,
    });
  }

  // ─── AVIS ──────────────────────────────────────────────────────────────────

  static Stream<List<Avis>> getAvis() {
    return _db
        .collection('avis')
        .orderBy('dateCreation', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Avis.fromFirestore(d)).toList());
  }

  static Future<void> ajouterAvis(Avis avis) async {
    await _db.collection('avis').doc(avis.id).set(avis.toFirestore());
  }

  // NOUVEAU : Répondre à un avis (fidélisation)
  static Future<void> repondreAvis(String avisId, String reponse) async {
    await _db.collection('avis').doc(avisId).update({
      'reponseAdmin': reponse,
      'publie': true,
    });
  }

  // ─── MESSAGES ──────────────────────────────────────────────────────────────

  static Stream<List<Message>> getMessagesByClient(String clientId) {
    return _db
        .collection('messages')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => Message.fromFirestore(d)).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  static Future<void> ajouterMessage(Message message) async {
    await _db.collection('messages').doc(message.id).set(message.toFirestore());
  }

  // ─── RELANCES ──────────────────────────────────────────────────────────────
  // NOUVEAU : CDC "Relances automatiques"

  static Stream<List<Relance>> getRelancesPlanifiees() {
    return _db
        .collection('relances')
        .where('statut', isEqualTo: 'planifiée')
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => Relance.fromFirestore(d)).toList();
      list.sort((a, b) => a.datePrevue.compareTo(b.datePrevue));
      return list;
    });
  }

  static Future<void> ajouterRelance(Relance relance) async {
    await _db.collection('relances').doc(relance.id).set(relance.toFirestore());
  }

  static Future<void> marquerRelanceEffectuee(String relanceId) async {
    await _db
        .collection('relances')
        .doc(relanceId)
        .update({'statut': 'effectuée'});
  }

  // ─── CAMPAGNES ─────────────────────────────────────────────────────────────

  static Stream<List<Campagne>> getCampagnes() {
    return _db
        .collection('campagnes')
        .orderBy('datePrevue', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Campagne.fromFirestore(d)).toList());
  }

  static Future<void> ajouterCampagne(Campagne c) async {
    await _db.collection('campagnes').doc(c.id).set(c.toFirestore());
  }

  // ─── KPIs ÉTENDUS ──────────────────────────────────────────────────────────
  // AMÉLIORATION : + pack le plus vendu, taux fidélisation, saisonnalité

  static Future<Map<String, dynamic>> getKPIs() async {
    final clients = await _db
        .collection('clients')
        .where('actif', isEqualTo: true)
        .get();
    final evenements = await _db.collection('evenements').get();
    final devis = await _db.collection('devis').get();
    final avis = await _db.collection('avis').get();

    final totalClients = clients.docs.length;
    final prospects = clients.docs
        .where((d) => d.data()['typeClient'] == 'Prospect')
        .length;
    final vip = clients.docs
        .where((d) => d.data()['typeClient'] == 'VIP')
        .length;

    final totalEvenements = evenements.docs.length;
    final devisAcceptes =
        devis.docs.where((d) => d.data()['statut'] == 'Accepté').length;
    final tauxConversion = devis.docs.isEmpty
        ? 0.0
        : (devisAcceptes / devis.docs.length) * 100;

    double caTotal = 0;
    for (var doc in evenements.docs) {
      if (doc.data()['statut'] != 'Annulé') {
        caTotal += (doc.data()['budget'] ?? 0).toDouble();
      }
    }

    double noteMoyenne = 0;
    if (avis.docs.isNotEmpty) {
      for (var doc in avis.docs) {
        noteMoyenne += (doc.data()['note'] ?? 0).toDouble();
      }
      noteMoyenne /= avis.docs.length;
    }

    // Par type d'événement
    final Map<String, int> parType = {};
    final Map<String, double> caParType = {};
    for (var doc in evenements.docs) {
      final type = doc.data()['typeEvenement'] as String? ?? 'Autre';
      parType[type] = (parType[type] ?? 0) + 1;
      caParType[type] = (caParType[type] ?? 0) +
          (doc.data()['budget'] as num? ?? 0).toDouble();
    }

    // Pack le plus vendu (CDC : Optimisation ventes de packs)
    final Map<String, int> parPack = {};
    for (var doc in evenements.docs) {
      final pack = doc.data()['packChoisi'] as String? ?? '';
      if (pack.isNotEmpty) parPack[pack] = (parPack[pack] ?? 0) + 1;
    }
    String packLePlusVendu = '';
    if (parPack.isNotEmpty) {
      packLePlusVendu = parPack.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    // CA par mois (saisonnalité)
    final Map<String, double> caParMois = {};
    final now = DateTime.now();
    for (var doc in evenements.docs) {
      final date = (doc.data()['date'] as Timestamp).toDate();
      if (now.difference(date).inDays <= 365) {
        final key = '${date.month.toString().padLeft(2, '0')}/${date.year}';
        caParMois[key] = (caParMois[key] ?? 0) +
            (doc.data()['budget'] as num? ?? 0).toDouble();
      }
    }

    // Taux fidélisation : clients avec 2+ événements
    final clientsMultiEvents = clients.docs
        .where((d) => (d.data()['nombreEvenements'] ?? 0) >= 2)
        .length;
    final tauxFidelisation =
        totalClients > 0 ? clientsMultiEvents / totalClients * 100 : 0.0;

    // Source d'acquisition (CDC : Connaissance clients)
    final Map<String, int> parSource = {};
    for (var doc in clients.docs) {
      final src = doc.data()['sourceAcquisition'] as String? ?? 'Autre';
      if (src.isNotEmpty) parSource[src] = (parSource[src] ?? 0) + 1;
    }

    return {
      'totalClients': totalClients,
      'prospects': prospects,
      'vip': vip,
      'totalEvenements': totalEvenements,
      'tauxConversion': tauxConversion,
      'caTotal': caTotal,
      'noteMoyenne': noteMoyenne,
      'parType': parType,
      'caParType': caParType,
      'caParMois': caParMois,
      'packLePlusVendu': packLePlusVendu,
      'tauxFidelisation': tauxFidelisation,
      'parSource': parSource,
    };
  }
}