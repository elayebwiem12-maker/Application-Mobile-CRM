// lib/screens/marketing_screen.dart — VERSION AMÉLIORÉE
// Améliorations :
//  + Détection automatique clients inactifs (CDC : Relances automatiques)
//  + Campagne anniversaire automatique (CDC : Promotions personnalisées)
//  + Affichage du nombre réel de destinataires par segment
//  + Relances planifiées listées et marquables comme effectuées
//  + Taux d'ouverture affiché sur chaque campagne

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../services/email_service.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';

class MarketingScreen extends StatefulWidget {
  const MarketingScreen({super.key});

  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Client> _inactifs = [];
  List<Client> _anniversaires = [];
  bool _loadingSegments = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadSegments();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSegments() async {
    final results = await Future.wait([
      FirebaseService.getClientsInactifs(mois: 3),
      FirebaseService.getClientsBirthdayThisMonth(),
    ]);
    setState(() {
      _inactifs = results[0] as List<Client>;
      _anniversaires = results[1] as List<Client>;
      _loadingSegments = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Marketing & Campagnes'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.flash_on_outlined), text: 'Actions'),
            Tab(icon: Icon(Icons.campaign_outlined), text: 'Campagnes'),
            Tab(icon: Icon(Icons.schedule_outlined), text: 'Relances'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildActionsTab(),
          _buildCampagnesTab(),
          _buildRelancesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCampagneForm(context),
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Nouvelle Campagne'),
      ),
    );
  }

  // ─── ONGLET ACTIONS RAPIDES ───────────────────────────────────────────────
  Widget _buildActionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Segments détectés automatiquement
        if (!_loadingSegments) ...[
          if (_inactifs.isNotEmpty)
            _SegmentAlert(
              icon: Icons.person_off_outlined,
              label: '${_inactifs.length} client(s) inactif(s) depuis 3 mois',
              color: AppColors.warning,
              onAction: () => _showCampagneForm(context,
                  cible: 'Inactifs',
                  nombreDest: _inactifs.length,
                  message:
                      'Bonjour ! Ça fait un moment qu\'on ne s\'est pas vus 😊 '
                      'Nous avons de nouvelles offres exclusives pour vous. '
                      'Contactez-nous pour en savoir plus !'),
            ),
          if (_anniversaires.isNotEmpty)
            _SegmentAlert(
              icon: Icons.cake_outlined,
              label:
                  '${_anniversaires.length} client(s) fête(nt) leur anniversaire ce mois',
              color: AppColors.success,
              onAction: () => _showCampagneForm(context,
                  cible: 'Anniversaires',
                  nombreDest: _anniversaires.length,
                  message:
                      'Joyeux anniversaire ! 🎂 Profitez de -10% sur votre '
                      'prochain événement ce mois-ci. Offre exclusive pour vous !'),
            ),
          const SizedBox(height: 16),
        ],

        const SectionHeader(title: 'Actions Rapides'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            _QuickAction(
              icon: Icons.person_off_outlined,
              label: 'Relancer inactifs',
              badge: _inactifs.isNotEmpty ? '${_inactifs.length}' : null,
              color: AppColors.warning,
              onTap: () => _showCampagneForm(context,
                  cible: 'Inactifs',
                  nombreDest: _inactifs.length,
                  message:
                      'Bonjour ! Ça fait un moment qu\'on ne s\'est pas vus 😊 '
                      'Nous avons de nouvelles offres pour vous !'),
            ),
            _QuickAction(
              icon: Icons.star_outline,
              label: 'Offre VIP',
              color: AppColors.gold,
              onTap: () => _showCampagneForm(context,
                  cible: 'VIP',
                  message:
                      'Chère cliente VIP, nous vous offrons -15% sur votre '
                      'prochain événement. Offre exclusive rien que pour vous ! 💎'),
            ),
            _QuickAction(
              icon: Icons.cake_outlined,
              label: 'Anniversaires',
              badge: _anniversaires.isNotEmpty ? '${_anniversaires.length}' : null,
              color: AppColors.success,
              onTap: () => _showCampagneForm(context,
                  cible: 'Anniversaires',
                  nombreDest: _anniversaires.length,
                  message:
                      'Joyeux anniversaire ! 🎂 -10% sur votre prochain événement.'),
            ),
            _QuickAction(
              icon: Icons.person_add_outlined,
              label: 'Bienvenue nouveaux',
              color: AppColors.info,
              onTap: () => _showCampagneForm(context,
                  cible: 'Nouveaux',
                  message:
                      'Bienvenue chez DECO PAS PLUS ! ✨ N\'hésitez pas à nous '
                      'contacter pour votre prochain événement.'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Modèles de messages
        const SectionHeader(title: 'Modèles de Messages'),
        const SizedBox(height: 10),
        ..._templates.map((t) => _TemplateCard(template: t)),
        const SizedBox(height: 80),
      ],
    );
  }

  // ─── ONGLET CAMPAGNES ─────────────────────────────────────────────────────
  Widget _buildCampagnesTab() {
    return StreamBuilder<List<Campagne>>(
      stream: FirebaseService.getCampagnes(),
      builder: (context, snap) {
        final campagnes = snap.data ?? [];
        if (campagnes.isEmpty) {
          return const EmptyState(
            icon: Icons.campaign_outlined,
            title: 'Aucune campagne',
            subtitle: 'Créez votre première campagne marketing',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: campagnes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _CampagneCard(campagne: campagnes[i]),
        );
      },
    );
  }

  // ─── ONGLET RELANCES (NOUVEAU) ────────────────────────────────────────────
  Widget _buildRelancesTab() {
    return StreamBuilder<List<Relance>>(
      stream: FirebaseService.getRelancesPlanifiees(),
      builder: (context, snap) {
        final relances = snap.data ?? [];
        if (relances.isEmpty) {
          return const EmptyState(
            icon: Icons.schedule_outlined,
            title: 'Aucune relance planifiée',
            subtitle: 'Les relances automatiques apparaîtront ici',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: relances.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _RelanceCard(
            relance: relances[i],
            onDone: () =>
                FirebaseService.marquerRelanceEffectuee(relances[i].id),
          ),
        );
      },
    );
  }

  void _showCampagneForm(BuildContext context,
      {String? cible, String? message, int? nombreDest}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CampagneForm(
          cibleInitiale: cible,
          messageInitial: message,
          nombreDestInitial: nombreDest),
    );
  }

  static final _templates = [
    _Template(
      titre: 'Confirmation de devis',
      canal: 'WhatsApp',
      message:
          'Bonjour [Nom], votre devis [N° Devis] a été préparé. Montant: [Montant] DT. '
          'Valable jusqu\'au [Date]. Contactez-nous pour toute question.',
    ),
    _Template(
      titre: 'Rappel événement J-7',
      canal: 'WhatsApp',
      message:
          'Bonjour [Nom] ! Votre [Type d\'événement] approche, rendez-vous le '
          '[Date] à [Lieu]. Notre équipe est prête ! 🎉',
    ),
    _Template(
      titre: 'Demande d\'avis post-événement',
      canal: 'WhatsApp',
      message:
          'Bonjour [Nom], votre événement s\'est bien passé ? 🌟 Nous serions '
          'ravis d\'avoir votre avis. Merci pour votre confiance !',
    ),
    _Template(
      titre: 'Relance devis expiré',
      canal: 'WhatsApp',
      message:
          'Bonjour [Nom], votre devis [N° Devis] est arrivé à expiration. '
          'Souhaitez-vous qu\'on le renouvelle ? Nous restons disponibles ! 😊',
    ),
  ];
}

// ─── WIDGETS ─────────────────────────────────────────────────────────────────

class _SegmentAlert extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onAction;

  const _SegmentAlert({
    required this.icon,
    required this.label,
    required this.color,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
            child: const Text('Envoyer', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text(badge!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CampagneCard extends StatelessWidget {
  final Campagne campagne;
  const _CampagneCard({required this.campagne});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
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
          Row(
            children: [
              Expanded(
                child: Text(campagne.titre,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textDark)),
              ),
              TypeChip(label: campagne.statut),
            ],
          ),
          const SizedBox(height: 6),
          Text(campagne.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textMedium)),
          const SizedBox(height: 8),
          Row(
            children: [
              _Info(Icons.people_outline, '${campagne.nombreDestinataires} dest.'),
              const SizedBox(width: 12),
              _Info(Icons.campaign_outlined, campagne.cible),
              const SizedBox(width: 12),
              _Info(Icons.message_outlined, campagne.canal),
              const Spacer(),
              Text(formatDate(campagne.datePrevue),
                  style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
            ],
          ),
          // Taux d'ouverture affiché si campagne envoyée
          if (campagne.statut == 'Envoyée' && campagne.nombreDestinataires > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: campagne.nombreDestinataires > 0
                        ? campagne.nombreOuvertures / campagne.nombreDestinataires
                        : 0,
                    backgroundColor: AppColors.primaryLight.withOpacity(0.3),
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${campagne.tauxOuverture.toStringAsFixed(0)}% ouvert',
                  style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RelanceCard extends StatelessWidget {
  final Relance relance;
  final VoidCallback onDone;

  const _RelanceCard({required this.relance, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final isUrgent = relance.datePrevue.isBefore(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isUrgent
                ? AppColors.error.withOpacity(0.4)
                : AppColors.primaryLight.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isUrgent ? AppColors.error : AppColors.warning)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: isUrgent ? AppColors.error : AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(relance.clientNom,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(_motifLabel(relance.motif),
                    style: const TextStyle(
                        color: AppColors.textMedium, fontSize: 12)),
                Text(
                  isUrgent
                      ? '⚠ Était prévu le ${formatDate(relance.datePrevue)}'
                      : 'Prévu le ${formatDate(relance.datePrevue)}',
                  style: TextStyle(
                      color: isUrgent ? AppColors.error : AppColors.textLight,
                      fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline,
                color: AppColors.success),
            onPressed: onDone,
            tooltip: 'Marquer comme effectuée',
          ),
        ],
      ),
    );
  }

  String _motifLabel(String motif) {
    switch (motif) {
      case 'devis_en_attente':
        return 'Devis en attente de réponse';
      case 'client_inactif':
        return 'Client inactif depuis 3+ mois';
      case 'anniversaire_event':
        return 'Anniversaire de l\'événement';
      default:
        return motif;
    }
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Info(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 12, color: AppColors.textLight),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
      ]);
}

class _Template {
  final String titre;
  final String message;
  final String canal;
  const _Template({required this.titre, required this.message, required this.canal});
}

class _TemplateCard extends StatelessWidget {
  final _Template template;
  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryLight.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.message_outlined,
                color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.titre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textDark)),
                Text(template.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textLight)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined,
                size: 16, color: AppColors.primary),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: template.message));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Message copié dans le presse-papiers'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CampagneForm extends StatefulWidget {
  final String? cibleInitiale;
  final String? messageInitial;
  final int? nombreDestInitial;

  const _CampagneForm({
    this.cibleInitiale,
    this.messageInitial,
    this.nombreDestInitial,
  });

  @override
  State<_CampagneForm> createState() => _CampagneFormState();
}

class _CampagneFormState extends State<_CampagneForm> {
  final _titreCtrl = TextEditingController();
  late TextEditingController _messageCtrl;
  final _subjectCtrl = TextEditingController(text: 'Message de DECO PAS PLUS');
  String _cible = 'Tous';
  String _canal = 'Email'; // Email par défaut
  bool _loading = false;
  String _loadingMsg = '';

  final _cibles = ['Tous', 'VIP', 'Nouveaux', 'Inactifs', 'Réguliers', 'Anniversaires'];
  final _canaux = ['Email', 'WhatsApp', 'SMS'];

  @override
  void initState() {
    super.initState();
    if (widget.cibleInitiale != null) _cible = widget.cibleInitiale!;
    _messageCtrl = TextEditingController(text: widget.messageInitial ?? '');
  }

  @override
  void dispose() {
    _titreCtrl.dispose();
    _messageCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titreCtrl.text.isEmpty || _messageCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Remplissez le titre et le message'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    setState(() { _loading = true; _loadingMsg = 'Préparation...'; });

    try {
      // 1. Sauvegarder la campagne
      final c = Campagne(
        id: const Uuid().v4(),
        titre: _titreCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        cible: _cible,
        canal: _canal,
        datePrevue: DateTime.now(),
        nombreDestinataires: widget.nombreDestInitial ?? 0,
      );
      await FirebaseService.ajouterCampagne(c);

      // 2. Si Email → envoyer via EmailJS
      if (_canal == 'Email') {
        setState(() => _loadingMsg = 'Envoi des emails...');
        final result = await EmailService.envoyerCampagne(
          cible: _cible,
          subject: _subjectCtrl.text.trim(),
          message: _messageCtrl.text.trim(),
        );
        // Mettre à jour le statut
        await FirebaseService.db
            .collection('campagnes')
            .doc(c.id)
            .update({
          'nombreDestinataires': result.envoyes,
          'statut': result.envoyes > 0 ? 'Envoyée' : 'Échouée',
        });

        if (mounted) {
          Navigator.pop(context);
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Row(children: [
                Icon(result.envoyes > 0 ? Icons.check_circle : Icons.warning,
                    color: result.envoyes > 0 ? AppColors.success : AppColors.warning),
                const SizedBox(width: 8),
                const Text('Résultat', style: TextStyle(fontWeight: FontWeight.bold)),
              ]),
              content: Text(result.summary),
              actions: [ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              )],
            ),
          );
        }
      } else {
        // WhatsApp / SMS → juste sauvegarder
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Campagne $_canal créée. Envoi manuel requis.'),
            backgroundColor: AppColors.info,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          const Text('Nouvelle Campagne',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.textDark)),
          if (widget.nombreDestInitial != null && widget.nombreDestInitial! > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${widget.nombreDestInitial} destinataire(s) identifié(s)',
                style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _titreCtrl,
            decoration: const InputDecoration(
              labelText: 'Titre de la campagne',
              prefixIcon: Icon(Icons.title, color: AppColors.primary, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _cible,
                  items: _cibles
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _cible = v!),
                  decoration: const InputDecoration(labelText: 'Cible'),
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _canal,
                  items: _canaux
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _canal = v!),
                  decoration: const InputDecoration(labelText: 'Canal'),
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_canal == 'Email') ...[
            TextField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(
                labelText: 'Objet de l\'email',
                prefixIcon: Icon(Icons.subject,
                    color: AppColors.primary, size: 18),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _messageCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Message',
              hintText: _canal == 'Email'
                  ? 'Utilisez [Nom] pour personnaliser (ex: Bonjour [Nom])'
                  : 'Votre message...',
              prefixIcon: const Icon(Icons.message_outlined,
                  color: AppColors.primary, size: 18),
              alignLabelWithHint: true,
            ),
          ),
          if (_canal == 'Email')
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '💡 [Nom] sera remplacé par le nom de chaque client',
                style: TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2)),
                        const SizedBox(width: 10),
                        Text(_loadingMsg),
                      ],
                    )
                  : Text(_canal == 'Email'
                      ? '📧 Envoyer la campagne'
                      : 'Créer la campagne'),
            ),
          ),
        ],
      ),
    );
  }
}
