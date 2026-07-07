// lib/main.dart — MODIFIÉ pour ajouter l'authentification
// AJOUTS :
//   + AuthGate : écoute l'état de connexion Firebase Auth
//     -> non connecté = LoginScreen
//     -> connecté = MainNavigation (avec profil chargé)
//   + Onglet "Profil" dans la navigation (logout + accès gestion users si admin)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'utils/theme.dart';
import 'models/app_user.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/evenements_screen.dart';
import 'screens/devis_screen.dart';
import 'screens/avis_screen.dart';
import 'screens/marketing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/analyse_screen.dart';
import 'screens/relances_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser la localisation française pour les dates
  await initializeDateFormatting('fr_FR', null);

  // Initialiser Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Orientation portrait uniquement (app mobile)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Couleur de la barre de statut
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const DecoCRMApp());
}

class DecoCRMApp extends StatelessWidget {
  const DecoCRMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DECO PAS PLUS — CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AuthGate(),
    );
  }
}

// ─── AUTH GATE (NOUVEAU) ───────────────────────────────────────────────────
// Point d'entrée qui décide quel écran afficher selon l'état de connexion.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        // Chargement initial de Firebase Auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        // Non connecté -> écran de login
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // Connecté -> charger le profil AppUser (avec rôle) puis afficher l'app
        return StreamBuilder<AppUser?>(
          stream: AuthService.currentAppUserStream(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppColors.background,
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }

            final appUser = userSnap.data;

            // Profil introuvable (cas rare/edge) -> déconnexion forcée
            if (appUser == null) {
              return const LoginScreen();
            }

            // Compte désactivé -> message + déconnexion
            if (!appUser.actif) {
              return _DeactivatedAccountScreen();
            }

            // Initialiser les notifications push (FCM) — une seule fois
            NotificationService.initialize();

            return MainNavigation(currentUser: appUser);
          },
        );
      },
    );
  }
}

class _DeactivatedAccountScreen extends StatelessWidget {
  const _DeactivatedAccountScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block_outlined, size: 60, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'Compte désactivé',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Votre compte a été désactivé. Contactez un administrateur.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => AuthService.signOut(),
                child: const Text('Se déconnecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── MAIN NAVIGATION (MODIFIÉ) ──────────────────────────────────────────────
// Ajout du paramètre currentUser + onglet Profil
class MainNavigation extends StatefulWidget {
  final AppUser currentUser;
  const MainNavigation({super.key, required this.currentUser});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    const DashboardScreen(),
    const ClientsScreen(),
    const EvenementsScreen(),
    const DevisScreen(),
    const AvisScreen(),
    const MarketingScreen(),
    const AnalyseScreen(),
    const RelancesScreen(),
    ProfileScreen(currentUser: widget.currentUser),
  ];

  final _navItems = const [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Accueil',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: 'Clients',
    ),
    NavigationDestination(
      icon: Icon(Icons.event_outlined),
      selectedIcon: Icon(Icons.event),
      label: 'Événements',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Devis',
    ),
    NavigationDestination(
      icon: Icon(Icons.star_outline),
      selectedIcon: Icon(Icons.star),
      label: 'Avis',
    ),
    NavigationDestination(
      icon: Icon(Icons.campaign_outlined),
      selectedIcon: Icon(Icons.campaign),
      label: 'Marketing',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights),
      label: 'Analyse',
    ),
    NavigationDestination(
      icon: Icon(Icons.notifications_outlined),
      selectedIcon: Icon(Icons.notifications),
      label: 'Relances',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryLight.withOpacity(0.5),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: _navItems,
        elevation: 8,
        shadowColor: AppColors.primary.withOpacity(0.2),
      ),
    );
  }
}