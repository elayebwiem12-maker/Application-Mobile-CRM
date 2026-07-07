// lib/screens/relances_screen.dart — NOUVEAU
// CDC : Relances automatiques
// Détecte automatiquement : devis expirés, clients inactifs, anniversaires
// et envoie des emails de relance via EmailJS

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../services/email_service.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';

class RelancesScreen extends StatefulWidget {
  const RelancesScreen({super.key});

  @override
  State<RelancesScreen> createState() => _RelancesScreenState();
}

class _RelancesScreenState extends State<RelancesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<_RelanceItem> _devisExpires = [];
  List<_RelanceItem> _clientsInactifs = [];
  List<_RelanceItem> _anniversaires = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadRelances();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRelances() async {
    setState(() => _loading = true);
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();

    // 1. Devis expirés (statut Envoyé/Brouillon + date expirée)
    final devisSnap = await db.collection('devis').get();
    final devis = devisSnap.docs.map((d) => Devis.fromFirestore(d)).toList();
    final expires = devis
        .where((d) =>
            (d.statut == 'Envoyé' || d.statut == 'Brouillon') &&
            d.dateExpiration.isBefore(now))
        .map((d) => _RelanceItem(
              clientNom: d.clientNom,
              clientId: d.clientId,
              motif: 'Devis ${d.numeroDevis.isNotEmpty ? d.numeroDevis : "#${d.id.substring(0, 6).toUpperCase()}"} expiré',
              detail: 'Expiré le ${formatDate(d.dateExpiration)} — ${formatMontant(d.total)}',
              urgence: _urgence(d.dateExpiration),
              emailTemplate:
                  'Bonjour [Nom],\n\nVotre devis est arrivé à expiration. '
                  'Souhaitez-vous qu\'on le renouvelle ?\n\n'
                  'Nous restons disponibles !\n\nCordialement,\nDECO PAS PLUS',
              sujet: 'Renouvellement de votre devis — DECO PAS PLUS',
            ))
        .toList();

    // 2. Clients inactifs depuis 3 mois
    final clientsSnap = await db
        .collection('clients')
        .where('actif', isEqualTo: true)
        .get();
    final clients = clientsSnap.docs.map((d) => Client.fromFirestore(d)).toList();
    final cutoff = now.subtract(const Duration(days: 90));
    final evSnap = await db
        .collection('evenements')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .get();
    final actifsIds = evSnap.docs
        .map((d) => d.data()['clientId'] as String)
        .toSet();
    final inactifs = clients
        .where((c) => !actifsIds.contains(c.id) && c.nombreEvenements > 0)
        .map((c) => _RelanceItem(
              clientNom: c.nomComplet,
              clientId: c.id,
              clientEmail: c.email,
              motif: 'Inactif depuis plus de 3 mois',
              detail: '${c.nombreEvenements} événement(s) — Budget moy. ${formatMontant(c.budgetMoyen)}',
              urgence: 'Moyen',
              emailTemplate:
                  'Bonjour [Nom],\n\nCela fait un moment qu\'on ne s\'est pas vus ! '
                  'Nous avons de nouvelles offres exclusives pour vous. '
                  'N\'hésitez pas à nous contacter pour votre prochain événement 😊\n\n'
                  'Cordialement,\nDECO PAS PLUS',
              sujet: 'On pense à vous ! — DECO PAS PLUS',
            ))
        .toList();

    // 3. Anniversaires ce mois-ci
    print('🔍 DEBUG: now.month = ${now.month}, now.year = ${now.year}');
    print('🔍 DEBUG: nombre clients total = ${clients.length}');
    for (final c in clients) {
      print('🔍 DEBUG: ${c.nomComplet} — dateNaissance = ${c.dateNaissance}');
    }
    final anniversaires = clients
        .where((c) =>
            c.dateNaissance != null && c.dateNaissance!.month == now.month)
        .map((c) => _RelanceItem(
              clientNom: c.nomComplet,
              clientId: c.id,
              clientEmail: c.email,
              motif: 'Anniversaire ce mois-ci 🎂',
              detail: 'Le ${c.dateNaissance!.day}/${c.dateNaissance!.month}',
              urgence: 'Faible',
              emailTemplate:
                  'Bonjour [Nom],\n\n🎂 Joyeux anniversaire !\n\n'
                  'En ce jour spécial, DECO PAS PLUS vous offre -10% '
                  'sur votre prochain événement.\n\n'
                  'Profitez-en avant la fin du mois !\n\nCordialement,\nDECO PAS PLUS',
              sujet: '🎂 Joyeux anniversaire de la part de DECO PAS PLUS !',
            ))
        .toList();

    setState(() {
      _devisExpires = expires;
      _clientsInactifs = inactifs;
      _anniversaires = anniversaires;
      _loading = false;
    });
  }

  String _urgence(DateTime date) {
    final jours = DateTime.now().difference(date).inDays;
    if (jours > 14) return 'Urgent';
    if (jours > 7)  return 'Moyen';
    return 'Faible';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Relances Automatiques'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRelances),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(
              icon: Badge(
                label: Text('${_devisExpires.length}'),
                isLabelVisible: _devisExpires.isNotEmpty,
                child: const Icon(Icons.receipt_long_outlined),
              ),
              text: 'Devis',
            ),
            Tab(
              icon: Badge(
                label: Text('${_clientsInactifs.length}'),
                isLabelVisible: _clientsInactifs.isNotEmpty,
                child: const Icon(Icons.person_off_outlined),
              ),
              text: 'Inactifs',
            ),
            Tab(
              icon: Badge(
                label: Text('${_anniversaires.length}'),
                isLabelVisible: _anniversaires.isNotEmpty,
                child: const Icon(Icons.cake_outlined),
              ),
              text: 'Anniversaires',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildListe(_devisExpires, 'Aucun devis expiré 🎉',
                    'Tous vos devis sont à jour !'),
                _buildListe(_clientsInactifs, 'Aucun client inactif 🎉',
                    'Tous vos clients sont actifs !'),
                _buildListe(_anniversaires, 'Aucun anniversaire ce mois 🎉',
                    'Revenez le mois prochain !'),
              ],
            ),
      // Bouton envoyer tout
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _envoyerTout(context),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Tout relancer par email'),
            ),
    );
  }

  Widget _buildListe(List<_RelanceItem> items, String emptyTitle, String emptySub) {
    if (items.isEmpty) {
      return EmptyState(icon: Icons.check_circle_outline, title: emptyTitle, subtitle: emptySub);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _RelanceCard(
        item: items[i],
        onEnvoyer: () => _envoyerRelance(context, items[i]),
      ),
    );
  }

  Future<void> _envoyerRelance(BuildContext context, _RelanceItem item) async {
    if (item.clientEmail.isEmpty || !item.clientEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ Ce client n\'a pas d\'email renseigné'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    final ok = await EmailService.sendEmail(
      toEmail: item.clientEmail,
      toName: item.clientNom,
      subject: item.sujet,
      message: item.emailTemplate.replaceAll('[Nom]', item.clientNom),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? '✅ Email envoyé à ${item.clientNom}'
            : '❌ Erreur envoi à ${item.clientNom}'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ));
    }
  }

  Future<void> _envoyerTout(BuildContext context) async {
    final tous = [..._devisExpires, ..._clientsInactifs, ..._anniversaires]
        .where((i) => i.clientEmail.contains('@'))
        .toList();

    if (tous.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ Aucun client avec email disponible'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer l\'envoi',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Envoyer ${tous.length} email(s) de relance ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Envoyer tout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    int envoyes = 0;
    for (final item in tous) {
      final ok = await EmailService.sendEmail(
        toEmail: item.clientEmail,
        toName: item.clientNom,
        subject: item.sujet,
        message: item.emailTemplate.replaceAll('[Nom]', item.clientNom),
      );
      if (ok) envoyes++;
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ $envoyes/${tous.length} emails envoyés'),
        backgroundColor: AppColors.success,
      ));
    }
  }
}

// ─── MODÈLE RELANCE ──────────────────────────────────────────────────────────
class _RelanceItem {
  final String clientNom;
  final String clientId;
  final String clientEmail;
  final String motif;
  final String detail;
  final String urgence;
  final String emailTemplate;
  final String sujet;

  _RelanceItem({
    required this.clientNom,
    required this.clientId,
    this.clientEmail = '',
    required this.motif,
    required this.detail,
    required this.urgence,
    required this.emailTemplate,
    required this.sujet,
  });
}

// ─── CARTE RELANCE ────────────────────────────────────────────────────────────
class _RelanceCard extends StatelessWidget {
  final _RelanceItem item;
  final VoidCallback onEnvoyer;

  const _RelanceCard({required this.item, required this.onEnvoyer});

  Color get _urgenceColor {
    switch (item.urgence) {
      case 'Urgent': return AppColors.error;
      case 'Moyen':  return AppColors.warning;
      default:       return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasEmail = item.clientEmail.contains('@');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _urgenceColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(
          color: _urgenceColor.withOpacity(0.06),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClientAvatar(nom: item.clientNom, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.clientNom, style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(item.motif, style: const TextStyle(
                        color: AppColors.textMedium, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _urgenceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(item.urgence,
                    style: TextStyle(color: _urgenceColor,
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.detail, style: const TextStyle(
              color: AppColors.textLight, fontSize: 11)),
          if (!hasEmail) ...[
            const SizedBox(height: 6),
            const Row(children: [
              Icon(Icons.warning_amber_outlined, size: 12, color: AppColors.warning),
              SizedBox(width: 4),
              Text('Email non renseigné', style: TextStyle(
                  color: AppColors.warning, fontSize: 11)),
            ]),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: hasEmail ? onEnvoyer : null,
              icon: const Icon(Icons.email_outlined, size: 14),
              label: Text(hasEmail ? 'Envoyer email de relance' : 'Email manquant',
                  style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: hasEmail ? AppColors.primary : AppColors.textLight,
                side: BorderSide(
                    color: hasEmail
                        ? AppColors.primary.withOpacity(0.5)
                        : AppColors.textLight.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}