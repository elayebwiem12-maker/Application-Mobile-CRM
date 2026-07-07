// lib/screens/segmentation_screen.dart — NOUVEAU
// CDC : Segmentation Clients par budget, zone, fréquence, satisfaction
// Affiche les clients filtrés avec stats + bouton action directe

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/email_service.dart';
import 'client_detail_screen.dart';

class SegmentationScreen extends StatefulWidget {
  const SegmentationScreen({super.key});

  @override
  State<SegmentationScreen> createState() => _SegmentationScreenState();
}

class _SegmentationScreenState extends State<SegmentationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Segmentation Clients'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Budget'),
            Tab(icon: Icon(Icons.location_on_outlined), text: 'Zone'),
            Tab(icon: Icon(Icons.repeat_outlined), text: 'Fréquence'),
            Tab(icon: Icon(Icons.star_outline), text: 'Satisfaction'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _SegmentBudget(),
          _SegmentZone(),
          _SegmentFrequence(),
          _SegmentSatisfaction(),
        ],
      ),
    );
  }
}

// ─── SEGMENTATION PAR BUDGET ─────────────────────────────────────────────────
class _SegmentBudget extends StatelessWidget {
  const _SegmentBudget();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clients')
          .where('actif', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        final clients = snap.data!.docs.map((d) => Client.fromFirestore(d)).toList();

        final premium  = clients.where((c) => c.budgetMoyen >= 3000).toList();
        final moyen    = clients.where((c) => c.budgetMoyen >= 1000 && c.budgetMoyen < 3000).toList();
        final econome  = clients.where((c) => c.budgetMoyen > 0 && c.budgetMoyen < 1000).toList();
        final nouveau  = clients.where((c) => c.budgetMoyen == 0).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SegmentCard(
              icon: Icons.diamond_outlined,
              label: 'Premium',
              subtitle: 'Budget ≥ 3 000 DT',
              count: premium.length,
              color: AppColors.gold,
              clients: premium,
              cibleEmail: 'VIP',
            ),
            _SegmentCard(
              icon: Icons.star_outline,
              label: 'Moyen Gamme',
              subtitle: '1 000 — 3 000 DT',
              count: moyen.length,
              color: AppColors.primary,
              clients: moyen,
              cibleEmail: 'Réguliers',
            ),
            _SegmentCard(
              icon: Icons.savings_outlined,
              label: 'Économique',
              subtitle: 'Budget < 1 000 DT',
              count: econome.length,
              color: AppColors.info,
              clients: econome,
              cibleEmail: 'Nouveaux',
            ),
            _SegmentCard(
              icon: Icons.person_add_outlined,
              label: 'Sans historique',
              subtitle: 'Aucun événement encore',
              count: nouveau.length,
              color: AppColors.textMedium,
              clients: nouveau,
              cibleEmail: 'Nouveaux',
            ),
          ],
        );
      },
    );
  }
}

// ─── SEGMENTATION PAR ZONE ───────────────────────────────────────────────────
class _SegmentZone extends StatelessWidget {
  const _SegmentZone();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clients')
          .where('actif', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        final clients = snap.data!.docs.map((d) => Client.fromFirestore(d)).toList();

        // Grouper par ville
        final Map<String, List<Client>> parVille = {};
        for (final c in clients) {
          final ville = c.ville.isEmpty ? 'Non renseignée' : c.ville;
          parVille.putIfAbsent(ville, () => []).add(c);
        }

        final sorted = parVille.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));

        if (sorted.isEmpty) {
          return const EmptyState(icon: Icons.location_off, title: 'Aucune zone disponible');
        }

        final colors = [AppColors.primary, AppColors.gold, AppColors.info,
          AppColors.success, AppColors.warning, AppColors.error];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Résumé
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatMini('Zones', '${sorted.length}', Icons.map_outlined),
                  _StatMini('Clients', '${clients.length}', Icons.people_outline),
                  _StatMini('Top zone', sorted.isNotEmpty ? sorted.first.key : '-',
                      Icons.location_on_outlined),
                ],
              ),
            ),
            ...sorted.asMap().entries.map((entry) {
              final color = colors[entry.key % colors.length];
              final ville = entry.value.key;
              final list  = entry.value.value;
              final pct   = clients.isNotEmpty ? list.length / clients.length * 100 : 0.0;

              return _ZoneCard(
                ville: ville,
                count: list.length,
                pct: pct,
                color: color,
                clients: list,
              );
            }),
          ],
        );
      },
    );
  }
}

// ─── SEGMENTATION PAR FRÉQUENCE ──────────────────────────────────────────────
class _SegmentFrequence extends StatelessWidget {
  const _SegmentFrequence();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clients')
          .where('actif', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        final clients = snap.data!.docs.map((d) => Client.fromFirestore(d)).toList();

        final champions = clients.where((c) => c.nombreEvenements >= 3).toList();
        final fideles   = clients.where((c) => c.nombreEvenements == 2).toList();
        final ponctuels = clients.where((c) => c.nombreEvenements == 1).toList();
        final inactifs  = clients.where((c) => c.nombreEvenements == 0).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SegmentCard(
              icon: Icons.emoji_events_outlined,
              label: 'Champions',
              subtitle: '3 événements et plus',
              count: champions.length,
              color: AppColors.gold,
              clients: champions,
              cibleEmail: 'VIP',
            ),
            _SegmentCard(
              icon: Icons.favorite_outline,
              label: 'Fidèles',
              subtitle: '2 événements',
              count: fideles.length,
              color: AppColors.success,
              clients: fideles,
              cibleEmail: 'Réguliers',
            ),
            _SegmentCard(
              icon: Icons.person_outline,
              label: 'Ponctuels',
              subtitle: '1 seul événement',
              count: ponctuels.length,
              color: AppColors.info,
              clients: ponctuels,
              cibleEmail: 'Nouveaux',
            ),
            _SegmentCard(
              icon: Icons.person_off_outlined,
              label: 'Inactifs',
              subtitle: 'Aucun événement',
              count: inactifs.length,
              color: AppColors.error,
              clients: inactifs,
              cibleEmail: 'Inactifs',
            ),
          ],
        );
      },
    );
  }
}

// ─── SEGMENTATION PAR SATISFACTION ──────────────────────────────────────────
class _SegmentSatisfaction extends StatelessWidget {
  const _SegmentSatisfaction();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('avis').get(),
      builder: (context, avisSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clients')
              .where('actif', isEqualTo: true)
              .snapshots(),
          builder: (context, clientsSnap) {
            if (!clientsSnap.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            final clients = clientsSnap.data!.docs
                .map((d) => Client.fromFirestore(d))
                .toList();

            // Map clientId -> note moyenne
            final Map<String, List<double>> notesParClient = {};
            if (avisSnap.hasData) {
              for (final doc in avisSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final cId  = data['clientId'] as String? ?? '';
                final note = (data['note'] as num? ?? 0).toDouble();
                if (cId.isNotEmpty) {
                  notesParClient.putIfAbsent(cId, () => []).add(note);
                }
              }
            }

            double moyenneNote(String clientId) {
              final notes = notesParClient[clientId];
              if (notes == null || notes.isEmpty) return -1;
              return notes.reduce((a, b) => a + b) / notes.length;
            }

            final ambassadeurs = clients
                .where((c) => moyenneNote(c.id) >= 4.5)
                .toList();
            final satisfaits = clients
                .where((c) => moyenneNote(c.id) >= 3.5 && moyenneNote(c.id) < 4.5)
                .toList();
            final neutres = clients
                .where((c) => moyenneNote(c.id) >= 2.5 && moyenneNote(c.id) < 3.5)
                .toList();
            final insatisfaits = clients
                .where((c) => moyenneNote(c.id) > 0 && moyenneNote(c.id) < 2.5)
                .toList();
            final sansAvis = clients
                .where((c) => moyenneNote(c.id) == -1)
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SegmentCard(
                  icon: Icons.sentiment_very_satisfied_outlined,
                  label: 'Ambassadeurs',
                  subtitle: 'Note ≥ 4.5 ⭐',
                  count: ambassadeurs.length,
                  color: AppColors.gold,
                  clients: ambassadeurs,
                  cibleEmail: 'VIP',
                ),
                _SegmentCard(
                  icon: Icons.sentiment_satisfied_outlined,
                  label: 'Satisfaits',
                  subtitle: 'Note 3.5 — 4.5 ⭐',
                  count: satisfaits.length,
                  color: AppColors.success,
                  clients: satisfaits,
                  cibleEmail: 'Réguliers',
                ),
                _SegmentCard(
                  icon: Icons.sentiment_neutral_outlined,
                  label: 'Neutres',
                  subtitle: 'Note 2.5 — 3.5 ⭐',
                  count: neutres.length,
                  color: AppColors.warning,
                  clients: neutres,
                  cibleEmail: 'Tous',
                ),
                _SegmentCard(
                  icon: Icons.sentiment_dissatisfied_outlined,
                  label: 'Insatisfaits',
                  subtitle: 'Note < 2.5 ⭐ — à relancer',
                  count: insatisfaits.length,
                  color: AppColors.error,
                  clients: insatisfaits,
                  cibleEmail: 'Inactifs',
                ),
                _SegmentCard(
                  icon: Icons.rate_review_outlined,
                  label: 'Sans avis',
                  subtitle: 'Demander un feedback',
                  count: sansAvis.length,
                  color: AppColors.textMedium,
                  clients: sansAvis,
                  cibleEmail: 'Tous',
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── WIDGETS ─────────────────────────────────────────────────────────────────

class _SegmentCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final int count;
  final Color color;
  final List<Client> clients;
  final String cibleEmail;

  const _SegmentCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.count,
    required this.color,
    required this.clients,
    required this.cibleEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$count',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
              const Icon(Icons.expand_more),
            ],
          ),
          children: [
            if (count == 0)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucun client dans ce segment',
                    style: TextStyle(color: AppColors.textLight)),
              )
            else ...[
              // Bouton action email
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEmailDialog(context),
                        icon: const Icon(Icons.email_outlined, size: 14),
                        label: Text('Envoyer email à $count client(s)',
                            style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                          side: BorderSide(color: color),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Liste des clients
              ...clients.take(5).map((c) => ListTile(
                dense: true,
                leading: ClientAvatar(nom: c.nomComplet, radius: 16),
                title: Text(c.nomComplet,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                subtitle: Text(c.telephone,
                    style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                trailing: Text(formatMontant(c.budgetMoyen),
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ClientDetailScreen(client: c))),
              )),
              if (count > 5)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: Text('+ ${count - 5} autres clients',
                        style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEmailDialog(BuildContext context) {
    final msgCtrl = TextEditingController(
      text: 'Bonjour [Nom],\n\nNous avons une offre spéciale pour vous !\n\nCordialement,\nDECO PAS PLUS',
    );
    final subCtrl = TextEditingController(text: 'Offre exclusive DECO PAS PLUS');
    bool sending = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Email au segment $label',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subCtrl,
                  decoration: const InputDecoration(labelText: 'Objet'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: msgCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Utilisez [Nom] pour personnaliser',
                  ),
                ),
                const SizedBox(height: 6),
                const Text('💡 [Nom] sera remplacé par le nom du client',
                    style: TextStyle(fontSize: 11, color: AppColors.textLight)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: sending ? null : () async {
                setS(() => sending = true);
                int envoyes = 0;
                for (final client in clients) {
                  if (client.email.contains('@')) {
                    final ok = await EmailService.sendEmail(
                      toEmail: client.email,
                      toName: client.nomComplet,
                      subject: subCtrl.text,
                      message: msgCtrl.text.replaceAll('[Nom]', client.nomComplet),
                    );
                    if (ok) envoyes++;
                    await Future.delayed(const Duration(milliseconds: 300));
                  }
                }
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('✅ $envoyes email(s) envoyé(s) au segment $label'),
                    backgroundColor: AppColors.success,
                  ));
                }
              },
              child: sending
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  final String ville;
  final int count;
  final double pct;
  final Color color;
  final List<Client> clients;

  const _ZoneCard({
    required this.ville, required this.count,
    required this.pct, required this.color, required this.clients,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.location_on_outlined, color: color, size: 18),
                const SizedBox(width: 8),
                Text(ville, style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
              ]),
              Text('$count client(s) — ${pct.toStringAsFixed(0)}%',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: color.withOpacity(0.1),
            color: color,
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
        ],
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatMini(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}
