// lib/screens/dashboard_screen.dart — VERSION SIMPLIFIÉE ET STABLE
// Toutes les queries sont simples (pas de compound queries = pas d'index requis)
// Compatible avec Firestore Spark plan sans configuration d'index

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/notifications_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _kpis;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final kpis = await _getSimpleKPIs();
      if (mounted) setState(() { _kpis = kpis; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // KPIs simples — sans compound queries, fonctionne sans index Firestore
  Future<Map<String, dynamic>> _getSimpleKPIs() async {
    final db = FirebaseService.db;

    // Clients
    final clientsSnap = await db.collection('clients').get();
    final clients = clientsSnap.docs.map((d) => d.data()).toList();
    final totalClients = clients.length;
    final vip = clients.where((c) => c['typeClient'] == 'VIP').length;
    final prospects = clients.where((c) => c['typeClient'] == 'Prospect').length;

    // Sources d'acquisition
    final Map<String, int> parSource = {};
    for (final c in clients) {
      final src = (c['sourceAcquisition'] as String?) ?? 'Autre';
      if (src.isNotEmpty) parSource[src] = (parSource[src] ?? 0) + 1;
    }

    // Événements
    final eventsSnap = await db.collection('evenements').get();
    final events = eventsSnap.docs.map((d) => d.data()).toList();
    final totalEvenements = events.length;

    double caTotal = 0;
    final Map<String, int> parType = {};
    final Map<String, double> caParType = {};
    final Map<String, int> parPack = {};
    final Map<String, double> caParMois = {};
    final now = DateTime.now();

    for (final e in events) {
      if (e['statut'] == 'Annulé') continue;
      final budget = (e['budget'] as num? ?? 0).toDouble();
      caTotal += budget;

      final type = (e['typeEvenement'] as String?) ?? 'Autre';
      parType[type] = (parType[type] ?? 0) + 1;
      caParType[type] = (caParType[type] ?? 0) + budget;

      final pack = (e['packChoisi'] as String?) ?? '';
      if (pack.isNotEmpty) parPack[pack] = (parPack[pack] ?? 0) + 1;

      try {
        final ts = e['date'];
        if (ts != null) {
          final date = (ts as dynamic).toDate() as DateTime;
          if (now.difference(date).inDays <= 365) {
            final key = '${date.month.toString().padLeft(2, '0')}/${date.year}';
            caParMois[key] = (caParMois[key] ?? 0) + budget;
          }
        }
      } catch (_) {}
    }

    String packLePlusVendu = '';
    if (parPack.isNotEmpty) {
      packLePlusVendu = parPack.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    // Devis
    final devisSnap = await db.collection('devis').get();
    final devisList = devisSnap.docs.map((d) => d.data()).toList();
    final devisAcceptes = devisList.where((d) => d['statut'] == 'Accepté').length;
    final tauxConversion = devisList.isEmpty
        ? 0.0
        : devisAcceptes / devisList.length * 100;

    // Avis
    final avisSnap = await db.collection('avis').get();
    final avisList = avisSnap.docs.map((d) => d.data()).toList();
    double noteMoyenne = 0;
    if (avisList.isNotEmpty) {
      noteMoyenne = avisList.fold(0.0, (s, a) => s + (a['note'] as num? ?? 0).toDouble()) / avisList.length;
    }

    // Taux fidélisation
    final clientsMulti = clients.where((c) => (c['nombreEvenements'] as int? ?? 0) >= 2).length;
    final tauxFidelisation = totalClients > 0 ? clientsMulti / totalClients * 100 : 0.0;

    return {
      'totalClients': totalClients,
      'vip': vip,
      'prospects': prospects,
      'totalEvenements': totalEvenements,
      'tauxConversion': tauxConversion,
      'caTotal': caTotal,
      'noteMoyenne': noteMoyenne,
      'parType': parType,
      'caParType': caParType,
      'caParMois': caParMois,
      'packLePlusVendu': packLePlusVendu,
      'tauxFidelisation': tauxFidelisation,
      'parSource': parSource,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadAll,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(60),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  else if (_error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                            const SizedBox(height: 12),
                            const Text('Erreur de chargement',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _loadAll,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    _buildKPIGrid(),
                    const SizedBox(height: 20),
                    _buildCAChart(),
                    const SizedBox(height: 20),
                    _buildEvenementsParType(),
                    const SizedBox(height: 20),
                    if ((_kpis!['packLePlusVendu'] as String).isNotEmpty)
                      _buildPacksCard(),
                    const SizedBox(height: 20),
                    _buildSourcesAcquisition(),
                    const SizedBox(height: 20),
                    _buildProchainEvenements(),
                    const SizedBox(height: 80),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.diamond_outlined, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DECO PAS PLUS',
                          style: TextStyle(color: Colors.white, fontSize: 18,
                              fontWeight: FontWeight.bold, letterSpacing: 1)),
                      Text('Tableau de bord CRM',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Badge notifications — NOUVEAU
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: IconButton(
            icon: NotificationsBadge(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => const NotificationsPanel(),
              ),
            ),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => const NotificationsPanel(),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadAll,
        ),
      ],
    );
  }

  Widget _buildKPIGrid() {
    final k = _kpis!;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        StatCard(title: 'Total Clients', value: '${k['totalClients']}',
            icon: Icons.people_outline, color: AppColors.primary),
        StatCard(title: 'Clients VIP', value: '${k['vip']}',
            icon: Icons.diamond_outlined, color: AppColors.gold),
        StatCard(title: 'Événements', value: '${k['totalEvenements']}',
            icon: Icons.event_outlined, color: AppColors.info),
        StatCard(title: 'Taux Conversion',
            value: '${(k['tauxConversion'] as double).toStringAsFixed(0)}%',
            icon: Icons.trending_up, color: AppColors.success),
        StatCard(title: 'CA Total', value: formatMontant(k['caTotal']),
            icon: Icons.account_balance_wallet_outlined, color: AppColors.primaryDark),
        StatCard(title: 'Fidélisation',
            value: '${(k['tauxFidelisation'] as double).toStringAsFixed(0)}%',
            icon: Icons.favorite_outline, color: AppColors.error),
        StatCard(title: 'Note Moyenne',
            value: '${(k['noteMoyenne'] as double).toStringAsFixed(1)} ⭐',
            icon: Icons.star_outline, color: AppColors.warning),
        StatCard(title: 'Prospects', value: '${k['prospects']}',
            icon: Icons.person_search_outlined, color: AppColors.textMedium),
      ],
    );
  }

  Widget _buildCAChart() {
    final caParMois = Map<String, double>.from(_kpis!['caParMois'] ?? {});
    if (caParMois.isEmpty) {
      return const _EmptyCard(title: 'Chiffre d\'Affaires', message: 'Pas encore de données CA');
    }

    final entries = caParMois.entries.toList()
      ..sort((a, b) {
        final pa = a.key.split('/');
        final pb = b.key.split('/');
        final da = DateTime(int.parse(pa[1]), int.parse(pa[0]));
        final db2 = DateTime(int.parse(pb[1]), int.parse(pb[0]));
        return da.compareTo(db2);
      });

    final spots = entries.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    return _ChartCard(
      title: 'Chiffre d\'Affaires (12 mois)',
      child: SizedBox(
        height: 160,
        child: LineChart(LineChartData(
          gridData: FlGridData(
            show: true, drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.primaryLight.withOpacity(0.3), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 42,
              getTitlesWidget: (v, _) => Text('${(v / 1000).toStringAsFixed(0)}k',
                  style: const TextStyle(fontSize: 9, color: AppColors.textLight)),
            )),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                final parts = entries[i].key.split('/');
                const noms = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
                  'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
                final m = int.tryParse(parts[0]) ?? 1;
                return Text(noms[m],
                    style: const TextStyle(fontSize: 9, color: AppColors.textLight));
              },
            )),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.gold]),
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(colors: [
                  AppColors.primary.withOpacity(0.2),
                  AppColors.gold.withOpacity(0.03),
                ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
            ),
          ],
        )),
      ),
    );
  }

  Widget _buildEvenementsParType() {
    final parType = Map<String, int>.from(_kpis!['parType'] ?? {});
    if (parType.isEmpty) return const _EmptyCard(title: 'Événements par Type', message: 'Aucun événement');

    final colors = [AppColors.primary, AppColors.gold, AppColors.info,
      AppColors.success, AppColors.warning, AppColors.error];
    final total = parType.values.fold(0, (a, b) => a + b);
    final sections = parType.entries.toList().asMap().entries.map((e) {
      final color = colors[e.key % colors.length];
      return PieChartSectionData(
        value: e.value.value.toDouble(),
        title: '${((e.value.value / total) * 100).toStringAsFixed(0)}%',
        color: color, radius: 55,
        titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      );
    }).toList();

    return _ChartCard(
      title: 'Événements par Type',
      child: Row(
        children: [
          SizedBox(
            height: 140, width: 140,
            child: PieChart(PieChartData(sections: sections, sectionsSpace: 2, centerSpaceRadius: 30)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: parType.entries.toList().asMap().entries.map((e) {
                final color = colors[e.key % colors.length];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.value.key,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
                          overflow: TextOverflow.ellipsis)),
                      Text('${e.value.value}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPacksCard() {
    final pack = _kpis!['packLePlusVendu'] as String;
    return _ChartCard(
      title: 'Pack le plus vendu',
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pack, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
                const Text('Pack le plus demandé par vos clients',
                    style: TextStyle(color: AppColors.textLight, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcesAcquisition() {
    final parSource = Map<String, int>.from(_kpis!['parSource'] ?? {});
    if (parSource.isEmpty) return const SizedBox.shrink();

    final total = parSource.values.fold(0, (a, b) => a + b);
    final sorted = parSource.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return _ChartCard(
      title: 'Sources d\'Acquisition',
      child: Column(
        children: sorted.take(5).map((entry) {
          final pct = total > 0 ? entry.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key, style: const TextStyle(fontSize: 13, color: AppColors.textDark)),
                    Text('${entry.value} (${(pct * 100).toStringAsFixed(0)}%)',
                        style: const TextStyle(fontSize: 12, color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: pct,
                  backgroundColor: AppColors.primaryLight.withOpacity(0.3),
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProchainEvenements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Prochains Événements', action: 'Voir tout'),
        const SizedBox(height: 8),
        StreamBuilder(
          stream: FirebaseService.getEvenementsAVenir(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final evens = snapshot.data!.take(3).toList();
            if (evens.isEmpty) {
              return const EmptyState(icon: Icons.event_busy, title: 'Aucun événement à venir');
            }
            return Column(
              children: evens.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: AppColors.cardGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryLight.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(DateFormat('dd').format(e.date),
                              style: const TextStyle(color: AppColors.primary,
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                          Text(DateFormat('MMM', 'fr_FR').format(e.date),
                              style: const TextStyle(color: AppColors.textLight, fontSize: 10)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.clientNom, style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textDark)),
                          Text('${e.typeEvenement} — ${e.lieu}',
                              style: const TextStyle(color: AppColors.textMedium, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TypeChip(label: e.statut),
                        const SizedBox(height: 4),
                        Text(formatMontant(e.budget),
                            style: const TextStyle(color: AppColors.gold,
                                fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              )).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ─── WIDGETS HELPERS ──────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: AppColors.primary.withOpacity(0.08),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String message;
  const _EmptyCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: title,
      child: Center(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message,
            style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
      )),
    );
  }
}