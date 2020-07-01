import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../../pal_event_helper.dart';
import '../app_logger.dart';
import 'apple_script_util.dart' as apple_script;

String _prevWindowName;

// Isolate entry point must be a top-level function (or static?)
// Run Apple Script for the active window
void macOSAppLoggerIsolate(SendPort sendPort) {
  Timer.periodic(queryInterval, (Timer _) {
    Process.run(apple_script.command, apple_script.scriptArgs).then((result) {
      final currWindow = result.stdout.trim();
      final resultMap = apple_script.buildResultMap(currWindow);
      final currWindowName = resultMap[appNameField];

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
