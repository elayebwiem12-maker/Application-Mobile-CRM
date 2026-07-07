// lib/widgets/notifications_widget.dart — NOUVEAU
// In-App Notifications Badge
// Affiche les alertes dans le dashboard :
//   - Devis expirés
//   - Clients inactifs
//   - Anniversaires ce mois
//   - Relances en attente

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/theme.dart';
import '../models/models.dart';

class NotificationsBadge extends StatelessWidget {
  final VoidCallback? onTap;
  const NotificationsBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _countAlertes(),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined, color: Colors.white),
              if (count > 0)
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<int> _countAlertes() async {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    int count = 0;

    try {
      // 1. Devis expirés
      final devisSnap = await db.collection('devis').get();
      count += devisSnap.docs.where((d) {
        final data = d.data();
        final statut = data['statut'] as String? ?? '';
        if (statut != 'Envoyé' && statut != 'Brouillon') return false;
        try {
          final exp = (data['dateExpiration'] as Timestamp).toDate();
          return exp.isBefore(now);
        } catch (_) { return false; }
      }).length;

      // 2. Anniversaires ce mois
      final clientsSnap = await db.collection('clients')
          .where('actif', isEqualTo: true)
          .get();
      count += clientsSnap.docs.where((d) {
        final data = d.data();
        if (data['dateNaissance'] == null) return false;
        try {
          final dob = (data['dateNaissance'] as Timestamp).toDate();
          return dob.month == now.month;
        } catch (_) { return false; }
      }).length;

      // 3. Clients inactifs (sans event depuis 3 mois)
      final cutoff = now.subtract(const Duration(days: 90));
      final evSnap = await db.collection('evenements')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .get();
      final actifsIds = evSnap.docs
          .map((d) => d.data()['clientId'] as String? ?? '')
          .toSet();
      final inactifsCount = clientsSnap.docs.where((d) {
        final id = d.id;
        final nb = (d.data()['nombreEvenements'] as int? ?? 0);
        return nb > 0 && !actifsIds.contains(id);
      }).length;
      if (inactifsCount > 0) count++;

    } catch (_) {}

    return count;
  }
}

// ─── PANEL NOTIFICATIONS (s'affiche au tap) ──────────────────────────────────
class NotificationsPanel extends StatefulWidget {
  const NotificationsPanel({super.key});

  @override
  State<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel> {
  List<_Notif> _notifs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final List<_Notif> notifs = [];

    try {
      // Devis expirés
      final devisSnap = await db.collection('devis').get();
      for (final d in devisSnap.docs) {
        final data = d.data();
        final statut = data['statut'] as String? ?? '';
        if (statut != 'Envoyé' && statut != 'Brouillon') continue;
        try {
          final exp = (data['dateExpiration'] as Timestamp).toDate();
          if (exp.isBefore(now)) {
            final num = data['numeroDevis'] as String? ?? '';
            final client = data['clientNom'] as String? ?? '';
            notifs.add(_Notif(
              icon: Icons.receipt_long_outlined,
              color: AppColors.error,
              titre: 'Devis expiré',
              message: '${num.isNotEmpty ? num : "Devis"} de $client',
              type: 'devis',
            ));
          }
        } catch (_) {}
      }

      // Anniversaires
      final clientsSnap = await db.collection('clients')
          .where('actif', isEqualTo: true).get();
      for (final d in clientsSnap.docs) {
        final data = d.data();
        if (data['dateNaissance'] == null) continue;
        try {
          final dob = (data['dateNaissance'] as Timestamp).toDate();
          if (dob.month == now.month) {
            final prenom = data['prenom'] as String? ?? '';
            final nom = data['nom'] as String? ?? '';
            notifs.add(_Notif(
              icon: Icons.cake_outlined,
              color: AppColors.success,
              titre: 'Anniversaire 🎂',
              message: '$prenom $nom fête son anniversaire ce mois',
              type: 'anniversaire',
            ));
          }
        } catch (_) {}
      }

      // Clients inactifs
      final cutoff = now.subtract(const Duration(days: 90));
      final evSnap = await db.collection('evenements')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .get();
      final actifsIds = evSnap.docs
          .map((d) => d.data()['clientId'] as String? ?? '')
          .toSet();
      final inactifs = clientsSnap.docs.where((d) {
        final nb = (d.data()['nombreEvenements'] as int? ?? 0);
        return nb > 0 && !actifsIds.contains(d.id);
      }).length;
      if (inactifs > 0) {
        notifs.add(_Notif(
          icon: Icons.person_off_outlined,
          color: AppColors.warning,
          titre: 'Clients inactifs',
          message: '$inactifs client(s) sans événement depuis 3 mois',
          type: 'inactifs',
        ));
      }
    } catch (_) {}

    setState(() { _notifs = notifs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Notifications',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 18, color: AppColors.textDark)),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (_notifs.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: AppColors.success, size: 48),
                    SizedBox(height: 8),
                    Text('Tout est à jour ! 🎉',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Aucune alerte en cours',
                        style: TextStyle(color: AppColors.textLight)),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _notifs.map((n) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: n.color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: n.color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: n.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(n.icon, color: n.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.titre, style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13, color: n.color)),
                          Text(n.message, style: const TextStyle(
                              color: AppColors.textMedium, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _Notif {
  final IconData icon;
  final Color color;
  final String titre;
  final String message;
  final String type;
  _Notif({required this.icon, required this.color,
    required this.titre, required this.message, required this.type});
}
