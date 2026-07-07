// lib/models/app_user.dart — NOUVEAU
// Modèle utilisateur de l'application (stocké dans collection 'users')
// Différent de Firebase Auth User (qui ne contient que email/uid/etc.)
// Ici on ajoute le rôle et les infos métier.

import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String nom;
  final String prenom;
  final String role; // 'admin' ou 'employe'
  final String? photoUrl;
  final DateTime dateCreation;
  final bool actif;

  AppUser({
    required this.uid,
    required this.email,
    required this.nom,
    required this.prenom,
    this.role = 'employe',
    this.photoUrl,
    required this.dateCreation,
    this.actif = true,
  });

  bool get isAdmin => role == 'admin';

  String get nomComplet => '$prenom $nom';

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      nom: data['nom'] ?? '',
      prenom: data['prenom'] ?? '',
      role: data['role'] ?? 'employe',
      photoUrl: data['photoUrl'],
      dateCreation: data['dateCreation'] != null
          ? (data['dateCreation'] as Timestamp).toDate()
          : DateTime.now(),
      actif: data['actif'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'nom': nom,
        'prenom': prenom,
        'role': role,
        'photoUrl': photoUrl,
        'dateCreation': Timestamp.fromDate(dateCreation),
        'actif': actif,
      };
}
