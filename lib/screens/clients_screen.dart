// lib/screens/clients_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';
import 'client_detail_screen.dart';
import 'client_form_screen.dart';
import 'segmentation_screen.dart';
import '../services/export_service.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedType = 'Tous';
  late TabController _tabCtrl;

  final _types = ['Tous', 'VIP', 'Régulier', 'Nouveau', 'Prospect'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _types.length, vsync: this);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart_outline),
            tooltip: 'Segmentation',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SegmentationScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Exporter en CSV',
            onPressed: () => _exporterClients(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un client...',
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.textLight),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textLight,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                onTap: (i) => setState(() => _selectedType = _types[i]),
                tabs: _types.map((t) => Tab(text: t)).toList(),
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<Client>>(
        stream: _selectedType == 'Tous'
            ? FirebaseService.getClients()
            : FirebaseService.getClientsByType(_selectedType),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return EmptyState(
              icon: Icons.people_outline,
              title: 'Aucun client',
              subtitle: 'Ajoutez votre premier client',
              buttonLabel: 'Nouveau client',
              onButton: () => _openForm(context),
            );
          }
          var clients = snapshot.data!;
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            clients = clients
                .where((c) =>
                    c.nomComplet.toLowerCase().contains(q) ||
                    c.telephone.contains(q) ||
                    c.email.toLowerCase().contains(q))
                .toList();
          }
          if (clients.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Aucun résultat',
              subtitle: 'Essayez un autre terme de recherche',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: clients.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ClientCard(
              client: clients[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientDetailScreen(client: clients[i]),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nouveau Client'),
      ),
    );
  }

  void _openForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClientFormScreen()),
    );
  }

  Future<void> _exporterClients(BuildContext context) async {
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
                Text('Export en cours...'),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final clients = await FirebaseService.getClients().first;
      await ExportService.exporterClientsCSV(clients);
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
}

class _ClientCard extends StatelessWidget {
  final Client client;
  final VoidCallback onTap;

  const _ClientCard({required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClientAvatar(nom: client.nomComplet, photoUrl: client.photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          client.nomComplet,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      TypeChip(label: client.typeClient),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 12, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        client.telephone,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMedium),
                      ),
                      if (client.ville.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Text(
                          client.ville,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMedium),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _InfoBadge(
                        icon: Icons.event_outlined,
                        label: '${client.nombreEvenements} événements',
                      ),
                      const SizedBox(width: 8),
                      if (client.budgetMoyen > 0)
                        _InfoBadge(
                          icon: Icons.payments_outlined,
                          label: formatMontant(client.budgetMoyen),
                          color: AppColors.gold,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoBadge({
    required this.icon,
    required this.label,
    this.color = AppColors.textLight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}