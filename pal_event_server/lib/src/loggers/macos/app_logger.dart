import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:taqo_common/model/event.dart';
import 'package:taqo_common/model/interrupt_cue.dart';

import '../../triggers/triggers.dart';
import '../loggers.dart';
import '../pal_event_helper.dart';
import 'apple_script_util.dart' as apple_script;

final _logger = Logger('AppLogger');

const _queryInterval = const Duration(seconds: 1);

String _prevWindowName;

// Isolate entry point must be a top-level function (or static?)
// Query xprop for the active window
void _appLoggerIsolate(SendPort sendPort) {
  Timer.periodic(_queryInterval, (Timer _) {
    Process.run(apple_script.command, apple_script.scriptArgs).then((result) {
      final currWindow = result.stdout.trim();
      final resultMap = apple_script.buildResultMap(currWindow);
      final currWindowName = resultMap[apple_script.appNameField];

      if (currWindowName != _prevWindowName) {
        // Send APP_CLOSED
        if (_prevWindowName != null && _prevWindowName.isNotEmpty) {
          sendPort.send(_prevWindowName);
        }

        _prevWindowName = currWindowName;

        // Send PacoEvent && APP_USAGE
        if (resultMap != null) {
          sendPort.send(resultMap);
        }
      }
    });
  });
}

class AppLogger extends PacoEventLogger with EventTriggerSource {
  static const appUsageLoggerName = 'app_usage_logger';
  static const Object _isolateDiedObj = Object();
  static AppLogger _instance;

  // Port for the main Isolate to receive msg from AppLogger Isolate
  ReceivePort _receivePort;
  // Background Isolate that will poll for the active window
  Isolate _isolate;

  // List of Events that should be sent to PAL
  final _eventsToSend = <Event>[];

  AppLogger._() : super(appUsageLoggerName);

  factory AppLogger() {
    if (_instance == null) {
      _instance = AppLogger._();
    }
    return _instance;
  }

  @override
  void start(List<ExperimentLoggerInfo> experiments) async {
    if (active) {
      return;
    }

    _logger.info('Starting AppLogger');
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_appLoggerIsolate, _receivePort.sendPort);
    _isolate.addOnExitListener(_receivePort.sendPort, response: _isolateDiedObj);
    _receivePort.listen(_listen);
    active = true;

    Timer.periodic(sendInterval, (Timer t) {
      final events = List.of(_eventsToSend);
      _eventsToSend.clear();
      sendToPal(events, t);
    });

    // Create Paco Events
    super.start(experiments);
  }

  @override
  void stop(List<ExperimentLoggerInfo> experiments) async {
    if (!active) {
      return;
    }

    // Create Paco Events
    await super.stop(experiments);

    if (experimentsBeingLogged.isEmpty) {
      // No more experiments -- shut down
      _logger.info('Stopping AppLogger');
      active = false;
      _isolate?.kill();
      _receivePort?.close();
    }
  }

  void _listen(dynamic data) async {
    if (data == _isolateDiedObj) {
      // The background Isolate died
      _isolate?.kill();
      _receivePort?.close();
      if (active) {
        start(experimentsBeingLogged);
      }
      return;
    }

    if (data is Map && data.isNotEmpty) {
      print(data);
      final pacoEvents = await createLoggerPacoEvents(data, pacoEventCreator: createAppUsagePacoEvent);
      _eventsToSend.addAll(pacoEvents);

      final triggerEvents = <TriggerEvent>[];
      for (final e in pacoEvents) {
        triggerEvents.add(createEventTriggers(InterruptCue.APP_USAGE, e.responses[appsUsedKey]));
      }
      broadcastEventsForTriggers(triggerEvents);
    } else if (data is String && data.isNotEmpty) {
      final triggerEvent = createEventTriggers(InterruptCue.APP_CLOSED, data);
      broadcastEventsForTriggers(<TriggerEvent>[triggerEvent]);
    }
  }
}
