# Mise à jour — Version Entreprise DECO PAS PLUS CRM

## Fichiers de cette livraison

| Fichier | Type | Destination |
|---|---|---|
| `pdf_devis_service.dart` | NOUVEAU | `lib/services/` |
| `export_service.dart` | NOUVEAU | `lib/services/` |
| `calendrier_screen.dart` | NOUVEAU | `lib/screens/` |
| `paiement_screen.dart` | NOUVEAU | `lib/screens/` |
| `clients_screen.dart` | MODIFIÉ | `lib/screens/` (remplace l'existant) |
| `devis_screen.dart` | MODIFIÉ | `lib/screens/` (remplace l'existant) |
| `main.dart` | MODIFIÉ | `lib/` (remplace l'existant) |
| `pubspec.yaml` | MODIFIÉ | racine du projet (remplace l'existant) |

---

## Ce qui a été ajouté

### 1. 📄 Génération PDF Devis + Partage WhatsApp
- Bouton **"Générer PDF & Partager"** sur chaque carte devis
- PDF professionnel avec logo, prestations, totaux, TVA
- Le partage ouvre le sélecteur natif (WhatsApp, Email, etc.)

### 2. 💰 Suivi des Paiements (nouvel onglet "Paiements")
- Statut : Payé / Partiel / Impayé
- Historique des versements par client
- KPI : Total dû / Reçu / Restant
- Bouton "Enregistrer un versement"

### 3. 📅 Calendrier Visuel (nouvel onglet "Calendrier")
- Vue mensuelle avec points indicateurs sur les jours avec événements
- Liste des événements du jour sélectionné
- Code couleur par statut (Confirmé/En attente/Terminé/Annulé)
- Stats rapides du mois (total, confirmés, en attente)

### 4. 📊 Export CSV Clients
- Bouton de téléchargement dans l'AppBar de l'écran Clients
- Export compatible Excel (BOM UTF-8)
- Colonnes : infos complètes + segment automatique

---

## Installation

### Étape 1 — Copier les fichiers
Remplacez les fichiers existants et ajoutez les nouveaux dans votre projet `C:\deco_crm\lib\`.

### Étape 2 — Installer les dépendances
```powershell
flutter pub get
```

### Étape 3 — Lancer
```powershell
flutter run
```

---

## Nouveaux onglets dans la navigation

La barre de navigation en bas contient maintenant :
Accueil | Clients | Événements | Devis | Avis | Marketing | Segments | Analyse | Relances | **Calendrier** | **Paiements** | Profil

⚠️ Avec 12 onglets, la barre peut être chargée sur petit écran — envisager de regrouper certains onglets secondaires dans un menu "Plus" si besoin d'épuration visuelle.

---

## Notes techniques

- **PDF** : généré localement avec le package `pdf`, sauvegardé temporairement puis partagé
- **Paiements** : nouvelle collection Firestore `paiements` (créée automatiquement au premier paiement)
- **Calendrier** : charge tous les événements au démarrage (optimisable avec pagination si volumineux)
- **Export CSV** : utilise `share_plus` pour le partage natif (ajouté au pubspec.yaml)
