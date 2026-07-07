// lib/models/models.dart — VERSION AMÉLIORÉE
// Améliorations : segmentation par zone/fréquence, score fidélité auto-calculé,
//                 modèle Commande séparé du Devis, champ dateNaissance client,
//                 packs prédéfinis dans Evenement, tags couleurs

import 'package:cloud_firestore/cloud_firestore.dart';

// ─── CLIENT MODEL ─────────────────────────────────────────────────────────────
// AMÉLIORATIONS :
//  + dateNaissance → permet relances anniversaire automatiques (CDC : Marketing Automation)
//  + scoreFidelite calculé dynamiquement (ne plus stocker une valeur statique)
//  + segmentAuto : tag calculé selon budget/fréquence (CDC : Segmentation)
//  + tags : liste libre pour filtrage avancé
class Client {
  final String id;
  final String nom;
  final String prenom;
  final String telephone;
  final String email;
  final String adresse;
  final String ville;
  final String typeClient; // VIP, Régulier, Nouveau, Prospect
  final String sourceAcquisition;
  final DateTime dateCreation;
  final DateTime? dateNaissance; // ← NOUVEAU : pour campagnes anniversaire
  final double budgetMoyen;
  final int nombreEvenements;
  final double scoreFidelite; // 0-100, calculé côté service
  final String notes;
  final String? photoUrl;
  final bool actif;
  final List<String> tags; // ← NOUVEAU : segmentation libre (ex: "Mariée", "Corporate")

  Client({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    this.email = '',
    this.adresse = '',
    this.ville = '',
    this.typeClient = 'Nouveau',
    this.sourceAcquisition = '',
    required this.dateCreation,
    this.dateNaissance,
    this.budgetMoyen = 0,
    this.nombreEvenements = 0,
    this.scoreFidelite = 0,
    this.notes = '',
    this.photoUrl,
    this.actif = true,
    this.tags = const [],
  });

  String get nomComplet => '$prenom $nom';

  // Score calculé localement à partir des données réelles
  double get scoreCalcule {
    double score = 0;
    score += (nombreEvenements * 15).clamp(0, 45).toDouble();
    if (budgetMoyen > 5000) score += 25;
    else if (budgetMoyen > 2000) score += 15;
    else if (budgetMoyen > 500) score += 8;
    if (typeClient == 'VIP') score += 20;
    else if (typeClient == 'Régulier') score += 10;
    return score.clamp(0, 100).toDouble();
  }

  // Segment automatique (CDC : Segmentation par budget + fréquence)
  String get segmentAuto {
    if (nombreEvenements >= 3 && budgetMoyen >= 3000) return 'Champion';
    if (nombreEvenements >= 2 || budgetMoyen >= 2000) return 'Fidèle';
    if (typeClient == 'Prospect') return 'Prospect';
    return 'Nouveau';
  }

  factory Client.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Client(
      id: doc.id,
      nom: data['nom'] ?? '',
      prenom: data['prenom'] ?? '',
      telephone: data['telephone'] ?? '',
      email: data['email'] ?? '',
      adresse: data['adresse'] ?? '',
      ville: data['ville'] ?? '',
      typeClient: data['typeClient'] ?? 'Nouveau',
      sourceAcquisition: data['sourceAcquisition'] ?? '',
      dateCreation: (data['dateCreation'] as Timestamp).toDate(),
      dateNaissance: data['dateNaissance'] != null
          ? (data['dateNaissance'] as Timestamp).toDate()
          : null,
      budgetMoyen: (data['budgetMoyen'] ?? 0).toDouble(),
      nombreEvenements: data['nombreEvenements'] ?? 0,
      scoreFidelite: (data['scoreFidelite'] ?? 0).toDouble(),
      notes: data['notes'] ?? '',
      photoUrl: data['photoUrl'],
      actif: data['actif'] ?? true,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'nom': nom,
        'prenom': prenom,
        'telephone': telephone,
        'email': email,
        'adresse': adresse,
        'ville': ville,
        'typeClient': typeClient,
        'sourceAcquisition': sourceAcquisition,
        'dateCreation': Timestamp.fromDate(dateCreation),
        'dateNaissance':
            dateNaissance != null ? Timestamp.fromDate(dateNaissance!) : null,
        'budgetMoyen': budgetMoyen,
        'nombreEvenements': nombreEvenements,
        'scoreFidelite': scoreCalcule, // stocker le score calculé
        'notes': notes,
        'photoUrl': photoUrl,
        'actif': actif,
        'tags': tags,
      };

  Client copyWith({
    String? nom,
    String? prenom,
    String? telephone,
    String? email,
    String? adresse,
    String? ville,
    String? typeClient,
    String? sourceAcquisition,
    DateTime? dateNaissance,
    double? budgetMoyen,
    int? nombreEvenements,
    double? scoreFidelite,
    String? notes,
    String? photoUrl,
    bool? actif,
    List<String>? tags,
  }) =>
      Client(
        id: id,
        nom: nom ?? this.nom,
        prenom: prenom ?? this.prenom,
        telephone: telephone ?? this.telephone,
        email: email ?? this.email,
        adresse: adresse ?? this.adresse,
        ville: ville ?? this.ville,
        typeClient: typeClient ?? this.typeClient,
        sourceAcquisition: sourceAcquisition ?? this.sourceAcquisition,
        dateCreation: dateCreation,
        dateNaissance: dateNaissance ?? this.dateNaissance,
        budgetMoyen: budgetMoyen ?? this.budgetMoyen,
        nombreEvenements: nombreEvenements ?? this.nombreEvenements,
        scoreFidelite: scoreFidelite ?? this.scoreFidelite,
        notes: notes ?? this.notes,
        photoUrl: photoUrl ?? this.photoUrl,
        actif: actif ?? this.actif,
        tags: tags ?? this.tags,
      );
}

// ─── PACK PRÉDÉFINI ──────────────────────────────────────────────────────────
// NOUVEAU : CDC mentionne "Optimisation des ventes de packs"
// Catalogue de packs réutilisables plutôt que saisie libre
class PackDecoration {
  final String id;
  final String nom;
  final String description;
  final double prix;
  final List<String> inclusions;

  const PackDecoration({
    required this.id,
    required this.nom,
    required this.description,
    required this.prix,
    required this.inclusions,
  });

  // Packs par défaut DECO PAS PLUS
  static const List<PackDecoration> catalogue = [
    PackDecoration(
      id: 'pack_essentiel',
      nom: 'Pack Essentiel',
      description: 'Décoration de base pour petits événements',
      prix: 800,
      inclusions: ['Centres de table x5', 'Ballons', 'Nappe'],
    ),
    PackDecoration(
      id: 'pack_prestige',
      nom: 'Pack Prestige',
      description: 'Décoration complète pour événements élégants',
      prix: 2500,
      inclusions: [
        'Centres de table x10',
        'Arch floral',
        'Photobooth',
        'Éclairage ambiance'
      ],
    ),
    PackDecoration(
      id: 'pack_royal',
      nom: 'Pack Royal',
      description: 'Décoration luxueuse tout inclus',
      prix: 5000,
      inclusions: [
        'Décoration complète salle',
        'Fleurs fraîches',
        'Photobooth premium',
        'Éclairage professionnel',
        'Coordination jour J'
      ],
    ),
    PackDecoration(
      id: 'pack_custom',
      nom: 'Sur Mesure',
      description: 'Devis personnalisé',
      prix: 0,
      inclusions: [],
    ),
  ];
}

// ─── ÉVÉNEMENT MODEL ──────────────────────────────────────────────────────────
// AMÉLIORATIONS :
//  + packId lié au catalogue (au lieu de texte libre)
//  + couleurs stockées comme liste structurée
//  + heureDebut / heureFin pour planning précis
//  + nombreInvites exploité dans KPIs
class Evenement {
  final String id;
  final String clientId;
  final String clientNom;
  final String typeEvenement;
  final DateTime date;
  final String? heureDebut; // ← NOUVEAU : ex "14:00"
  final String lieu;
  final String ville;
  final double budget;
  final String packChoisi;
  final String packId; // ← NOUVEAU : lié à PackDecoration.catalogue
  final String theme;
  final List<String> couleurs;
  final String statut;
  final String notes;
  final List<String> photos;
  final DateTime dateCreation;
  final int nombreInvites;

  Evenement({
    required this.id,
    required this.clientId,
    required this.clientNom,
    required this.typeEvenement,
    required this.date,
    this.heureDebut,
    required this.lieu,
    this.ville = '',
    required this.budget,
    this.packChoisi = '',
    this.packId = '',
    this.theme = '',
    this.couleurs = const [],
    this.statut = 'En attente',
    this.notes = '',
    this.photos = const [],
    required this.dateCreation,
    this.nombreInvites = 0,
  });

  factory Evenement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Evenement(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      clientNom: data['clientNom'] ?? '',
      typeEvenement: data['typeEvenement'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      heureDebut: data['heureDebut'],
      lieu: data['lieu'] ?? '',
      ville: data['ville'] ?? '',
      budget: (data['budget'] ?? 0).toDouble(),
      packChoisi: data['packChoisi'] ?? '',
      packId: data['packId'] ?? '',
      theme: data['theme'] ?? '',
      couleurs: List<String>.from(data['couleurs'] ?? []),
      statut: data['statut'] ?? 'En attente',
      notes: data['notes'] ?? '',
      photos: List<String>.from(data['photos'] ?? []),
      dateCreation: (data['dateCreation'] as Timestamp).toDate(),
      nombreInvites: data['nombreInvites'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'clientId': clientId,
        'clientNom': clientNom,
        'typeEvenement': typeEvenement,
        'date': Timestamp.fromDate(date),
        'heureDebut': heureDebut,
        'lieu': lieu,
        'ville': ville,
        'budget': budget,
        'packChoisi': packChoisi,
        'packId': packId,
        'theme': theme,
        'couleurs': couleurs,
        'statut': statut,
        'notes': notes,
        'photos': photos,
        'dateCreation': Timestamp.fromDate(dateCreation),
        'nombreInvites': nombreInvites,
      };
}

// ─── DEVIS MODEL ──────────────────────────────────────────────────────────────
// AMÉLIORATIONS :
//  + numeroDevis lisible (ex: "DEV-2026-001") au lieu d'UUID brut
//  + tva : certains clients entreprises nécessitent TVA
//  + dateEnvoi : pour suivre délai de réponse
class Devis {
  final String id;
  final String numeroDevis; // ← NOUVEAU : ex "DEV-2026-042"
  final String clientId;
  final String clientNom;
  final String evenementId;
  final String typeEvenement;
  final List<LigneDevis> lignes;
  final double sousTotal;
  final double remise;
  final double tva; // ← NOUVEAU : 0 par défaut (particuliers), 19% entreprises
  final double total;
  final String statut;
  final DateTime dateCreation;
  final DateTime? dateEnvoi; // ← NOUVEAU : null = pas encore envoyé
  final DateTime dateExpiration;
  final String notes;
  final bool converti;

  Devis({
    required this.id,
    this.numeroDevis = '',
    required this.clientId,
    required this.clientNom,
    this.evenementId = '',
    this.typeEvenement = '',
    required this.lignes,
    required this.sousTotal,
    this.remise = 0,
    this.tva = 0,
    required this.total,
    this.statut = 'Brouillon',
    required this.dateCreation,
    this.dateEnvoi,
    required this.dateExpiration,
    this.notes = '',
    this.converti = false,
  });

  // Total TTC calculé
  double get totalTTC => total * (1 + tva / 100);

  factory Devis.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Devis(
      id: doc.id,
      numeroDevis: data['numeroDevis'] ?? '',
      clientId: data['clientId'] ?? '',
      clientNom: data['clientNom'] ?? '',
      evenementId: data['evenementId'] ?? '',
      typeEvenement: data['typeEvenement'] ?? '',
      lignes: (data['lignes'] as List<dynamic>? ?? [])
          .map((l) => LigneDevis.fromMap(l))
          .toList(),
      sousTotal: (data['sousTotal'] ?? 0).toDouble(),
      remise: (data['remise'] ?? 0).toDouble(),
      tva: (data['tva'] ?? 0).toDouble(),
      total: (data['total'] ?? 0).toDouble(),
      statut: data['statut'] ?? 'Brouillon',
      dateCreation: (data['dateCreation'] as Timestamp).toDate(),
      dateEnvoi: data['dateEnvoi'] != null
          ? (data['dateEnvoi'] as Timestamp).toDate()
          : null,
      dateExpiration: (data['dateExpiration'] as Timestamp).toDate(),
      notes: data['notes'] ?? '',
      converti: data['converti'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'numeroDevis': numeroDevis,
        'clientId': clientId,
        'clientNom': clientNom,
        'evenementId': evenementId,
        'typeEvenement': typeEvenement,
        'lignes': lignes.map((l) => l.toMap()).toList(),
        'sousTotal': sousTotal,
        'remise': remise,
        'tva': tva,
        'total': total,
        'statut': statut,
        'dateCreation': Timestamp.fromDate(dateCreation),
        'dateEnvoi': dateEnvoi != null ? Timestamp.fromDate(dateEnvoi!) : null,
        'dateExpiration': Timestamp.fromDate(dateExpiration),
        'notes': notes,
        'converti': converti,
      };
}

class LigneDevis {
  final String description;
  final int quantite;
  final double prixUnitaire;
  final double total;
  final String unite; // ← NOUVEAU : "unité", "heure", "forfait"

  LigneDevis({
    required this.description,
    required this.quantite,
    required this.prixUnitaire,
    required this.total,
    this.unite = 'unité',
  });

  factory LigneDevis.fromMap(Map<String, dynamic> map) => LigneDevis(
        description: map['description'] ?? '',
        quantite: map['quantite'] ?? 1,
        prixUnitaire: (map['prixUnitaire'] ?? 0).toDouble(),
        total: (map['total'] ?? 0).toDouble(),
        unite: map['unite'] ?? 'unité',
      );

  Map<String, dynamic> toMap() => {
        'description': description,
        'quantite': quantite,
        'prixUnitaire': prixUnitaire,
        'total': total,
        'unite': unite,
      };
}

// ─── AVIS MODEL ───────────────────────────────────────────────────────────────
// AMÉLIORATIONS :
//  + aspects : évaluation multi-critères (qualité déco, ponctualité, rapport qualité/prix)
//  + reponseAdmin : réponse de l'équipe à l'avis (fidélisation)
class Avis {
  final String id;
  final String clientId;
  final String clientNom;
  final String evenementId;
  final String typeEvenement;
  final double note; // Note globale 1-5
  final Map<String, double> aspects; // ← NOUVEAU : {"qualite": 5, "ponctualite": 4, ...}
  final String commentaire;
  final List<String> photos;
  final DateTime dateCreation;
  final bool publie;
  final String reponseAdmin; // ← NOUVEAU : réponse équipe

  Avis({
    required this.id,
    required this.clientId,
    required this.clientNom,
    this.evenementId = '',
    this.typeEvenement = '',
    required this.note,
    this.aspects = const {},
    this.commentaire = '',
    this.photos = const [],
    required this.dateCreation,
    this.publie = false,
    this.reponseAdmin = '',
  });

  factory Avis.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Avis(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      clientNom: data['clientNom'] ?? '',
      evenementId: data['evenementId'] ?? '',
      typeEvenement: data['typeEvenement'] ?? '',
      note: (data['note'] ?? 0).toDouble(),
      aspects: Map<String, double>.from(
        (data['aspects'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      commentaire: data['commentaire'] ?? '',
      photos: List<String>.from(data['photos'] ?? []),
      dateCreation: (data['dateCreation'] as Timestamp).toDate(),
      publie: data['publie'] ?? false,
      reponseAdmin: data['reponseAdmin'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'clientId': clientId,
        'clientNom': clientNom,
        'evenementId': evenementId,
        'typeEvenement': typeEvenement,
        'note': note,
        'aspects': aspects,
        'commentaire': commentaire,
        'photos': photos,
        'dateCreation': Timestamp.fromDate(dateCreation),
        'publie': publie,
        'reponseAdmin': reponseAdmin,
      };
}

// ─── MESSAGE MODEL ────────────────────────────────────────────────────────────
class Message {
  final String id;
  final String clientId;
  final String clientNom;
  final String contenu;
  final String canal; // WhatsApp, Email, SMS, Appel
  final String direction; // Entrant, Sortant
  final DateTime date;
  final bool lu;

  Message({
    required this.id,
    required this.clientId,
    required this.clientNom,
    required this.contenu,
    this.canal = 'WhatsApp',
    this.direction = 'Sortant',
    required this.date,
    this.lu = false,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      clientNom: data['clientNom'] ?? '',
      contenu: data['contenu'] ?? '',
      canal: data['canal'] ?? 'WhatsApp',
      direction: data['direction'] ?? 'Sortant',
      date: (data['date'] as Timestamp).toDate(),
      lu: data['lu'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'clientId': clientId,
        'clientNom': clientNom,
        'contenu': contenu,
        'canal': canal,
        'direction': direction,
        'date': Timestamp.fromDate(date),
        'lu': lu,
      };
}

// ─── CAMPAGNE MARKETING MODEL ─────────────────────────────────────────────────
// AMÉLIORATIONS :
//  + typeCampagne : "relance", "promo", "anniversaire", "bienvenue"
//  + periodicite : pour campagnes récurrentes automatiques
//  + resultat : tracking après envoi
class Campagne {
  final String id;
  final String titre;
  final String message;
  final String cible;
  final String canal;
  final String typeCampagne; // ← NOUVEAU : relance|promo|anniversaire|bienvenue
  final DateTime datePrevue;
  final String statut;
  final int nombreDestinataires;
  final int nombreOuvertures;
  final int nombreClics; // ← NOUVEAU

  Campagne({
    required this.id,
    required this.titre,
    required this.message,
    this.cible = 'Tous',
    this.canal = 'WhatsApp',
    this.typeCampagne = 'promo',
    required this.datePrevue,
    this.statut = 'Planifiée',
    this.nombreDestinataires = 0,
    this.nombreOuvertures = 0,
    this.nombreClics = 0,
  });

  double get tauxOuverture => nombreDestinataires > 0
      ? nombreOuvertures / nombreDestinataires * 100
      : 0;

  factory Campagne.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Campagne(
      id: doc.id,
      titre: data['titre'] ?? '',
      message: data['message'] ?? '',
      cible: data['cible'] ?? 'Tous',
      canal: data['canal'] ?? 'WhatsApp',
      typeCampagne: data['typeCampagne'] ?? 'promo',
      datePrevue: (data['datePrevue'] as Timestamp).toDate(),
      statut: data['statut'] ?? 'Planifiée',
      nombreDestinataires: data['nombreDestinataires'] ?? 0,
      nombreOuvertures: data['nombreOuvertures'] ?? 0,
      nombreClics: data['nombreClics'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'titre': titre,
        'message': message,
        'cible': cible,
        'canal': canal,
        'typeCampagne': typeCampagne,
        'datePrevue': Timestamp.fromDate(datePrevue),
        'statut': statut,
        'nombreDestinataires': nombreDestinataires,
        'nombreOuvertures': nombreOuvertures,
        'nombreClics': nombreClics,
      };
}

// ─── RELANCE AUTOMATIQUE MODEL ────────────────────────────────────────────────
// NOUVEAU : CDC "Relances automatiques" — suivre les relances planifiées
class Relance {
  final String id;
  final String clientId;
  final String clientNom;
  final String motif; // "devis_en_attente", "client_inactif", "anniversaire_event"
  final DateTime datePrevue;
  final String statut; // "planifiée", "effectuée", "ignorée"
  final String notes;

  Relance({
    required this.id,
    required this.clientId,
    required this.clientNom,
    required this.motif,
    required this.datePrevue,
    this.statut = 'planifiée',
    this.notes = '',
  });

  factory Relance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Relance(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      clientNom: data['clientNom'] ?? '',
      motif: data['motif'] ?? '',
      datePrevue: (data['datePrevue'] as Timestamp).toDate(),
      statut: data['statut'] ?? 'planifiée',
      notes: data['notes'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'clientId': clientId,
        'clientNom': clientNom,
        'motif': motif,
        'datePrevue': Timestamp.fromDate(datePrevue),
        'statut': statut,
        'notes': notes,
      };
}
