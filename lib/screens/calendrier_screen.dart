// lib/screens/calendrier_screen.dart — NOUVEAU
// Calendrier visuel des événements
// Utilise table_calendar déjà dans pubspec.yaml
 
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';
 
class CalendrierScreen extends StatefulWidget {
  const CalendrierScreen({super.key});
 
  @override
  State<CalendrierScreen> createState() => _CalendrierScreenState();
}
 
class _CalendrierScreenState extends State<CalendrierScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Evenement>> _evenements = {};
  bool _loading = true;
 
  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadEvenements();
  }
 
  Future<void> _loadEvenements() async {
    setState(() => _loading = true);
    final snap = await FirebaseFirestore.instance
        .collection('evenements')
        .get();
    final Map<DateTime, List<Evenement>> map = {};
    for (final doc in snap.docs) {
      final e = Evenement.fromFirestore(doc);
      final key = DateTime(e.date.year, e.date.month, e.date.day);
      map.putIfAbsent(key, () => []).add(e);
    }
    setState(() { _evenements = map; _loading = false; });
  }
 
  List<Evenement> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _evenements[key] ?? [];
  }
 
  Color _statutColor(String statut) {
    switch (statut) {
      case 'Confirmé': return AppColors.success;
      case 'En attente': return AppColors.warning;
      case 'Terminé': return AppColors.textMedium;
      case 'Annulé': return AppColors.error;
      default: return AppColors.primary;
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final selectedEvents = _selectedDay != null
        ? _getEventsForDay(_selectedDay!)
        : <Evenement>[];
 
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Calendrier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () => setState(() {
              _focusedDay = DateTime.now();
              _selectedDay = DateTime.now();
            }),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadEvenements),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Calendrier
                Container(
                  color: AppColors.surface,
                  child: TableCalendar<Evenement>(
                    firstDay: DateTime(2024),
                    lastDay: DateTime(2027),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    eventLoader: _getEventsForDay,
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 3,
                      outsideDaysVisible: false,
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.primary),
                      rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.primary),
                      titleTextStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textDark),
                    ),
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _selectedDay = selected;
                        _focusedDay = focused;
                      });
                    },
                    onPageChanged: (focused) {
                      setState(() => _focusedDay = focused);
                    },
                  ),
                ),
 
                // Résumé du mois
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MiniStat(
                        label: 'Ce mois',
                        value: '${_evenementsDuMois()}',
                        color: AppColors.primary,
                      ),
                      _MiniStat(
                        label: 'Confirmés',
                        value: '${_evenementsParStatut('Confirmé')}',
                        color: AppColors.success,
                      ),
                      _MiniStat(
                        label: 'En attente',
                        value: '${_evenementsParStatut('En attente')}',
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ),
 
                const Divider(height: 1),
 
                // Événements du jour sélectionné
                Expanded(
                  child: selectedEvents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_available,
                                  size: 48,
                                  color: AppColors.primaryLight.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              Text(
                                _selectedDay != null
                                    ? 'Aucun événement le ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}'
                                    : 'Sélectionnez un jour',
                                style: const TextStyle(color: AppColors.textLight),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: selectedEvents.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final e = selectedEvents[i];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border(left: BorderSide(
                                  color: _statutColor(e.statut),
                                  width: 4,
                                )),
                                boxShadow: [BoxShadow(
                                  color: AppColors.primary.withOpacity(0.06),
                                  blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(e.clientNom,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14)),
                                        const SizedBox(height: 4),
                                        Text(e.typeEvenement,
                                            style: const TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500)),
                                        Text('📍 ${e.lieu}',
                                            style: const TextStyle(
                                                color: AppColors.textMedium,
                                                fontSize: 11)),
                                        if (e.heureDebut != null)
                                          Text('🕐 ${e.heureDebut}',
                                              style: const TextStyle(
                                                  color: AppColors.textMedium,
                                                  fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _statutColor(e.statut)
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(e.statut,
                                            style: TextStyle(
                                                color: _statutColor(e.statut),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(formatMontant(e.budget),
                                          style: const TextStyle(
                                              color: AppColors.gold,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
 
  int _evenementsDuMois() {
    return _evenements.entries
        .where((e) =>
            e.key.month == _focusedDay.month &&
            e.key.year == _focusedDay.year)
        .fold(0, (sum, e) => sum + e.value.length);
  }
 
  int _evenementsParStatut(String statut) {
    return _evenements.entries
        .where((e) =>
            e.key.month == _focusedDay.month &&
            e.key.year == _focusedDay.year)
        .expand((e) => e.value)
        .where((e) => e.statut == statut)
        .length;
  }
}
 
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});
 
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 20, color: color)),
        Text(label, style: const TextStyle(
            fontSize: 11, color: AppColors.textLight)),
      ],
    );
  }
}