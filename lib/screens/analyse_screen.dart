// lib/screens/analyse_screen.dart — NOUVEAU
// CDC : Analyse du Comportement
// Saisonnalité, thèmes populaires, préférences clients, budget moyen

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';

class AnalyseScreen extends StatefulWidget {
  const AnalyseScreen({super.key});

  @override
  State<AnalyseScreen> createState() => _AnalyseScreenState();
}

class _AnalyseScreenState extends State<AnalyseScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = FirebaseFirestore.instance;

    final evSnap = await db.collection('evenements').get();
    final events = evSnap.docs.map((d) => d.data()).toList();

    // Saisonnalité par mois
    final Map<String, int> parMois = {
      '01': 0, '02': 0, '03': 0, '04': 0, '05': 0, '06': 0,
      '07': 0, '08': 0, '09': 0, '10': 0, '11': 0, '12': 0,
    };
    // Thèmes populaires
    final Map<String, int> parTheme = {};
    // Types populaires
    final Map<String, int> parType = {};
    // Packs populaires
    final Map<String, int> parPack = {};
    // Budget par type
    final Map<String, List<double>> budgetParType = {};
    // Couleurs populaires
    final Map<String, int> parCouleur = {};

    for (final e in events) {
      if (e['statut'] == 'Annulé') continue;

      // Mois
      try {
        final date = (e['date'] as dynamic).toDate() as DateTime;
        final m = date.month.toString().padLeft(2, '0');
        parMois[m] = (parMois[m] ?? 0) + 1;
      } catch (_) {}

      // Thème
      final theme = (e['theme'] as String? ?? '').trim();
      if (theme.isNotEmpty) parTheme[theme] = (parTheme[theme] ?? 0) + 1;

      // Type
      final type = (e['typeEvenement'] as String? ?? '').trim();
      if (type.isNotEmpty) {
        parType[type] = (parType[type] ?? 0) + 1;
        budgetParType.putIfAbsent(type, () => [])
            .add((e['budget'] as num? ?? 0).toDouble());
      }

      // Pack
      final pack = (e['packChoisi'] as String? ?? '').trim();
      if (pack.isNotEmpty) parPack[pack] = (parPack[pack] ?? 0) + 1;

      // Couleurs
      final couleurs = List<String>.from(e['couleurs'] ?? []);
      for (final c in couleurs) {
        if (c.isNotEmpty) parCouleur[c] = (parCouleur[c] ?? 0) + 1;
      }
    }

    // Budget moyen par type
    final Map<String, double> budgetMoyenParType = {};
    budgetParType.forEach((type, budgets) {
      budgetMoyenParType[type] =
          budgets.reduce((a, b) => a + b) / budgets.length;
    });

    setState(() {
      _data = {
        'parMois': parMois,
        'parTheme': parTheme,
        'parType': parType,
        'parPack': parPack,
        'parCouleur': parCouleur,
        'budgetMoyenParType': budgetMoyenParType,
        'totalEvents': events.length,
      };
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analyse du Comportement'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSaisonnalite(),
                  const SizedBox(height: 16),
                  _buildTypesPopulaires(),
                  const SizedBox(height: 16),
                  _buildBudgetParType(),
                  const SizedBox(height: 16),
                  _buildThemesPopulaires(),
                  const SizedBox(height: 16),
                  _buildPacksPopulaires(),
                  const SizedBox(height: 16),
                  _buildCouleursPopulaires(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  // ─── SAISONNALITÉ ─────────────────────────────────────────────────────────
  Widget _buildSaisonnalite() {
    final parMois = Map<String, int>.from(_data!['parMois']);
    const moisNoms = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    final maxVal = parMois.values.fold(0, (a, b) => a > b ? a : b).toDouble();

    return _Card(
      title: 'Saisonnalité des Événements',
      subtitle: 'Mois les plus chargés',
      icon: Icons.calendar_month_outlined,
      child: SizedBox(
        height: 160,
        child: BarChart(BarChartData(
          maxY: maxVal > 0 ? maxVal + 1 : 5,
          gridData: FlGridData(
            show: true, drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.primaryLight.withOpacity(0.3), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt() + 1;
                if (i < 1 || i > 12) return const SizedBox.shrink();
                return Text(moisNoms[i],
                    style: const TextStyle(fontSize: 8, color: AppColors.textLight));
              },
            )),
          ),
          barGroups: parMois.entries.toList().asMap().entries.map((e) {
            final val = e.value.value.toDouble();
            final isMax = val == maxVal && maxVal > 0;
            return BarChartGroupData(
              x: e.key,
              barRods: [BarChartRodData(
                toY: val > 0 ? val : 0.1,
                color: isMax ? AppColors.gold : AppColors.primary.withOpacity(0.6),
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              )],
            );
          }).toList(),
        )),
      ),
    );
  }

  // ─── TYPES POPULAIRES ─────────────────────────────────────────────────────
  Widget _buildTypesPopulaires() {
    final parType = Map<String, int>.from(_data!['parType']);
    if (parType.isEmpty) return const _EmptyCard('Types d\'événements', 'Aucun événement');

    final sorted = parType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = parType.values.fold(0, (a, b) => a + b);
    final colors = [AppColors.primary, AppColors.gold, AppColors.info,
      AppColors.success, AppColors.warning];

    return _Card(
      title: 'Types d\'Événements les plus demandés',
      icon: Icons.event_outlined,
      child: Column(
        children: sorted.asMap().entries.map((e) {
          final color = colors[e.key % colors.length];
          final pct = total > 0 ? e.value.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(e.value.key, style: const TextStyle(fontSize: 13)),
                  Text('${e.value.value} (${(pct * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: pct, minHeight: 6,
                  backgroundColor: color.withOpacity(0.1), color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── BUDGET PAR TYPE ──────────────────────────────────────────────────────
  Widget _buildBudgetParType() {
    final budgetMoyen = Map<String, double>.from(_data!['budgetMoyenParType']);
    if (budgetMoyen.isEmpty) return const _EmptyCard('Budget Moyen', 'Aucune donnée');

    final sorted = budgetMoyen.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _Card(
      title: 'Budget Moyen par Type d\'Événement',
      icon: Icons.payments_outlined,
      child: Column(
        children: sorted.map((e) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primaryLight.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(e.key, style: const TextStyle(fontSize: 13)),
              Text(formatMontant(e.value),
                  style: const TextStyle(color: AppColors.gold,
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  // ─── THÈMES POPULAIRES ────────────────────────────────────────────────────
  Widget _buildThemesPopulaires() {
    final parTheme = Map<String, int>.from(_data!['parTheme']);
    if (parTheme.isEmpty) {
      return const _EmptyCard('Thèmes Populaires', 'Aucun thème renseigné');
    }

    final sorted = parTheme.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _Card(
      title: 'Thèmes les plus Populaires',
      icon: Icons.palette_outlined,
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: sorted.map((e) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${e.key}  ${e.value}',
            style: const TextStyle(color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        )).toList(),
      ),
    );
  }

  // ─── PACKS POPULAIRES ─────────────────────────────────────────────────────
  Widget _buildPacksPopulaires() {
    final parPack = Map<String, int>.from(_data!['parPack']);
    if (parPack.isEmpty) {
      return const _EmptyCard('Packs Populaires', 'Aucun pack renseigné');
    }

    final sorted = parPack.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final colors = [AppColors.gold, AppColors.primary, AppColors.info, AppColors.success];

    return _Card(
      title: 'Packs les Plus Vendus',
      icon: Icons.inventory_2_outlined,
      child: Column(
        children: sorted.asMap().entries.map((e) {
          final color = colors[e.key % colors.length];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Center(
                    child: Text('${e.key + 1}',
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(e.value.key,
                    style: const TextStyle(fontWeight: FontWeight.w500))),
                Text('${e.value.value} vente(s)',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── COULEURS POPULAIRES ──────────────────────────────────────────────────
  Widget _buildCouleursPopulaires() {
    final parCouleur = Map<String, int>.from(_data!['parCouleur']);
    if (parCouleur.isEmpty) {
      return const _EmptyCard('Couleurs Préférées', 'Aucune couleur renseignée');
    }

    final sorted = parCouleur.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _Card(
      title: 'Couleurs les Plus Demandées',
      icon: Icons.color_lens_outlined,
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: sorted.take(10).map((e) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Text(
            '${e.key}  ×${e.value}',
            style: const TextStyle(fontSize: 12, color: AppColors.textDark),
          ),
        )).toList(),
      ),
    );
  }
}

// ─── WIDGETS HELPERS ──────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;

  const _Card({required this.title, this.subtitle, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: AppColors.primary.withOpacity(0.07),
          blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark)),
                if (subtitle != null)
                  Text(subtitle!, style: const TextStyle(
                      fontSize: 11, color: AppColors.textLight)),
              ],
            )),
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String message;
  const _EmptyCard(this.title, this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Center(child: Text(message,
              style: const TextStyle(color: AppColors.textLight))),
        ],
      ),
    );
  }
}
