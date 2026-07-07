// lib/screens/devis_screen.dart — VERSION AMÉLIORÉE
// Améliorations :
//  + Numéro de devis lisible DEV-YYYY-NNN (au lieu d'UUID brut)
//  + Champ TVA (0% particuliers, 19% entreprises)
//  + Bouton "Envoyer" qui enregistre dateEnvoi
//  + Badge devis expiré visible
//  + Conversion en commande avec confirmation

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/pdf_devis_service.dart';

class DevisScreen extends StatefulWidget {
  const DevisScreen({super.key});

  @override
  State<DevisScreen> createState() => _DevisScreenState();
}

class _DevisScreenState extends State<DevisScreen> {
  String _filterStatut = 'Tous';
  final _statuts = ['Tous', 'Brouillon', 'Envoyé', 'Accepté', 'Refusé', 'Expiré'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Devis & Commandes')),
      body: Column(
        children: [
          // Filtres
          Container(
            height: 50,
            color: AppColors.surface,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _statuts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _statuts[i];
                final selected = _filterStatut == s;
                return GestureDetector(
                  onTap: () => setState(() => _filterStatut = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.primaryLight,
                      ),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.textMedium,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Devis>>(
              stream: FirebaseService.getDevis(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary));
                }
                var devisList = snap.data ?? [];

                // Marquer automatiquement les devis expirés
                final now = DateTime.now();
                devisList = devisList.map((d) {
                  if ((d.statut == 'Envoyé' || d.statut == 'Brouillon') &&
                      d.dateExpiration.isBefore(now)) {
                    return Devis(
                      id: d.id,
                      numeroDevis: d.numeroDevis,
                      clientId: d.clientId,
                      clientNom: d.clientNom,
                      lignes: d.lignes,
                      sousTotal: d.sousTotal,
                      remise: d.remise,
                      tva: d.tva,
                      total: d.total,
                      statut: 'Expiré',
                      dateCreation: d.dateCreation,
                      dateEnvoi: d.dateEnvoi,
                      dateExpiration: d.dateExpiration,
                      notes: d.notes,
                    );
                  }
                  return d;
                }).toList();

                if (_filterStatut != 'Tous') {
                  devisList =
                      devisList.where((d) => d.statut == _filterStatut).toList();
                }

                if (devisList.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Aucun devis',
                    subtitle: 'Créez votre premier devis',
                    buttonLabel: 'Nouveau devis',
                    onButton: () => _showDevisForm(context),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: devisList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _DevisCard(
                    devis: devisList[i],
                    onStatutChanged: (statut) =>
                        FirebaseService.modifierStatutDevis(devisList[i].id, statut),
                    onConvertir: () => _confirmerConversion(context, devisList[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDevisForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau Devis'),
      ),
    );
  }

  void _showDevisForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DevisFormScreen()),
    );
  }

  Future<void> _confirmerConversion(BuildContext context, Devis devis) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Convertir en commande',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Convertir le devis ${devis.numeroDevis.isNotEmpty ? devis.numeroDevis : "#${devis.id.substring(0, 6).toUpperCase()}"} '
            'de ${formatMontant(devis.total)} en commande confirmée ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseService.convertirEnCommande(devis.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Devis converti en commande ✓'),
          backgroundColor: AppColors.success,
        ));
      }
    }
  }
}

class _DevisCard extends StatelessWidget {
  final Devis devis;
  final void Function(String) onStatutChanged;
  final VoidCallback onConvertir;

  const _DevisCard({
    required this.devis,
    required this.onStatutChanged,
    required this.onConvertir,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = devis.statut == 'Expiré';
    final numero = devis.numeroDevis.isNotEmpty
        ? devis.numeroDevis
        : '#${devis.id.substring(0, 6).toUpperCase()}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isExpired
            ? Border.all(color: AppColors.error.withOpacity(0.4))
            : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: isExpired
                      ? const LinearGradient(
                          colors: [AppColors.error, AppColors.warning])
                      : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      numero,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textDark),
                    ),
                    Text(
                      devis.clientNom,
                      style: const TextStyle(
                          color: AppColors.textMedium, fontSize: 13),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showStatutPicker(context),
                child: TypeChip(label: devis.statut),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _Detail(Icons.calendar_today_outlined,
                  'Créé le ${formatDate(devis.dateCreation)}'),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formatMontant(devis.total),
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ],
          ),
          if (devis.tva > 0) ...[
            const SizedBox(height: 4),
            Text(
              'TTC : ${formatMontant(devis.totalTTC)} (TVA ${devis.tva.toStringAsFixed(0)}%)',
              style: const TextStyle(
                  color: AppColors.textLight, fontSize: 11),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (isExpired)
                _Detail(Icons.warning_amber_outlined,
                    'Expiré le ${formatDate(devis.dateExpiration)}')
              else
                _Detail(Icons.timer_outlined,
                    'Valable jusqu\'au ${formatDate(devis.dateExpiration)}'),
              if (devis.dateEnvoi != null) ...[
                const SizedBox(width: 12),
                _Detail(Icons.send_outlined,
                    'Envoyé le ${formatDate(devis.dateEnvoi!)}'),
              ],
            ],
          ),
          // Boutons d'action
          if (devis.statut != 'Accepté' && devis.statut != 'Refusé') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (devis.statut == 'Brouillon' || devis.statut == 'Expiré')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onStatutChanged('Envoyé'),
                      icon: const Icon(Icons.send_outlined, size: 14),
                      label: const Text('Envoyer', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                if (devis.statut == 'Envoyé') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onConvertir,
                      icon: const Icon(Icons.check_circle_outline, size: 14),
                      label: const Text('Accepter', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onStatutChanged('Refusé'),
                      icon: const Icon(Icons.cancel_outlined, size: 14),
                      label: const Text('Refuser', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          // BOUTON PDF / PARTAGER — NOUVEAU
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _partagerDevis(context),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
              label: const Text('Générer PDF & Partager',
                  style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: BorderSide(color: AppColors.primaryDark.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          if (devis.converti)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 14),
                  SizedBox(width: 6),
                  Text('Converti en commande',
                      style: TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _partagerDevis(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text('Génération du PDF...'),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      await PdfDevisService.partagerPDF(devis);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _showStatutPicker(BuildContext context) {
    final statuts = ['Brouillon', 'Envoyé', 'Accepté', 'Refusé'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Changer le statut',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textDark)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: statuts.map((s) {
                return GestureDetector(
                  onTap: () {
                    onStatutChanged(s);
                    Navigator.pop(context);
                  },
                  child: TypeChip(label: s),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Detail(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 13, color: AppColors.textLight),
        const SizedBox(width: 4),
        Text(text,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textMedium)),
      ]);
}

// ─── FORMULAIRE DEVIS ─────────────────────────────────────────────────────────
class DevisFormScreen extends StatefulWidget {
  final String? clientId;
  final String? clientNom;

  const DevisFormScreen({super.key, this.clientId, this.clientNom});

  @override
  State<DevisFormScreen> createState() => _DevisFormScreenState();
}

class _DevisFormScreenState extends State<DevisFormScreen> {
  final _clientNomCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<LigneDevis> _lignes = [];
  double _remise = 0;
  double _tva = 0;
  DateTime _dateExpiration =
      DateTime.now().add(const Duration(days: 15));
  bool _loading = false;

  double get _sousTotal =>
      _lignes.fold(0, (s, l) => s + l.total);
  double get _total => _sousTotal * (1 - _remise / 100);
  double get _totalTTC => _total * (1 + _tva / 100);

  @override
  void initState() {
    super.initState();
    if (widget.clientNom != null) _clientNomCtrl.text = widget.clientNom!;
  }

  @override
  void dispose() {
    _clientNomCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _ajouterLigne() async {
    final ligne = await showDialog<LigneDevis>(
      context: context,
      builder: (_) => const _LigneDialog(),
    );
    if (ligne != null) setState(() => _lignes.add(ligne));
  }

  Future<void> _submit() async {
    if (_clientNomCtrl.text.isEmpty || _lignes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ajoutez au moins une ligne et un client'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _loading = true);
    try {
      final numero = await FirebaseService.generateNumeroDevis();
      final devis = Devis(
        id: const Uuid().v4(),
        numeroDevis: numero,
        clientId: widget.clientId ?? '',
        clientNom: _clientNomCtrl.text.trim(),
        lignes: _lignes,
        sousTotal: _sousTotal,
        remise: _remise,
        tva: _tva,
        total: _total,
        statut: 'Brouillon',
        dateCreation: DateTime.now(),
        dateExpiration: _dateExpiration,
        notes: _notesCtrl.text.trim(),
      );
      await FirebaseService.ajouterDevis(devis);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Devis $numero créé avec succès'),
          backgroundColor: AppColors.success,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nouveau Devis')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Client
              _section('Client', [
                TextField(
                  controller: _clientNomCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom du client',
                    prefixIcon: Icon(Icons.person_outline,
                        color: AppColors.primary, size: 18),
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // Lignes
              _section('Prestations', [
                ..._lignes.asMap().entries.map((e) => _LigneTile(
                      ligne: e.value,
                      onDelete: () =>
                          setState(() => _lignes.removeAt(e.key)),
                    )),
                TextButton.icon(
                  onPressed: _ajouterLigne,
                  icon: const Icon(Icons.add, color: AppColors.primary),
                  label: const Text('Ajouter une prestation',
                      style: TextStyle(color: AppColors.primary)),
                ),
              ]),
              const SizedBox(height: 14),

              // Totaux
              _section('Récapitulatif', [
                _TotalRow('Sous-total', _sousTotal),
                if (_remise > 0)
                  _TotalRow('Remise (${_remise.toStringAsFixed(0)}%)',
                      -_sousTotal * _remise / 100),
                _buildRemiseSlider(),
                if (_tva > 0) _TotalRow('TVA (${_tva.toStringAsFixed(0)}%)',
                    _total * _tva / 100),
                _buildTVAToggle(),
                const Divider(),
                _TotalRow('TOTAL HT', _total, bold: true),
                if (_tva > 0) _TotalRow('TOTAL TTC', _totalTTC, bold: true),
              ]),
              const SizedBox(height: 14),

              // Options
              _section('Options', [
                // Date expiration
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dateExpiration,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 90)),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.light(
                              primary: AppColors.primary),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null)
                      setState(() => _dateExpiration = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Date d\'expiration',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textLight)),
                            Text(formatDate(_dateExpiration),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark)),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.edit_outlined,
                            color: AppColors.primary, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optionnel)',
                    prefixIcon: Icon(Icons.notes_outlined,
                        color: AppColors.primary, size: 18),
                    alignLabelWithHint: true,
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Créer le devis',
                        style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 40),
            ],
          ),
          if (_loading) const LoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildRemiseSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Remise',
                style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
            Text('${_remise.toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 12)),
          ],
        ),
        Slider(
          value: _remise,
          min: 0,
          max: 30,
          divisions: 30,
          activeColor: AppColors.primary,
          inactiveColor: AppColors.primaryLight,
          onChanged: (v) => setState(() => _remise = v),
        ),
      ],
    );
  }

  Widget _buildTVAToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('TVA 19% (entreprises)',
            style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
        Switch(
          value: _tva > 0,
          activeColor: AppColors.primary,
          onChanged: (v) => setState(() => _tva = v ? 19 : 0),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primaryDark)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double montant;
  final bool bold;

  const _TotalRow(this.label, this.montant, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 14 : 12,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal,
                  color:
                      bold ? AppColors.textDark : AppColors.textMedium)),
          Text(
            formatMontant(montant.abs()),
            style: TextStyle(
                fontSize: bold ? 15 : 12,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
                color: bold
                    ? AppColors.primary
                    : montant < 0
                        ? AppColors.success
                        : AppColors.textDark),
          ),
        ],
      ),
    );
  }
}

class _LigneTile extends StatelessWidget {
  final LigneDevis ligne;
  final VoidCallback onDelete;

  const _LigneTile({required this.ligne, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryLight.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ligne.description,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: AppColors.textDark)),
                Text(
                  '${ligne.quantite} ${ligne.unite} × ${formatMontant(ligne.prixUnitaire)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          Text(formatMontant(ligne.total),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 13)),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _LigneDialog extends StatefulWidget {
  const _LigneDialog();

  @override
  State<_LigneDialog> createState() => _LigneDialogState();
}

class _LigneDialogState extends State<_LigneDialog> {
  final _descCtrl = TextEditingController();
  final _qteCtrl = TextEditingController(text: '1');
  final _prixCtrl = TextEditingController();
  String _unite = 'unité';

  final _unites = ['unité', 'heure', 'forfait', 'pièce'];

  @override
  void dispose() {
    _descCtrl.dispose();
    _qteCtrl.dispose();
    _prixCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qte = int.tryParse(_qteCtrl.text) ?? 1;
    final prix = double.tryParse(_prixCtrl.text) ?? 0;
    final total = qte * prix;

    return AlertDialog(
      title: const Text('Ajouter une prestation',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description_outlined,
                    color: AppColors.primary, size: 16),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qteCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Qté'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _unite,
                    items: _unites
                        .map((u) =>
                            DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _unite = v!),
                    decoration: const InputDecoration(labelText: 'Unité'),
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(
                        color: AppColors.textDark, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _prixCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Prix unitaire (DT)',
                prefixIcon: Icon(Icons.payments_outlined,
                    color: AppColors.primary, size: 16),
              ),
            ),
            if (total > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Total : ',
                        style: TextStyle(
                            color: AppColors.textMedium, fontSize: 13)),
                    Text(formatMontant(total),
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_descCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('⚠️ Veuillez entrer une description'),
                backgroundColor: AppColors.error,
              ));
              return;
            }
            if (prix <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('⚠️ Le prix doit être supérieur à 0'),
                backgroundColor: AppColors.error,
              ));
              return;
            }
            Navigator.pop(
              context,
              LigneDevis(
                description: _descCtrl.text.trim(),
                quantite: qte,
                prixUnitaire: prix,
                total: total,
                unite: _unite,
              ),
            );
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}