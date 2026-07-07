// lib/screens/avis_screen.dart — VERSION AVEC PHOTOS
// Améliorations :
//  + Upload photo depuis galerie ou caméra (image_picker + firebase_storage)
//  + Affichage photos dans la carte avis
//  + Multi-critères + réponse admin (déjà présents)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';

class AvisScreen extends StatefulWidget {
  const AvisScreen({super.key});

  @override
  State<AvisScreen> createState() => _AvisScreenState();
}

class _AvisScreenState extends State<AvisScreen> {
  double _filtreNoteMin = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Avis & Satisfaction'),
        actions: [
          PopupMenuButton<double>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrer par note',
            onSelected: (v) => setState(() => _filtreNoteMin = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 0, child: Text('Tous les avis')),
              const PopupMenuItem(value: 4, child: Text('4 étoiles et +')),
              const PopupMenuItem(value: 3, child: Text('3 étoiles et +')),
              const PopupMenuItem(value: 1, child: Text('Avis négatifs (< 3)')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Avis>>(
        stream: FirebaseService.getAvis(),
        builder: (context, snap) {
          var avisList = snap.data ?? [];
          if (_filtreNoteMin == 1) {
            avisList = avisList.where((a) => a.note < 3).toList();
          } else if (_filtreNoteMin > 0) {
            avisList = avisList.where((a) => a.note >= _filtreNoteMin).toList();
          }

          final noteMoyenne = avisList.isEmpty
              ? 0.0
              : avisList.fold(0.0, (s, a) => s + a.note) / avisList.length;

          final dist = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
          for (final a in avisList) {
            dist[a.note.round()] = (dist[a.note.round()] ?? 0) + 1;
          }

          final satisfaits = avisList.where((a) => a.note >= 4).length;
          final tauxSatisfaction =
              avisList.isEmpty ? 0.0 : satisfaits / avisList.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Score global
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(noteMoyenne.toStringAsFixed(1),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold)),
                            RatingBarIndicator(
                              rating: noteMoyenne,
                              itemBuilder: (_, __) =>
                                  const Icon(Icons.star, color: Colors.white),
                              itemCount: 5,
                              itemSize: 18,
                              unratedColor: Colors.white30,
                            ),
                            const SizedBox(height: 4),
                            Text('${avisList.length} avis',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            children: [5, 4, 3, 2, 1].map((n) {
                              final count = dist[n] ?? 0;
                              final pct = avisList.isEmpty
                                  ? 0.0
                                  : count / avisList.length;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Text('$n',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 11)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: LinearPercentIndicator(
                                        percent: pct,
                                        lineHeight: 6,
                                        backgroundColor: Colors.white24,
                                        progressColor: Colors.white,
                                        padding: EdgeInsets.zero,
                                        barRadius: const Radius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('$count',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_outlined,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${(tauxSatisfaction * 100).toStringAsFixed(0)}% de clients satisfaits',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (avisList.isEmpty)
                const EmptyState(
                  icon: Icons.star_outline,
                  title: 'Aucun avis',
                  subtitle: 'Les avis de vos clients apparaîtront ici',
                )
              else
                ...avisList.map((a) => _AvisCard(
                      avis: a,
                      onRepondre: (reponse) =>
                          FirebaseService.repondreAvis(a.id, reponse),
                    )),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAvisForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un avis'),
      ),
    );
  }

  void _showAvisForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _AvisForm(),
    );
  }
}

// ─── CARTE AVIS ──────────────────────────────────────────────────────────────
class _AvisCard extends StatelessWidget {
  final Avis avis;
  final Future<void> Function(String) onRepondre;

  const _AvisCard({required this.avis, required this.onRepondre});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: AppColors.primary.withOpacity(0.07),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClientAvatar(nom: avis.clientNom, radius: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(avis.clientNom,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    if (avis.typeEvenement.isNotEmpty)
                      Text(avis.typeEvenement,
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RatingBarIndicator(
                    rating: avis.note,
                    itemBuilder: (_, __) =>
                        const Icon(Icons.star, color: AppColors.gold),
                    itemCount: 5,
                    itemSize: 14,
                    unratedColor: AppColors.primaryLight,
                  ),
                  Text(formatDate(avis.dateCreation),
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 10)),
                ],
              ),
            ],
          ),
          // Notes multi-critères
          if (avis.aspects.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 4,
              children: avis.aspects.entries.map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryLight),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_aspectLabel(e.key),
                      style: const TextStyle(fontSize: 10, color: AppColors.textMedium)),
                  const SizedBox(width: 4),
                  const Icon(Icons.star, size: 10, color: AppColors.gold),
                  Text(' ${e.value.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 10,
                          fontWeight: FontWeight.bold, color: AppColors.textDark)),
                ]),
              )).toList(),
            ),
          ],
          // Commentaire
          if (avis.commentaire.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('"${avis.commentaire}"',
                  style: const TextStyle(fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textMedium)),
            ),
          ],
          // PHOTOS — NOUVEAU
          if (avis.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: avis.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _showPhoto(context, avis.photos[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      avis.photos[i],
                      width: 80, height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80, height: 80,
                        color: AppColors.cardBg,
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: AppColors.textLight),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          // Réponse admin
          if (avis.reponseAdmin.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryLight),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.reply_outlined, size: 14, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Réponse : ${avis.reponseAdmin}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMedium))),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _showReponseDialog(context),
              icon: const Icon(Icons.reply_outlined, size: 14),
              label: const Text('Répondre', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            ),
          ],
        ],
      ),
    );
  }

  void _showPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  void _showReponseDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Répondre à l\'avis',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Votre réponse...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                onRepondre(ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Publier'),
          ),
        ],
      ),
    );
  }

  String _aspectLabel(String key) {
    switch (key) {
      case 'qualite': return 'Qualité déco';
      case 'ponctualite': return 'Ponctualité';
      case 'rapport_qualite_prix': return 'Rapport Q/P';
      case 'communication': return 'Communication';
      default: return key;
    }
  }
}

// ─── FORMULAIRE AVIS AVEC PHOTOS ─────────────────────────────────────────────
class _AvisForm extends StatefulWidget {
  const _AvisForm();

  @override
  State<_AvisForm> createState() => _AvisFormState();
}

class _AvisFormState extends State<_AvisForm> {
  final _clientCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  double _note = 5;
  final Map<String, double> _aspects = {
    'qualite': 5, 'ponctualite': 5,
    'rapport_qualite_prix': 5, 'communication': 5,
  };
  final List<File> _photos = [];
  bool _loading = false;
  String _loadingMsg = '';

  @override
  void dispose() {
    _clientCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) {
      setState(() => _photos.add(File(picked.path)));
    }
  }

  Future<List<String>> _uploadPhotos(String avisId) async {
    final urls = <String>[];
    for (int i = 0; i < _photos.length; i++) {
      setState(() => _loadingMsg = 'Upload photo ${i + 1}/${_photos.length}...');
      final ref = FirebaseStorage.instance
          .ref()
          .child('avis/$avisId/photo_$i.jpg');
      await ref.putFile(_photos[i]);
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  Future<void> _submit() async {
    if (_clientCtrl.text.isEmpty) return;
    setState(() { _loading = true; _loadingMsg = 'Enregistrement...'; });

    final avisId = const Uuid().v4();
    List<String> photoUrls = [];

    if (_photos.isNotEmpty) {
      setState(() => _loadingMsg = 'Upload des photos...');
      photoUrls = await _uploadPhotos(avisId);
    }

    final avis = Avis(
      id: avisId,
      clientId: '',
      clientNom: _clientCtrl.text.trim(),
      note: _note,
      aspects: Map.from(_aspects),
      commentaire: _commentCtrl.text.trim(),
      photos: photoUrls,
      dateCreation: DateTime.now(),
    );

    await FirebaseService.ajouterAvis(avis);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nouvel Avis',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18,
                  color: AppColors.textDark)),
          const SizedBox(height: 16),
          TextField(
            controller: _clientCtrl,
            decoration: const InputDecoration(
              labelText: 'Nom du client',
              prefixIcon: Icon(Icons.person_outline,
                  color: AppColors.primary, size: 18),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Note globale', style: TextStyle(
              fontWeight: FontWeight.w600, color: AppColors.textMedium, fontSize: 13)),
          const SizedBox(height: 8),
          RatingBar.builder(
            initialRating: _note,
            minRating: 1,
            itemCount: 5,
            itemBuilder: (_, __) => const Icon(Icons.star, color: AppColors.gold),
            onRatingUpdate: (r) => setState(() => _note = r),
            itemSize: 36,
          ),
          const SizedBox(height: 16),
          const Text('Évaluation détaillée', style: TextStyle(
              fontWeight: FontWeight.w600, color: AppColors.textMedium, fontSize: 13)),
          const SizedBox(height: 10),
          ..._aspects.keys.map((key) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text(_aspectLabel(key),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMedium))),
                Expanded(flex: 3, child: RatingBar.builder(
                  initialRating: _aspects[key]!,
                  minRating: 1,
                  itemCount: 5,
                  itemSize: 24,
                  itemBuilder: (_, __) => const Icon(Icons.star, color: AppColors.gold),
                  onRatingUpdate: (r) => setState(() => _aspects[key] = r),
                )),
              ],
            ),
          )),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Commentaire',
              prefixIcon: Icon(Icons.chat_bubble_outline,
                  color: AppColors.primary, size: 18),
            ),
          ),
          const SizedBox(height: 16),
          // PHOTOS — NOUVEAU
          const Text('Photos', style: TextStyle(
              fontWeight: FontWeight.w600, color: AppColors.textMedium, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              _PhotoBtn(
                icon: Icons.photo_library_outlined,
                label: 'Galerie',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              const SizedBox(width: 10),
              _PhotoBtn(
                icon: Icons.camera_alt_outlined,
                label: 'Caméra',
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ],
          ),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_photos[i],
                          width: 80, height: 80, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2, right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                              color: AppColors.error, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
                  : const Text('Enregistrer l\'avis'),
            ),
          ),
        ],
      ),
    );
  }

  String _aspectLabel(String key) {
    switch (key) {
      case 'qualite': return 'Qualité déco';
      case 'ponctualite': return 'Ponctualité';
      case 'rapport_qualite_prix': return 'Rapport Q/P';
      case 'communication': return 'Communication';
      default: return key;
    }
  }
}

class _PhotoBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PhotoBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primaryLight),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(
                  color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
