// lib/screens/evenements_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';
import 'evenement_form_screen.dart';

class EvenementsScreen extends StatefulWidget {
  const EvenementsScreen({super.key});

  @override
  State<EvenementsScreen> createState() => _EvenementsScreenState();
}

class _EvenementsScreenState extends State<EvenementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _filterStatut = 'Tous';

  final _statuts = ['Tous', 'En attente', 'Confirmé', 'En cours', 'Terminé', 'Annulé'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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
        title: const Text('Événements'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'Liste'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Calendrier'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildListView(),
          _buildCalendarView(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EvenementFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nouvel Événement'),
      ),
    );
  }

  Widget _buildListView() {
    return Column(
      children: [
        // Filter chips
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
          child: StreamBuilder<List<Evenement>>(
            stream: FirebaseService.getEvenements(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (!snap.hasData || snap.data!.isEmpty) {
                return EmptyState(
                  icon: Icons.event_outlined,
                  title: 'Aucun événement',
                  subtitle: 'Créez votre premier événement',
                  buttonLabel: 'Nouvel événement',
                  onButton: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EvenementFormScreen()),
                  ),
                );
              }
              var events = snap.data!;
              if (_filterStatut != 'Tous') {
                events = events
                    .where((e) => e.statut == _filterStatut)
                    .toList();
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _EvenementCard(
                  evenement: events[i],
                  onStatutChanged: (statut) =>
                      FirebaseService.mettreAJourStatut(events[i].id, statut),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarView() {
    return StreamBuilder<List<Evenement>>(
      stream: FirebaseService.getEvenements(),
      builder: (context, snap) {
        final events = snap.data ?? [];
        final eventMap = <DateTime, List<Evenement>>{};
        for (final e in events) {
          final day = DateTime(e.date.year, e.date.month, e.date.day);
          eventMap[day] = [...(eventMap[day] ?? []), e];
        }

        final selectedEvents = _selectedDay != null
            ? (eventMap[DateTime(
                    _selectedDay!.year,
                    _selectedDay!.month,
                    _selectedDay!.day)] ??
                [])
            : [];

        return Column(
          children: [
            Container(
              color: AppColors.surface,
              child: TableCalendar<Evenement>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                eventLoader: (d) {
                  final key = DateTime(d.year, d.month, d.day);
                  return eventMap[key] ?? [];
                },
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                calendarStyle: CalendarStyle(
                  selectedDecoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                  outsideDaysVisible: false,
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textDark),
                ),
              ),
            ),
            if (selectedEvents.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppColors.background,
                child: Row(
                  children: [
                    Text(
                      '${selectedEvents.length} événement(s)',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: selectedEvents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _EvenementCard(
                    evenement: selectedEvents[i] as Evenement,
                    onStatutChanged: (s) => FirebaseService.mettreAJourStatut(
                        (selectedEvents[i] as Evenement).id, s),
                  ),
                ),
              ),
            ] else
              Expanded(
                child: Center(
                  child: Text(
                    _selectedDay == null
                        ? 'Sélectionnez un jour'
                        : 'Aucun événement ce jour',
                    style: const TextStyle(color: AppColors.textLight),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EvenementCard extends StatelessWidget {
  final Evenement evenement;
  final void Function(String) onStatutChanged;

  const _EvenementCard(
      {required this.evenement, required this.onStatutChanged});

  static const _typeIcons = {
    'Mariage': Icons.favorite_outline,
    'Anniversaire': Icons.cake_outlined,
    'Baby Shower': Icons.child_care_outlined,
    'Corporate': Icons.business_outlined,
    'Fiançailles': Icons.diamond_outlined,
    'Gala': Icons.star_outline,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _typeIcons[evenement.typeEvenement] ?? Icons.event_outlined;
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evenement.clientNom,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textDark),
                    ),
                    Text(
                      evenement.typeEvenement,
                      style: const TextStyle(
                          color: AppColors.textMedium, fontSize: 13),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showStatutPicker(context),
                child: TypeChip(label: evenement.statut),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _Detail(Icons.calendar_today_outlined, formatDate(evenement.date)),
              const SizedBox(width: 16),
              _Detail(Icons.location_on_outlined, evenement.lieu),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formatMontant(evenement.budget),
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          if (evenement.packChoisi.isNotEmpty || evenement.theme.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                if (evenement.packChoisi.isNotEmpty)
                  TypeChip(
                      label: '📦 ${evenement.packChoisi}',
                      color: AppColors.info),
                if (evenement.theme.isNotEmpty)
                  TypeChip(
                      label: '🎨 ${evenement.theme}',
                      color: AppColors.primary),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showStatutPicker(BuildContext context) {
    final statuts = ['En attente', 'Confirmé', 'En cours', 'Terminé', 'Annulé'];
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
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textLight),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
      ],
    );
  }
}
