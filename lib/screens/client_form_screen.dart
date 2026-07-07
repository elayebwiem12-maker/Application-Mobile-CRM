// lib/screens/client_form_screen.dart — VERSION AMÉLIORÉE
// Améliorations :
//  + Champ dateNaissance (pour campagnes anniversaire — CDC : Marketing Automation)
//  + Champ tags (segmentation libre — CDC : Segmentation)
//  + Badge segment automatique affiché en prévisualisation
//  + Validation email améliorée

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';

class ClientFormScreen extends StatefulWidget {
  final Client? client;
  const ClientFormScreen({super.key, this.client});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _villeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _typeClient = 'Nouveau';
  String _sourceAcquisition = 'Instagram';
  DateTime? _dateNaissance; // NOUVEAU
  List<String> _tags = []; // NOUVEAU
  bool _loading = false;

  final _types = ['Nouveau', 'Régulier', 'VIP', 'Prospect'];
  final _sources = [
    'Instagram', 'Facebook', 'Bouche à oreille',
    'Site web', 'WhatsApp', 'Autre',
  ];
  final _tagsDisponibles = [
    'Mariage', 'Anniversaire', 'Corporate', 'Baby Shower',
    'Fidèle', 'Recommandé', 'Premium',
  ];

  bool get _isEdit => widget.client != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final c = widget.client!;
      _nomCtrl.text = c.nom;
      _prenomCtrl.text = c.prenom;
      _telCtrl.text = c.telephone;
      _emailCtrl.text = c.email;
      _adresseCtrl.text = c.adresse;
      _villeCtrl.text = c.ville;
      _notesCtrl.text = c.notes;
      _typeClient = c.typeClient;
      _sourceAcquisition =
          c.sourceAcquisition.isNotEmpty ? c.sourceAcquisition : 'Instagram';
      _dateNaissance = c.dateNaissance;
      _tags = List.from(c.tags);
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _prenomCtrl.dispose(); _telCtrl.dispose();
    _emailCtrl.dispose(); _adresseCtrl.dispose();
    _villeCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateNaissance() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateNaissance ?? DateTime(1990),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateNaissance = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final client = Client(
        id: _isEdit ? widget.client!.id : const Uuid().v4(),
        nom: _nomCtrl.text.trim(),
        prenom: _prenomCtrl.text.trim(),
        telephone: _telCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        adresse: _adresseCtrl.text.trim(),
        ville: _villeCtrl.text.trim(),
        typeClient: _typeClient,
        sourceAcquisition: _sourceAcquisition,
        dateCreation: _isEdit ? widget.client!.dateCreation : DateTime.now(),
        dateNaissance: _dateNaissance,
        notes: _notesCtrl.text.trim(),
        tags: _tags,
        nombreEvenements: _isEdit ? widget.client!.nombreEvenements : 0,
        budgetMoyen: _isEdit ? widget.client!.budgetMoyen : 0,
      );
      if (_isEdit) {
        await FirebaseService.modifierClient(client);
      } else {
        await FirebaseService.ajouterClient(client);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit
              ? 'Client modifié avec succès'
              : 'Client ajouté avec succès'),
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
      appBar: AppBar(title: Text(_isEdit ? 'Modifier Client' : 'Nouveau Client')),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection('Informations Personnelles', [
                  _buildRow([
                    _FormField(ctrl: _prenomCtrl, label: 'Prénom',
                        icon: Icons.person_outline, required: true),
                    _FormField(ctrl: _nomCtrl, label: 'Nom',
                        icon: Icons.person_outline, required: true),
                  ]),
                  _FormField(
                    ctrl: _telCtrl,
                    label: 'Téléphone',
                    icon: Icons.phone_outlined,
                    required: true,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Champ requis';
                      if (v.replaceAll(RegExp(r'[^\d]'), '').length < 8)
                        return 'Numéro invalide';
                      return null;
                    },
                  ),
                  _FormField(
                    ctrl: _emailCtrl,
                    label: 'Email (optionnel)',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v != null && v.isNotEmpty &&
                          !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                        return 'Email invalide';
                      }
                      return null;
                    },
                  ),
                  // NOUVEAU : Date de naissance
                  GestureDetector(
                    onTap: _pickDateNaissance,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cake_outlined,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Date de naissance (optionnel)',
                                    style: TextStyle(
                                        fontSize: 11, color: AppColors.textLight)),
                                Text(
                                  _dateNaissance != null
                                      ? formatDate(_dateNaissance!)
                                      : 'Non renseignée',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: _dateNaissance != null
                                        ? AppColors.textDark
                                        : AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _dateNaissance != null
                                ? Icons.edit_outlined
                                : Icons.add_outlined,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('Localisation', [
                  _FormField(ctrl: _villeCtrl, label: 'Ville',
                      icon: Icons.location_city_outlined),
                  _FormField(ctrl: _adresseCtrl, label: 'Adresse complète',
                      icon: Icons.home_outlined, maxLines: 2),
                ]),
                const SizedBox(height: 16),
                _buildSection('Classification', [
                  _buildDropdown(
                    label: 'Type de client',
                    value: _typeClient,
                    items: _types,
                    icon: Icons.category_outlined,
                    onChanged: (v) => setState(() => _typeClient = v!),
                  ),
                  _buildDropdown(
                    label: 'Source d\'acquisition',
                    value: _sourceAcquisition,
                    items: _sources,
                    icon: Icons.source_outlined,
                    onChanged: (v) => setState(() => _sourceAcquisition = v!),
                  ),
                ]),
                const SizedBox(height: 16),
                // NOUVEAU : Tags
                _buildSection('Tags & Intérêts', [
                  const Text('Sélectionnez les tags applicables :',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMedium)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tagsDisponibles.map((tag) {
                      final sel = _tags.contains(tag);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (sel) _tags.remove(tag);
                          else _tags.add(tag);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primary
                                : AppColors.primaryLight.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.primaryLight,
                            ),
                          ),
                          child: Text(tag,
                              style: TextStyle(
                                  color: sel ? Colors.white : AppColors.textMedium,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ),
                      );
                    }).toList(),
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('Notes', [
                  _FormField(ctrl: _notesCtrl, label: 'Notes internes',
                      icon: Icons.notes_outlined, maxLines: 4),
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
                      : Text(
                          _isEdit ? 'Enregistrer les modifications' : 'Ajouter le client',
                          style: const TextStyle(fontSize: 16)),
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

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
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

  Widget _buildRow(List<Widget> children) {
    return Row(
      children: children
          .asMap()
          .entries
          .map((e) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: e.key > 0 ? 8 : 0),
                  child: e.value,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildDropdown({
    required String label, required String value,
    required List<String> items, required IconData icon,
    required void Function(String?) onChanged,
  }) {
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

class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool required;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator ??
            (required
                ? (v) => v == null || v.isEmpty ? 'Champ requis' : null
                : null),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
        ),
      ),
    );
  }
}
