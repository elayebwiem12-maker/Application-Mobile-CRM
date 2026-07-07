// lib/services/email_service.dart — NOUVEAU
// Envoie des emails via EmailJS (gratuit, 200/mois)
// Ne nécessite pas de backend — fonctionne directement depuis Flutter

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailService {
  // ─── CONFIGURATION EMAILJS ───────────────────────────────────────────────
  static const String _publicKey   = 'sZh5cX6STwd4wp5iM';
  static const String _serviceId   = 'service_sf4p6qo';
  static const String _templateId  = 'template_8kk2jlt';
  static const String _apiUrl      = 'https://api.emailjs.com/api/v1.0/email/send';

  // ─── ENVOYER UN EMAIL ────────────────────────────────────────────────────
  static Future<bool> sendEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id':  _serviceId,
          'template_id': _templateId,
          'user_id':     _publicKey,
          'template_params': {
            'to_email': toEmail,
            'to_name':  toName,
            'subject':  subject,
            'message':  message,
            'email':    toEmail,
          },
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('EmailJS error: $e');
      return false;
    }
  }

  // ─── ENVOYER UNE CAMPAGNE À UN SEGMENT ──────────────────────────────────
  // Récupère les clients selon la cible et envoie un email à chacun
  static Future<CampagneResult> envoyerCampagne({
    required String cible,       // 'VIP', 'Nouveaux', 'Inactifs', 'Tous', etc.
    required String subject,
    required String message,
  }) async {
    final db = FirebaseFirestore.instance;

    // 1. Récupérer les clients selon la cible
    final snap = await db.collection('clients')
        .where('actif', isEqualTo: true)
        .get();

    var clients = snap.docs.map((d) => d.data()).toList();

    // 2. Filtrer selon la cible
    if (cible == 'VIP') {
      clients = clients.where((c) => c['typeClient'] == 'VIP').toList();
    } else if (cible == 'Nouveaux') {
      clients = clients.where((c) => c['typeClient'] == 'Nouveau').toList();
    } else if (cible == 'Réguliers') {
      clients = clients.where((c) => c['typeClient'] == 'Régulier').toList();
    } else if (cible == 'Prospects') {
      clients = clients.where((c) => c['typeClient'] == 'Prospect').toList();
    } else if (cible == 'Inactifs') {
      // Clients sans événement depuis 3 mois
      final cutoff = DateTime.now().subtract(const Duration(days: 90));
      final eventsSnap = await db.collection('evenements')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .get();
      final actifsIds = eventsSnap.docs
          .map((d) => d.data()['clientId'] as String)
          .toSet();
      clients = clients.where((c) => !actifsIds.contains(c['id'] ?? '')).toList();
    } else if (cible == 'Anniversaires') {
      final now = DateTime.now();
      clients = clients.where((c) {
        if (c['dateNaissance'] == null) return false;
        final dob = (c['dateNaissance'] as Timestamp).toDate();
        return dob.month == now.month;
      }).toList();
    }
    // 'Tous' = pas de filtre

    // 3. Garder uniquement les clients avec un email valide
    final avecEmail = clients
        .where((c) => (c['email'] as String? ?? '').contains('@'))
        .toList();

    if (avecEmail.isEmpty) {
      return CampagneResult(
        total: clients.length,
        envoyes: 0,
        echoues: 0,
        sansEmail: clients.length,
      );
    }

    // 4. Envoyer les emails un par un
    int envoyes = 0;
    int echoues = 0;

    for (final client in avecEmail) {
      final prenom = client['prenom'] as String? ?? '';
      final nom    = client['nom']    as String? ?? '';
      final email  = client['email']  as String? ?? '';
      final nomComplet = '$prenom $nom'.trim();

      // Personnaliser le message avec le nom du client
      final msgPersonalise = message.replaceAll('[Nom]', nomComplet);

      final ok = await sendEmail(
        toEmail: email,
        toName: nomComplet,
        subject: subject,
        message: msgPersonalise,
      );

      if (ok) envoyes++; else echoues++;

      // Petite pause entre les envois pour éviter le spam
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return CampagneResult(
      total: clients.length,
      envoyes: envoyes,
      echoues: echoues,
      sansEmail: clients.length - avecEmail.length,
    );
  }
}

// ─── RÉSULTAT D'UNE CAMPAGNE ─────────────────────────────────────────────────
class CampagneResult {
  final int total;
  final int envoyes;
  final int echoues;
  final int sansEmail;

  CampagneResult({
    required this.total,
    required this.envoyes,
    required this.echoues,
    required this.sansEmail,
  });

  String get summary =>
      '✅ $envoyes email(s) envoyé(s)'
      '${echoues > 0 ? '\n❌ $echoues échoué(s)' : ''}'
      '${sansEmail > 0 ? '\n⚠️ $sansEmail client(s) sans email' : ''}';
}
