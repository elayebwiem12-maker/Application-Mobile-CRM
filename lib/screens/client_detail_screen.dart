// lib/screens/client_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';
import 'client_form_screen.dart';
import 'evenement_form_screen.dart';
import 'devis_screen.dart';

class ClientDetailScreen extends StatelessWidget {
  final Client client;
  const ClientDetailScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildInfoCard(),
                const SizedBox(height: 14),
                _buildActionButtons(context), // context passed correctly
                const SizedBox(height: 20),
                _buildEvenementsSection(context),
                const SizedBox(height: 20),
                _buildDevisSection(context),
                const SizedBox(height: 20),
                _buildMessagesSection(context),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              ClientAvatar(
                  nom: client.nomComplet, photoUrl: client.photoUrl, radius: 40),
              const SizedBox(height: 10),
              Text(
                client.nomComplet,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TypeChip(label: client.typeClient),
                  const SizedBox(width: 8),
                  if (client.sourceAcquisition.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        client.sourceAcquisition,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientFormScreen(client: client),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoRow(Icons.phone_outlined, 'Téléphone', client.telephone),
          if (client.email.isNotEmpty)
            _InfoRow(Icons.email_outlined, 'Email', client.email),
          if (client.ville.isNotEmpty)
            _InfoRow(Icons.location_on_outlined, 'Ville', client.ville),
          if (client.adresse.isNotEmpty)
            _InfoRow(Icons.home_outlined, 'Adresse', client.adresse),
          _InfoRow(
            Icons.calendar_today_outlined,
            'Client depuis',
            formatDate(client.dateCreation),
          ),
          _InfoRow(Icons.event_outlined, 'Événements',
              '${client.nombreEvenements}'),
          _InfoRow(Icons.payments_outlined, 'Budget moyen',
              formatMontant(client.budgetMoyen)),
          if (client.notes.isNotEmpty)
            _InfoRow(Icons.notes_outlined, 'Notes', client.notes),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext ctx) {
    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            icon: Icons.phone,
            label: 'Appeler',
            color: AppColors.success,
            onTap: () => _call(client.telephone),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionBtn(
            icon: Icons.message,
            label: 'WhatsApp',
            color: const Color(0xFF25D366),
            onTap: () => _whatsApp(client.telephone, client.nomComplet),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionBtn(
            icon: Icons.event_note,
            label: 'Événement',
            color: AppColors.info,
            onTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => EvenementFormScreen(
                  clientId: client.id,
                  clientNom: client.nomComplet,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEvenementsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(title: 'Événements'),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EvenementFormScreen(
                    clientId: client.id,
                    clientNom: client.nomComplet,
                  ),
                ),
              ),
              icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
              label: const Text('Ajouter',
                  style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Evenement>>(
          stream: FirebaseService.getEvenementsByClient(client.id),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final evens = snap.data!;
            if (evens.isEmpty) {
              return const EmptyState(
                icon: Icons.event_busy,
                title: 'Aucun événement',
              );
            }
            return Column(
              children: evens.map((e) => _EvenementMiniCard(e)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDevisSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(title: 'Devis & Commandes'),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DevisFormScreen(
                    clientId: client.id,
                    clientNom: client.nomComplet,
                  ),
                ),
              ),
              icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
              label: const Text('Nouveau devis',
                  style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Devis>>(
          stream: FirebaseService.getDevisByClient(client.id),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final devisList = snap.data!;
            if (devisList.isEmpty) {
              return const EmptyState(
                  icon: Icons.receipt_long, title: 'Aucun devis');
            }
            return Column(
              children: devisList.map((d) => _DevisMiniCard(d)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMessagesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Historique Messages'),
        const SizedBox(height: 8),
        StreamBuilder<List<Message>>(
          stream: FirebaseService.getMessagesByClient(client.id),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final msgs = snap.data!;
            if (msgs.isEmpty) {
              return const EmptyState(
                  icon: Icons.chat_bubble_outline, title: 'Aucun message');
            }
            return Column(
              children: msgs.take(5).map((m) => _MessageMiniCard(m)).toList(),
            );
          },
        ),
      ],
    );
  }

  // ─── FONCTIONS APPEL & WHATSAPP ───────────────────────────────────────────

  void _call(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _whatsApp(String phone, String nom) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    final number = cleaned.startsWith('216') ? cleaned : '216$cleaned';
    final msg = Uri.encodeComponent(
      'Bonjour $nom ! 😊 Merci de nous contacter chez DECO PAS PLUS.',
    );
    final uri = Uri.parse('https://wa.me/$number?text=$msg');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

// ─── WIDGETS INTERNES ─────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 12),
          Text('$label :',
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _EvenementMiniCard extends StatelessWidget {
  final Evenement e;
  const _EvenementMiniCard(this.e);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryLight.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.typeEvenement,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${formatDate(e.date)} — ${e.lieu}',
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TypeChip(label: e.statut),
              const SizedBox(height: 4),
              Text(formatMontant(e.budget),
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DevisMiniCard extends StatelessWidget {
  final Devis d;
  const _DevisMiniCard(this.d);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryLight.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.numeroDevis.isNotEmpty
                      ? d.numeroDevis
                      : 'Devis #${d.id.substring(0, 6).toUpperCase()}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(formatDate(d.dateCreation),
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TypeChip(label: d.statut),
              const SizedBox(height: 4),
              Text(formatMontant(d.total),
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageMiniCard extends StatelessWidget {
  final Message m;
  const _MessageMiniCard(this.m);

  @override
  Widget build(BuildContext context) {
    final isOut = m.direction == 'Sortant';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOut
            ? AppColors.primary.withOpacity(0.07)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isOut
                ? AppColors.primary.withOpacity(0.2)
                : AppColors.primaryLight.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            m.canal == 'WhatsApp' ? Icons.message : Icons.email_outlined,
            size: 14,
            color: isOut ? AppColors.primary : AppColors.textLight,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.contenu,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(formatDateHeure(m.date),
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 10)),
              ],
            ),
          ),
          Text(
            isOut ? '↗ Envoyé' : '↙ Reçu',
            style: TextStyle(
              fontSize: 10,
              color: isOut ? AppColors.primary : AppColors.textLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
