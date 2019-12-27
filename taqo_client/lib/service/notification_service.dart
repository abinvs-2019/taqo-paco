import 'dart:async';
import 'dart:isolate';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../main.dart';
import '../model/action_specification.dart';
import '../model/experiment.dart';
import '../model/notification_holder.dart';
import '../pages/survey/survey_page.dart';
import '../storage/pending_notification_storage.dart';
import 'experiment_service.dart';

class ReceivedNotification {
  final int id;
  final String title;
  final String body;
  final String payload;

  ReceivedNotification(this.id, this.title, this.body, this.payload);
}

class NotificationManager {
  static const ANDROID_NOTIFICATION_CHANNEL_ID = "com.taqo.survey.taqosurvey.NOTIFICATIONS";
  static const ANDROID_NOTIFICATION_CHANNEL_NAME = "Experiment Reminders";
  static const ANDROID_NOTIFICATION_CHANNEL_DESC = "Reminders to participate in Experiments";
  static const ANDROID_ICON = "paco256";
  static const ANDROID_SOUND = "deepbark_trial";

  static final _instance = NotificationManager._();

  final _plugin = FlutterLocalNotificationsPlugin();

  StreamController<ReceivedNotification> _receivedNotifications;
  StreamController<String> _selectedNotifications;

  Completer _initialized;

  NotificationManager._() {
    _init();
  }

  factory NotificationManager() => _instance;

  /// Gets the initial notification ID. Afterwards, the ID is just incremented.
  /// Using this method should allow for unique IDs that never overlap (ever)
  /// Note: Dart uses 64-bit ints but Android uses 32-bits
  Future<int> _getNextId() async {
    var max = -1;
    (await PendingNotifications.getInstance()).getAll().keys.forEach((k) {
      if (k != null && k > max) {
        max = k;
      }
    });
    return max + 1;
  }

  void _init() async {
    _initialized = Completer();
    WidgetsFlutterBinding.ensureInitialized();

    // For iOS only, when notification is received while app has foreground
    _receivedNotifications = StreamController<ReceivedNotification>();
    _selectedNotifications = StreamController<String>();

    final initSettingsAndroid = AndroidInitializationSettings(ANDROID_ICON);
    final initSettingsIOS = IOSInitializationSettings(
        onDidReceiveLocalNotification: (int id, String title, String body, String payload) async {
      // TODO Can we just add the payload to one Stream?
      _receivedNotifications.add(ReceivedNotification(id, title, body, payload));
    });

    final initSettings = InitializationSettings(initSettingsAndroid, initSettingsIOS);
    await _plugin.initialize(initSettings, onSelectNotification: (String payload) async {
      // TODO Is this all I need?
      _selectedNotifications.add(payload);
    });

    // Listen
    _receivedNotifications.stream.listen((ReceivedNotification notification) {
      _handleNotification(notification.payload);
    });
    _selectedNotifications.stream.listen((String payload) {
      _handleNotification(payload);
    });

    _initialized.complete();
  }

  void _handleNotification(String payload) async {
    await _initialized.future;
    getLaunchDetails().then((launchDetails) {
      if (!launchDetails.didNotificationLaunchApp) {
        openSurvey(payload);
      }
    });
  }

  void dispose() {
    if (_selectedNotifications != null) {
      _selectedNotifications.close();
    }
    if (_receivedNotifications != null) {
      _receivedNotifications.close();
    }
  }

  Future<NotificationAppLaunchDetails> getLaunchDetails() async =>
      await _plugin.getNotificationAppLaunchDetails();

  Future<void> openSurvey(String payload) async {
    final id = int.tryParse(payload);
    final notificationHolder = (await PendingNotifications.getInstance())[id];
    (await PendingNotifications.getInstance()).remove(id);

    if (notificationHolder == null) {
      print('No holder for payload: $payload');
      return;
    }

    try {
      final e = ExperimentService()
          .getJoinedExperiments()
          .firstWhere((e) => e.id == notificationHolder.experimentId);
      e.groups.firstWhere((g) => g.name == notificationHolder.experimentGroupName);
      MyApp.navigatorKey.currentState.pushReplacementNamed(SurveyPage.routeName,
          arguments: [e, notificationHolder.experimentGroupName]);
    } on StateError catch (e, stack) {
      print('StateError: $e');
      print(stack);
    }
  }

  Future<int> showNotification(ActionSpecification actionSpec) async {
    await _initialized.future;

    final int id = await _getNextId();
    var timeout = 59;
    if (actionSpec.action != null) {
      timeout = actionSpec.action.timeout ?? timeout;
    }
    final notification = NotificationHolder(
      id,
      actionSpec.time.millisecondsSinceEpoch,
      actionSpec.experiment.id,
      0,
      1000 * 60 * timeout,
      actionSpec.experimentGroup.name,
      actionSpec.actionTrigger.id,
      actionSpec.action?.id,
      null,
      actionSpec.action == null ? "Time to participate" : actionSpec.action.msgText,
      actionSpec.actionTriggerSpecId,
    );

    print('Showing notification id: $id @ ${actionSpec.time}');
    (await PendingNotifications.getInstance())[id] = notification;

    final androidDetails = AndroidNotificationDetails(
      ANDROID_NOTIFICATION_CHANNEL_ID,
      ANDROID_NOTIFICATION_CHANNEL_NAME,
      ANDROID_NOTIFICATION_CHANNEL_DESC,
      sound: ANDROID_SOUND,
    );
    final iOSDetails = IOSNotificationDetails();
    final details = NotificationDetails(androidDetails, iOSDetails);

    await _plugin.show(
        id, actionSpec.experiment.title, notification.message, details, payload: "$id");

    return id;
  }

  Future<int> scheduleNotification(ActionSpecification actionSpec) async {
    await _initialized.future;

    final int id = await _getNextId();
    var timeout = 59;
    if (actionSpec.action != null) {
      timeout = actionSpec.action.timeout ?? timeout;
    }
    final notification = NotificationHolder(
      id,
      actionSpec.time.millisecondsSinceEpoch,
      actionSpec.experiment.id,
      0,
      1000 * 60 * timeout,
      actionSpec.experimentGroup.name,
      actionSpec.actionTrigger.id,
      actionSpec.action?.id,
      null,
      actionSpec.action == null ? "Time to participate" : actionSpec.action.msgText,
      actionSpec.actionTriggerSpecId,
    );

    print('Scheduling notification id: $id @ ${actionSpec.time}');
    (await PendingNotifications.getInstance())[id] = notification;

    final androidDetails = AndroidNotificationDetails(
      ANDROID_NOTIFICATION_CHANNEL_ID,
      ANDROID_NOTIFICATION_CHANNEL_NAME,
      ANDROID_NOTIFICATION_CHANNEL_DESC,
      sound: ANDROID_SOUND,
    );
    final iOSDetails = IOSNotificationDetails();
    final details = NotificationDetails(androidDetails, iOSDetails);

    await _plugin.schedule(
        id, actionSpec.experiment.title, notification.message, actionSpec.time, details,
        payload: "$id", androidAllowWhileIdle: true);

    return id;
  }

  void cancelNotification(int id) async {
    try {
      _plugin.cancel(id);
    } on ArgumentError catch (e) {
      print("Error canceling notification id $id: $e");
    } on MissingPluginException catch (e) {
      print("Error canceling notification id $id: $e");
    }
    (await PendingNotifications.getInstance()).remove(id);
  }

  void cancelForExperiment(Experiment experiment) async {
    (await PendingNotifications.getInstance()).getAll().forEach((k, v) async {
      if (v.experimentId == experiment.id) {
        cancelNotification(k);
        (await PendingNotifications.getInstance()).remove(k);
      }
    });
  }

  void cancelAllNotifications() {
    try {
      _plugin.cancelAll();
    } on MissingPluginException catch (e) {
      print("Error canceling notifications: $e");
    }
  }
}
