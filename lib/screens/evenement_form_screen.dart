// lib/screens/evenement_form_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';

class EvenementFormScreen extends StatefulWidget {
  final Evenement? evenement;
  final String? clientId;
  final String? clientNom;

  const EvenementFormScreen({
    super.key,
    this.evenement,
    this.clientId,
    this.clientNom,
  });

  @override
  State<EvenementFormScreen> createState() => _EvenementFormScreenState();
}

class _EvenementFormScreenState extends State<EvenementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientNomCtrl = TextEditingController();
  final _lieuCtrl = TextEditingController();
  final _villeCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _packCtrl = TextEditingController();
  final _themeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _invitesCtrl = TextEditingController();

  String _typeEvenement = 'Mariage';
  String _statut = 'En attente';
  DateTime _date = DateTime.now().add(const Duration(days: 30));
  bool _loading = false;

  final _types = [
    'Mariage',
    'Fiançailles',
    'Anniversaire',
    'Baby Shower',
    'Corporate',
    'Gala',
    'Réception',
    'Autre',
  ];
  final _statuts = ['En attente', 'Confirmé', 'En cours', 'Terminé', 'Annulé'];

  bool get _isEdit => widget.evenement != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final e = widget.evenement!;
      _clientNomCtrl.text = e.clientNom;
      _lieuCtrl.text = e.lieu;
      _villeCtrl.text = e.ville;
      _budgetCtrl.text = e.budget.toStringAsFixed(0);
      _packCtrl.text = e.packChoisi;
      _themeCtrl.text = e.theme;
      _notesCtrl.text = e.notes;
      _invitesCtrl.text = e.nombreInvites.toString();
      _typeEvenement = e.typeEvenement;
      _statut = e.statut;
      _date = e.date;
    } else if (widget.clientNom != null) {
      _clientNomCtrl.text = widget.clientNom!;
    }
  }

  @override
  void dispose() {
    _clientNomCtrl.dispose();
    _lieuCtrl.dispose();
    _villeCtrl.dispose();
    _budgetCtrl.dispose();
    _packCtrl.dispose();
    _themeCtrl.dispose();
    _notesCtrl.dispose();
    _invitesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final evenement = Evenement(
        id: _isEdit ? widget.evenement!.id : const Uuid().v4(),
        clientId: widget.clientId ?? widget.evenement?.clientId ?? '',
        clientNom: _clientNomCtrl.text.trim(),
        typeEvenement: _typeEvenement,
        date: _date,
        lieu: _lieuCtrl.text.trim(),
        ville: _villeCtrl.text.trim(),
        budget: double.tryParse(_budgetCtrl.text.trim()) ?? 0,
        packChoisi: _packCtrl.text.trim(),
        theme: _themeCtrl.text.trim(),
        statut: _statut,
        notes: _notesCtrl.text.trim(),
        dateCreation: _isEdit ? widget.evenement!.dateCreation : DateTime.now(),
        nombreInvites: int.tryParse(_invitesCtrl.text.trim()) ?? 0,
      );
      if (_isEdit) {
        await FirebaseService.modifierEvenement(evenement);
      } else {
        await FirebaseService.ajouterEvenement(evenement);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Événement enregistré avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier Événement' : 'Nouvel Événement'),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('Client & Type', [
                  _field(_clientNomCtrl, 'Nom du client', Icons.person_outline,
                      required: true),
                  _dropdown('Type d\'événement', _typeEvenement, _types,
                      Icons.celebration_outlined,
                      (v) => setState(() => _typeEvenement = v!)),
                ]),
                const SizedBox(height: 14),
                _section('Date & Lieu', [
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Date de l\'événement',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.textLight)),
                              Text(
                                formatDate(_date),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark),
                              ),
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
                  _field(_lieuCtrl, 'Lieu / Salle', Icons.place_outlined,
                      required: true),
                  _field(_villeCtrl, 'Ville', Icons.location_city_outlined),
                ]),
                const SizedBox(height: 14),
                _section('Budget & Pack', [
                  _field(
                    _budgetCtrl,
                    'Budget (DT)',
                    Icons.payments_outlined,
                    required: true,
                    keyboard: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Champ requis';
                      if (double.tryParse(v) == null) return 'Montant invalide';
                      return null;
                    },
                  ),
                  _field(_packCtrl, 'Pack choisi', Icons.inventory_2_outlined),
                  _field(_invitesCtrl, 'Nombre d\'invités',
                      Icons.group_outlined,
                      keyboard: TextInputType.number),
                ]),
                const SizedBox(height: 14),
                _section('Décoration & Thème', [
                  _field(_themeCtrl, 'Thème', Icons.palette_outlined),
                  _dropdown('Statut', _statut, _statuts,
                      Icons.flag_outlined,
                      (v) => setState(() => _statut = v!)),
                ]),
                const SizedBox(height: 14),
                _section('Notes', [
                  _field(_notesCtrl, 'Notes internes', Icons.notes_outlined,
                      maxLines: 4),
                ]),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isEdit ? 'Enregistrer' : 'Créer l\'événement',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_loading) const LoadingOverlay(),
        ],
      ),
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

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        validator: validator ??
            (required ? (v) => (v == null || v.isEmpty) ? 'Requis' : null : null),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      IconData icon, void Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
        ),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        dropdownColor: AppColors.surface,
        style: const TextStyle(color: AppColors.textDark, fontSize: 14),
      ),
    );
  }
}
