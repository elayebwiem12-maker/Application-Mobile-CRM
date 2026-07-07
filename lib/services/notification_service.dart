// lib/services/notification_service.dart — NOUVEAU
// Gère les notifications push (FCM) :
//   - Demande la permission
//   - Enregistre le token FCM de l'utilisateur dans Firestore
//   - Abonne l'utilisateur au topic "equipe"
//   - Affiche les notifications reçues (foreground/background)

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  // ─── INITIALISATION (à appeler dans main.dart après login) ───────────────
  static Future<void> initialize() async {
    // 1. Demander la permission (iOS/Android 13+)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Initialiser les notifications locales (pour foreground)
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotif.initialize(initSettings);

    // 3. S'abonner au topic "equipe" (tous les employés reçoivent les mêmes notifs)
    await _messaging.subscribeToTopic('equipe');

    // 4. Enregistrer le token FCM dans Firestore (pour envoi ciblé si besoin)
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }

    // 5. Écouter le renouvellement du token
    _messaging.onTokenRefresh.listen(_saveTokenToFirestore);

    // 6. Gérer les notifications reçues quand l'app est ouverte (foreground)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 7. Gérer le clic sur une notification (app en arrière-plan → ouverte)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  // ─── ENREGISTRER LE TOKEN DANS FIRESTORE ─────────────────────────────────
  static Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': token});
    } catch (e) {
      if (kDebugMode) print('Erreur sauvegarde token FCM: $e');
    }
  }

  // ─── AFFICHER UNE NOTIFICATION LOCALE QUAND L'APP EST OUVERTE ────────────
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'deco_crm_channel',
      'DECO PAS PLUS — Notifications',
      channelDescription: 'Notifications du CRM DECO PAS PLUS',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotif.show(
      message.hashCode,
      message.notification?.title ?? 'DECO PAS PLUS',
      message.notification?.body ?? '',
      details,
    );
  }

  // ─── GÉRER LE CLIC SUR UNE NOTIFICATION ──────────────────────────────────
  static void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'];
    if (kDebugMode) print('Notification cliquée, type: $type');
    // Ici on pourrait naviguer vers l'écran approprié selon le type
    // (devis, événement, avis, etc.) — à implémenter avec un GlobalKey<NavigatorState>
  }

  // ─── SE DÉSABONNER (au logout) ────────────────────────────────────────────
  static Future<void> unsubscribe() async {
    await _messaging.unsubscribeFromTopic('equipe');
  }
}
