import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'storage.dart';

class NotificationsService {
  NotificationsService._internal();
  static final NotificationsService instance = NotificationsService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    
    // Créer le canal de notification Android
    if (!kIsWeb) {
      final androidImplementation = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        // Supprimer le canal existant s'il existe pour forcer la recréation avec les nouveaux paramètres
        await androidImplementation.deleteNotificationChannel('medi_alert_channel');
        
        const channel = AndroidNotificationChannel(
          'medi_alert_channel',
          'Medication Reminders',
          description: 'Daily medication reminder notifications',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          // Ne pas spécifier de son - Android utilisera le son par défaut du système
        );
        await androidImplementation.createNotificationChannel(channel);
        debugPrint('Canal de notification créé avec son activé');
      }
    }
    
    final android = const AndroidInitializationSettings('@mipmap/ic_launcher');
    final ios = const DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          final storage = StorageService();
          final now = DateTime.now();
          await storage.appendHistory(
            ReminderLogEntry(
              id: 'log_${now.millisecondsSinceEpoch}',
              medicationId: payload,
              scheduledAt: now,
              firedAt: now,
              acknowledged: true,
            ),
          );
        }
      },
    );
    if (!kIsWeb) {
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }
    _initialized = true;
  }

  Future<int> scheduleDailyForMedication(Medication med) async {
    await init();
    final id = _stableIdFromString(med.id);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, med.time.hour, med.time.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    
    final timeStr = '${med.time.hour.toString().padLeft(2, '0')}:${med.time.minute.toString().padLeft(2, '0')}';
    
    debugPrint('Programmation de notification pour ${med.name} à $timeStr (ID: $id)');
    debugPrint('Date programmée: $scheduled');
    
    // Vérifier les permissions Android
    if (!kIsWeb) {
      final androidImplementation = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        // Vérifier la permission de notification
        final granted = await androidImplementation.requestNotificationsPermission();
        debugPrint('Permission de notification accordée: $granted');
        
        // Note: requestExactAlarmsPermission n'existe peut-être pas dans toutes les versions
        // La permission est gérée via le manifest et les paramètres système
        debugPrint('Vérification des permissions d\'alarme exacte...');
      }
    }
    
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medi_alert_channel',
        'Medication Reminders',
        channelDescription: 'Daily medication reminder notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        enableLights: true,
        vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
        // Ne pas spécifier de son - Android utilisera le son par défaut du canal
        ongoing: false,
        autoCancel: true,
        category: AndroidNotificationCategory.alarm,
        ticker: 'Rappel de médicament', // Texte qui apparaît dans la barre de statut
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default', // Son par défaut iOS
      ),
    );
    
    try {
      debugPrint('Tentative de programmation avec exactAllowWhileIdle...');
      await _plugin.zonedSchedule(
        id,
        med.name,
        'Dose: ${med.dose} à $timeStr',
        scheduled,
        details,
        payload: med.id,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('Notification programmée avec succès (exactAllowWhileIdle)');
    } catch (e) {
      debugPrint('Erreur avec exactAllowWhileIdle: $e');
      // Si exactAllowWhileIdle échoue, essayer avec exact
      try {
        debugPrint('Tentative de programmation avec exact...');
        await _plugin.zonedSchedule(
          id,
          med.name,
          'Dose: ${med.dose} à $timeStr',
          scheduled,
          details,
          payload: med.id,
          androidScheduleMode: AndroidScheduleMode.exact,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        debugPrint('Notification programmée avec succès (exact)');
      } catch (e2) {
        debugPrint('Erreur avec exact: $e2');
        // En dernier recours, utiliser le mode inexact
        try {
          debugPrint('Tentative de programmation avec inexactAllowWhileIdle...');
          await _plugin.zonedSchedule(
            id,
            med.name,
            'Dose: ${med.dose} à $timeStr',
            scheduled,
            details,
            payload: med.id,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
          );
          debugPrint('Notification programmée avec succès (inexactAllowWhileIdle)');
        } catch (e3) {
          debugPrint('Erreur avec inexactAllowWhileIdle: $e3');
          // Dernière tentative sans matchDateTimeComponents
          try {
            await _plugin.zonedSchedule(
              id,
              med.name,
              'Dose: ${med.dose} à $timeStr',
              scheduled,
              details,
              payload: med.id,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            );
            debugPrint('Notification programmée avec succès (sans matchDateTimeComponents)');
          } catch (e4) {
            debugPrint('Toutes les tentatives ont échoué. Dernière erreur: $e4');
            rethrow;
          }
        }
      }
    }
    return id;
  }

  Future<void> cancelForMedication(Medication med) async {
    await init();
    try {
      // Annuler la notification principale avec l'ID stable
      await _plugin.cancel(_stableIdFromString(med.id));
      
      // Annuler toutes les notifications en attente qui ont le même payload (med.id)
      final pending = await _plugin.pendingNotificationRequests();
      for (final notification in pending) {
        if (notification.payload == med.id) {
          await _plugin.cancel(notification.id);
          debugPrint('Notification annulée: ID=${notification.id}, Titre=${notification.title}');
        }
      }
      debugPrint('Toutes les notifications pour ${med.name} ont été annulées');
    } catch (e) {
      debugPrint('Erreur lors de l\'annulation des notifications pour ${med.name}: $e');
      // Ne pas faire échouer la suppression si l'annulation des notifications échoue
    }
  }

  Future<List<PendingNotificationRequest>> pending() async {
    await init();
    return _plugin.pendingNotificationRequests();
  }

  /// Re-programme toutes les notifications pour les médicaments existants
  Future<void> rescheduleAllMedications() async {
    await init();
    final storage = StorageService();
    final medications = await storage.loadMedications();
    
    debugPrint('Re-programmation de ${medications.length} médicament(s)...');
    for (final med in medications) {
      try {
        await scheduleDailyForMedication(med);
      } catch (e) {
        debugPrint('Erreur lors de la re-programmation de ${med.name}: $e');
      }
    }
    debugPrint('Re-programmation terminée');
  }

  /// Teste une notification immédiate (pour débogage)
  Future<void> showTestNotification() async {
    await init();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medi_alert_channel',
        'Medication Reminders',
        channelDescription: 'Daily medication reminder notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        enableLights: true,
        vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
        ongoing: false,
        autoCancel: true,
        category: AndroidNotificationCategory.alarm,
        ticker: 'Test de notification',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      ),
    );
    
    await _plugin.show(
      999999,
      'Test MediAlert',
      'Si vous voyez cette notification, les alarmes fonctionnent !',
      details,
    );
    debugPrint('Notification de test affichée');
  }

  /// Affiche les notifications en attente (pour débogage)
  Future<void> debugPendingNotifications() async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('=== Notifications en attente: ${pending.length} ===');
    for (final notification in pending) {
      debugPrint('ID: ${notification.id}, Titre: ${notification.title}, Date: ${notification.body}');
    }
  }

  int _stableIdFromString(String input) {
    // Stable hash -> 31-bit positive int
    int hash = 0;
    for (final code in input.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    if (hash == 0) hash = Random().nextInt(1 << 30);
    return hash;
  }
}


