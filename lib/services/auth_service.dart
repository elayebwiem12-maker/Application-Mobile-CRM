// lib/services/auth_service.dart — NOUVEAU
// Gère l'authentification (Email/Password + Google) et les rôles utilisateur.
//
// IMPORTANT pour Google Sign-In :
//   1. package google_sign_in doit être ajouté au pubspec.yaml :
//        google_sign_in: ^6.2.1
//   2. Configuration Android nécessaire (SHA-1 fingerprint dans Firebase Console) :
//        - Générer SHA-1 : cd android && ./gradlew signingReport
//        - Ajouter le SHA-1 dans Firebase Console > Project Settings > Your apps > Android app
//        - Télécharger le nouveau google-services.json et remplacer l'ancien
//        - Activer Google comme provider : Firebase Console > Authentication > Sign-in method > Google
//
// Le premier utilisateur créé devient automatiquement admin.
// Tout utilisateur suivant créé via "register" devient employé par défaut,
// SAUF si créé depuis l'écran de gestion des utilisateurs par un admin (rôle choisi).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_user.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // ─── STREAM ÉTAT AUTH ─────────────────────────────────────────────────────
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  // ─── RÉCUPÉRER LE PROFIL UTILISATEUR (avec rôle) ─────────────────────────
  static Future<AppUser?> getCurrentAppUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  static Stream<AppUser?> currentAppUserStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);
    return _db
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
  }

  // ─── LOGIN EMAIL / PASSWORD ───────────────────────────────────────────────
  static Future<AppUser?> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return await _ensureUserDoc(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    }
  }

  // ─── INSCRIPTION EMAIL / PASSWORD ─────────────────────────────────────────
  // Utilisé pour le premier compte (devient admin automatiquement)
  // ou par un admin pour créer un nouveau compte employé.
  static Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    required String nom,
    required String prenom,
    String? roleOverride, // si null -> auto (premier=admin, sinon=employe)
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final role = roleOverride ?? await _determineRole();

      final appUser = AppUser(
        uid: cred.user!.uid,
        email: email.trim(),
        nom: nom.trim(),
        prenom: prenom.trim(),
        role: role,
        dateCreation: DateTime.now(),
      );

      await _db.collection('users').doc(cred.user!.uid).set(appUser.toFirestore());
      return appUser;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    }
  }

  // Vérifie si c'est le premier utilisateur -> admin, sinon employe
  static Future<String> _determineRole() async {
    final snap = await _db.collection('users').limit(1).get();
    return snap.docs.isEmpty ? 'admin' : 'employe';
  }

  // ─── GOOGLE SIGN-IN ────────────────────────────────────────────────────────
  static Future<AppUser?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // utilisateur a annulé

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      return await _ensureUserDoc(userCred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    }
  }

  // Crée le document Firestore si l'utilisateur se connecte pour la 1ère fois
  // (utile pour Google Sign-In où il n'y a pas d'étape "register" séparée)
  static Future<AppUser> _ensureUserDoc(User firebaseUser) async {
    final docRef = _db.collection('users').doc(firebaseUser.uid);
    final doc = await docRef.get();

    if (doc.exists) {
      return AppUser.fromFirestore(doc);
    }

    // Nouvel utilisateur (ex: première connexion Google)
    final role = await _determineRole();
    final displayName = firebaseUser.displayName ?? '';
    final parts = displayName.split(' ');
    final prenom = parts.isNotEmpty ? parts.first : '';
    final nom = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final appUser = AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      nom: nom,
      prenom: prenom,
      role: role,
      photoUrl: firebaseUser.photoURL,
      dateCreation: DateTime.now(),
    );

    await docRef.set(appUser.toFirestore());
    return appUser;
  }

  // ─── LOGOUT ────────────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ─── RESET PASSWORD ────────────────────────────────────────────────────────
  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    }
  }

  // ─── GESTION UTILISATEURS (ADMIN) ────────────────────────────────────────

  static Stream<List<AppUser>> getAllUsers() {
    return _db
        .collection('users')
        .orderBy('dateCreation', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => AppUser.fromFirestore(d)).toList());
  }

  static Future<void> updateUserRole(String uid, String newRole) async {
    await _db.collection('users').doc(uid).update({'role': newRole});
  }

  static Future<void> deactivateUser(String uid) async {
    await _db.collection('users').doc(uid).update({'actif': false});
  }

  static Future<void> reactivateUser(String uid) async {
    await _db.collection('users').doc(uid).update({'actif': true});
  }

  // ─── MESSAGES D'ERREUR EN FRANÇAIS ────────────────────────────────────────
  static String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Aucun compte trouvé avec cet email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé.';
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'weak-password':
        return 'Le mot de passe doit contenir au moins 6 caractères.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'network-request-failed':
        return 'Erreur réseau. Vérifiez votre connexion.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      default:
        return 'Erreur d\'authentification : $code';
    }
  }
}


