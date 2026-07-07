// lib/screens/paiement_screen.dart — NOUVEAU
// Suivi des paiements clients
// Statut: Payé / Partiel / Impayé + montant reçu + solde restant
 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';
 
// ─── MODÈLE PAIEMENT ─────────────────────────────────────────────────────────
class Paiement {
  final String id;
  final String clientId;
  final String clientNom;
  final String devisId;
  final String evenementId;
  final double montantTotal;
  final double montantRecu;
  final String statut; // 'Payé', 'Partiel', 'Impayé'
  final DateTime dateCreation;
  final List<Map<String, dynamic>> versements;
  final String notes;
 
  Paiement({
    required this.id,
    required this.clientId,
    required this.clientNom,
    this.devisId = '',
    this.evenementId = '',
    required this.montantTotal,
    this.montantRecu = 0,
    this.statut = 'Impayé',
    required this.dateCreation,
    this.versements = const [],
    this.notes = '',
  });
 
  double get soldeRestant => montantTotal - montantRecu;
  double get pourcentagePaye =>
      montantTotal > 0 ? (montantRecu / montantTotal).clamp(0, 1) : 0;
 
  factory Paiement.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Paiement(
      id: doc.id,
      clientId: d['clientId'] ?? '',
      clientNom: d['clientNom'] ?? '',
      devisId: d['devisId'] ?? '',
      evenementId: d['evenementId'] ?? '',
      montantTotal: (d['montantTotal'] ?? 0).toDouble(),
      montantRecu: (d['montantRecu'] ?? 0).toDouble(),
      statut: d['statut'] ?? 'Impayé',
      dateCreation: (d['dateCreation'] as Timestamp).toDate(),
      versements: List<Map<String, dynamic>>.from(d['versements'] ?? []),
      notes: d['notes'] ?? '',
    );
  }
 
  Map<String, dynamic> toFirestore() => {
    'clientId': clientId,
    'clientNom': clientNom,
    'devisId': devisId,
    'evenementId': evenementId,
    'montantTotal': montantTotal,
    'montantRecu': montantRecu,
    'statut': statut,
    'dateCreation': Timestamp.fromDate(dateCreation),
    'versements': versements,
    'notes': notes,
  };
}
 
// ─── SCREEN PAIEMENTS ─────────────────────────────────────────────────────────
class PaiementScreen extends StatefulWidget {
  const PaiementScreen({super.key});
 
  @override
  State<PaiementScreen> createState() => _PaiementScreenState();
}
 
class _PaiementScreenState extends State<PaiementScreen> {
  String _filtre = 'Tous';
  final _filtres = ['Tous', 'Impayé', 'Partiel', 'Payé'];
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Suivi des Paiements')),
      body: Column(
        children: [
          // Filtres statut
          Container(
            height: 50,
            color: AppColors.surface,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filtres.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filtres[i];
                final sel = _filtre == f;
                return GestureDetector(
                  onTap: () => setState(() => _filtre = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? _statutColor(f) : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? _statutColor(f) : AppColors.primaryLight),
                    ),
                    child: Text(f,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : AppColors.textMedium)),
                  ),
                );
              },
            ),
          ),
          // Résumé KPI
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('paiements')
                .snapshots(),
            builder: (context, snap) {
              final paiements = snap.data?.docs
                  .map((d) => Paiement.fromFirestore(d))
                  .toList() ?? [];
              final totalDu = paiements.fold(
                  0.0, (s, p) => s + p.montantTotal);
              final totalRecu = paiements.fold(
                  0.0, (s, p) => s + p.montantRecu);
              final totalRestant = totalDu - totalRecu;
              return Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: _KpiMini(
                        'Total dû', formatMontant(totalDu),
                        AppColors.textDark)),
                    Expanded(child: _KpiMini(
                        'Reçu', formatMontant(totalRecu),
                        AppColors.success)),
                    Expanded(child: _KpiMini(
                        'Restant', formatMontant(totalRestant),
                        AppColors.error)),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('paiements')
                  .orderBy('dateCreation', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }
                var paiements = snap.data!.docs
                    .map((d) => Paiement.fromFirestore(d))
                    .toList();
                if (_filtre != 'Tous') {
                  paiements = paiements
                      .where((p) => p.statut == _filtre)
                      .toList();
                }
                if (paiements.isEmpty) {
                  return EmptyState(
                    icon: Icons.payment_outlined,
                    title: 'Aucun paiement',
                    subtitle: 'Ajoutez un paiement depuis un devis',
                    buttonLabel: 'Nouveau paiement',
                    onButton: () => _showForm(context),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: paiements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _PaiementCard(
                    paiement: paiements[i],
                    onVersement: () =>
                        _showVersementDialog(context, paiements[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau paiement'),
      ),
    );
  }
 
  Color _statutColor(String statut) {
    switch (statut) {
      case 'Payé': return AppColors.success;
      case 'Partiel': return AppColors.warning;
      case 'Impayé': return AppColors.error;
      default: return AppColors.primary;
    }
  }
 
  void _showForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _PaiementForm(),
    );
  }
 
  void _showVersementDialog(BuildContext context, Paiement p) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Versement — ${p.clientNom}',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Solde restant: ${formatMontant(p.soldeRestant)}',
                style: const TextStyle(color: AppColors.error,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant reçu (DT)',
                prefixIcon: Icon(Icons.payments_outlined,
                    color: AppColors.primary, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final montant = double.tryParse(ctrl.text) ?? 0;
              if (montant <= 0) return;
              final nouveauRecu = p.montantRecu + montant;
              final statut = nouveauRecu >= p.montantTotal
                  ? 'Payé'
                  : 'Partiel';
              final versements = [...p.versements, {
                'montant': montant,
                'date': Timestamp.now(),
              }];
              await FirebaseFirestore.instance
                  .collection('paiements')
                  .doc(p.id)
                  .update({
                'montantRecu': nouveauRecu,
                'statut': statut,
                'versements': versements,
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
 
// ─── CARTE PAIEMENT ───────────────────────────────────────────────────────────
class _PaiementCard extends StatelessWidget {
  final Paiement paiement;
  final VoidCallback onVersement;
 
  const _PaiementCard({required this.paiement, required this.onVersement});
 
  Color get _color {
    switch (paiement.statut) {
      case 'Payé': return AppColors.success;
      case 'Partiel': return AppColors.warning;
      default: return AppColors.error;
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: _color, width: 4)),
        boxShadow: [BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClientAvatar(nom: paiement.clientNom, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(paiement.clientNom, style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(formatDate(paiement.dateCreation),
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(paiement.statut,
                    style: TextStyle(color: _color,
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barre de progression paiement
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Reçu: ${formatMontant(paiement.montantRecu)}',
                  style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
              Text('Restant: ${formatMontant(paiement.soldeRestant)}',
                  style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: paiement.pourcentagePaye,
            backgroundColor: AppColors.error.withOpacity(0.2),
            color: _color,
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(paiement.pourcentagePaye * 100).toStringAsFixed(0)}% payé',
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 11)),
              Text('Total: ${formatMontant(paiement.montantTotal)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          // Historique versements
          if (paiement.versements.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Versements:',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textLight)),
            ...paiement.versements.map((v) {
              final date = (v['date'] as Timestamp).toDate();
              return Text(
                '• ${formatMontant((v['montant'] as num).toDouble())} — ${formatDate(date)}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMedium),
              );
            }),
          ],
          if (paiement.statut != 'Payé') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onVersement,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Enregistrer un versement',
                    style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
 
// ─── FORMULAIRE NOUVEAU PAIEMENT ─────────────────────────────────────────────
class _PaiementForm extends StatefulWidget {
  const _PaiementForm();
 
  @override
  State<_PaiementForm> createState() => _PaiementFormState();
}
 
class _PaiementFormState extends State<_PaiementForm> {
  final _clientCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _recuCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _loading = false;
 
  @override
  void dispose() {
    _clientCtrl.dispose();
    _totalCtrl.dispose();
    _recuCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }
 
  Future<void> _submit() async {
    if (_clientCtrl.text.isEmpty || _totalCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    final total = double.tryParse(_totalCtrl.text) ?? 0;
    final recu = double.tryParse(_recuCtrl.text) ?? 0;
    String statut = 'Impayé';
    if (recu >= total) statut = 'Payé';
    else if (recu > 0) statut = 'Partiel';
 
    final p = Paiement(
      id: const Uuid().v4(),
      clientNom: _clientCtrl.text.trim(),
      clientId: '',
      montantTotal: total,
      montantRecu: recu,
      statut: statut,
      dateCreation: DateTime.now(),
      versements: recu > 0 ? [{'montant': recu, 'date': Timestamp.now()}] : [],
      notes: _notesCtrl.text.trim(),
    );
    await FirebaseFirestore.instance
        .collection('paiements')
        .doc(p.id)
        .set(p.toFirestore());
    if (mounted) Navigator.pop(context);
  }
 
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nouveau Paiement', style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18,
              color: AppColors.textDark)),
          const SizedBox(height: 16),
          TextField(
            controller: _clientCtrl,
            decoration: const InputDecoration(
              labelText: 'Nom du client',
              prefixIcon: Icon(Icons.person_outline,
                  color: AppColors.primary, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(
              controller: _totalCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Montant total (DT)'),
            )),
            const SizedBox(width: 10),
            Expanded(child: TextField(
              controller: _recuCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Montant reçu (DT)'),
            )),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes (optionnel)',
              prefixIcon: Icon(Icons.notes_outlined,
                  color: AppColors.primary, size: 18),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Enregistrer'),
            ),
          ),
        ],
      ),
    );
  }
}
 
class _KpiMini extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiMini(this.label, this.value, this.color);
 
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      Text(label, style: const TextStyle(
          fontSize: 10, color: AppColors.textLight)),
    ],
  );
}