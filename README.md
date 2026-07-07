# 📱 DECO PAS PLUS — Application CRM Mobile

Application Flutter complète pour la gestion CRM de l'entreprise DECO PAS PLUS (Ezzahra, Ben Arous).

---

## 🏗️ Architecture du projet

```
lib/
├── main.dart                    # Point d'entrée + navigation principale
├── models/
│   └── models.dart              # Tous les modèles de données (Client, Evenement, Devis, Avis, Message, Campagne)
├── services/
│   └── firebase_service.dart    # Couche d'accès à Firestore (CRUD + streams)
├── utils/
│   └── theme.dart               # Palette couleurs + thème global (Rose Gold DECO PAS PLUS)
├── widgets/
│   └── shared_widgets.dart      # Composants réutilisables (StatCard, TypeChip, EmptyState...)
└── screens/
    ├── dashboard_screen.dart    # Tableau de bord KPI + graphiques
    ├── clients_screen.dart      # Liste clients avec recherche + filtres
    ├── client_detail_screen.dart # Fiche client complète
    ├── client_form_screen.dart  # Formulaire ajout/modification client
    ├── evenements_screen.dart   # Événements (liste + calendrier)
    ├── evenement_form_screen.dart # Formulaire événement
    ├── devis_screen.dart        # Devis, commandes, détails, création
    ├── avis_screen.dart         # Avis clients + statistiques satisfaction
    └── marketing_screen.dart   # Campagnes + modèles messages
```

---

## 🚀 Installation pas à pas

### 1. Prérequis
- Flutter SDK ≥ 3.0.0 installé
- Android Studio ou VS Code
- Compte Google (pour Firebase)

### 2. Créer le projet Firebase

1. Aller sur [console.firebase.google.com](https://console.firebase.google.com)
2. **Créer un projet** → nommer : `deco-crm`
3. Activer **Cloud Firestore** → Démarrer en mode test
4. Activer **Firebase Authentication** → Email/Mot de passe
5. (Optionnel) Activer **Firebase Storage** pour les photos

### 3. Connecter Flutter à Firebase

```bash
# Installer FlutterFire CLI
dart pub global activate flutterfire_cli

# Dans le dossier du projet
flutterfire configure --project=deco-crm
```

Cette commande génère automatiquement `lib/firebase_options.dart`.

**Puis modifier `main.dart` :**
```dart
// Remplacer la ligne Firebase.initializeApp(...) par :
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
// Et ajouter l'import :
import 'firebase_options.dart';
```

### 4. Installer les dépendances

```bash
cd deco_crm
flutter pub get
```

### 5. Lancer l'application

```bash
# Vérifier les appareils disponibles
flutter devices

# Lancer sur l'émulateur Android
flutter run

# Lancer en release (APK)
flutter build apk --release
```

---

## 🔥 Structure Firestore

Collections créées automatiquement :

| Collection | Description |
|------------|-------------|
| `clients` | Fiches clients avec type, source, budget... |
| `evenements` | Événements avec date, lieu, pack, statut |
| `devis` | Devis avec lignes, totaux, remises |
| `avis` | Notes et commentaires clients |
| `messages` | Historique communications |
| `campagnes` | Campagnes marketing |

---

## 📦 Modules couverts (CDC complet)

| N° | Module | Statut |
|----|--------|--------|
| 1 | Gestion Clients (CRM) | ✅ Complet |
| 2 | Module Événementiel | ✅ Complet |
| 3 | Devis et Commandes | ✅ Complet |
| 4 | Segmentation Clients | ✅ Filtres par type |
| 5 | Analyse du Comportement | ✅ KPIs + graphiques |
| 6 | Avis et Satisfaction | ✅ Complet avec notes |
| 7 | Communication Clients | ✅ WhatsApp + historique |
| 8 | Marketing Automation | ✅ Campagnes + templates |
| 9 | Tableau de Bord KPI | ✅ Charts FL_Chart |

---

## 🎨 Charte graphique

- **Couleur principale** : Rose Gold `#B76E79`
- **Couleur secondaire** : Or `#D4AF37`
- **Typographies** : Playfair Display (titres) + Poppins (corps)
- **Style** : Élégant, premium, événementiel

---

## ⚙️ Technologies utilisées

| Couche | Technologie |
|--------|-------------|
| Frontend | Flutter + Dart |
| Backend | Firebase (Firestore + Auth + Storage) |
| Base de données | Cloud Firestore (NoSQL) |
| Graphiques | FL Chart |
| Calendrier | Table Calendar |
| PDF | pdf package |
| Communication | url_launcher (WhatsApp, appels) |

---

## 📱 Fonctionnalités principales

- **Dashboard** : KPIs en temps réel, graphiques CA, événements par type
- **Clients** : CRUD complet, recherche, filtres, fiche détaillée
- **Événements** : Vue liste + calendrier, gestion statuts
- **Devis** : Création avec lignes dynamiques, calcul automatique, PDF
- **Avis** : Notes étoiles, distribution, statistiques
- **Marketing** : Campagnes ciblées, templates WhatsApp, relances automatiques

---

## 🔧 Prochaines évolutions suggérées

- Authentification admin (Firebase Auth)
- Export PDF des devis
- Notifications push (Firebase Messaging)
- Mode hors ligne (Firestore cache)
- Dashboard Web Admin (Flutter Web)
- Intégration WhatsApp Business API

---

*Développé dans le cadre du stage PFE — DECO PAS PLUS, Ezzahra, Ben Arous*
