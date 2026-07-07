// lib/screens/users_management_screen.dart — NOUVEAU
// Accessible uniquement aux admins (vérifié dans main.dart / navigation).
// Permet de : voir tous les utilisateurs, changer leur rôle, désactiver/réactiver,
// et créer un nouveau compte employé directement.

import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';

class UsersManagementScreen extends StatelessWidget {
  const UsersManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Gestion des Utilisateurs')),
      body: StreamBuilder<List<AppUser>>(
        stream: AuthService.getAllUsers(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final users = snap.data!;
          if (users.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'Aucun utilisateur',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _UserCard(user: users[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateUserDialog(context),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nouvel employé'),
      ),
    );
  }

  void _showCreateUserDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _CreateUserForm(),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  const _UserCard({required this.user});

  bool get _isCurrentUser =>
      AuthService.currentUser?.uid == user.uid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: !user.actif
            ? Border.all(color: AppColors.error.withOpacity(0.3))
            : null,
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          ClientAvatar(nom: user.nomComplet, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(user.nomComplet,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    if (_isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Vous',
                            style: TextStyle(
                                fontSize: 9, color: AppColors.primary)),
                      ),
                    ],
                  ],
                ),
                Text(user.email,
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 11)),
                if (!user.actif)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('Compte désactivé',
                        style: TextStyle(
                            color: AppColors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          // Badge rôle + sélecteur
          if (!_isCurrentUser)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'admin' || value == 'employe') {
                  await AuthService.updateUserRole(user.uid, value);
                } else if (value == 'toggle') {
                  if (user.actif) {
                    await AuthService.deactivateUser(user.uid);
                  } else {
                    await AuthService.reactivateUser(user.uid);
                  }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'admin',
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 16,
                          color: user.role == 'admin'
                              ? AppColors.primary
                              : AppColors.textLight),
                      const SizedBox(width: 8),
                      const Text('Administrateur'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'employe',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 16,
                          color: user.role == 'employe'
                              ? AppColors.primary
                              : AppColors.textLight),
                      const SizedBox(width: 8),
                      const Text('Employé'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        user.actif
                            ? Icons.block_outlined
                            : Icons.check_circle_outline,
                        size: 16,
                        color: user.actif ? AppColors.error : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Text(user.actif ? 'Désactiver' : 'Réactiver'),
                    ],
                  ),
                ),
              ],
              child: TypeChip(
                  label: user.role == 'admin' ? 'Admin' : 'Employé'),
            )
          else
            TypeChip(label: user.role == 'admin' ? 'Admin' : 'Employé'),
        ],
      ),
    );
  }
}

class _CreateUserForm extends StatefulWidget {
  const _CreateUserForm();

  @override
  State<_CreateUserForm> createState() => _CreateUserFormState();
}

class _CreateUserFormState extends State<_CreateUserForm> {
  final _formKey = GlobalKey<FormState>();
  final _prenomCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = 'employe';
  bool _loading = false;

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.registerWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        nom: _nomCtrl.text.trim(),
        prenom: _prenomCtrl.text.trim(),
        roleOverride: _role,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Compte créé avec succès'),
          backgroundColor: AppColors.success,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('AuthException: ', '')),
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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nouvel Employé',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.textDark)),
            const SizedBox(height: 4),
            const Text(
              '⚠️ Le compte sera créé immédiatement. Communiquez les identifiants de manière sécurisée.',
              style: TextStyle(color: AppColors.warning, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _prenomCtrl,
                    decoration: const InputDecoration(labelText: 'Prénom'),
                    validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _nomCtrl,
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined,
                    color: AppColors.primary, size: 18),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Champ requis';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                  return 'Email invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe temporaire',
                prefixIcon: Icon(Icons.lock_outline,
                    color: AppColors.primary, size: 18),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Champ requis';
                if (v.length < 6) return 'Minimum 6 caractères';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(
                labelText: 'Rôle',
                prefixIcon: Icon(Icons.shield_outlined,
                    color: AppColors.primary, size: 18),
              ),
              items: const [
                DropdownMenuItem(value: 'employe', child: Text('Employé')),
                DropdownMenuItem(
                    value: 'admin', child: Text('Administrateur')),
              ],
              onChanged: (v) => setState(() => _role = v!),
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textDark, fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Créer le compte'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
