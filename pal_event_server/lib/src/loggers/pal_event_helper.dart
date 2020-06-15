import 'dart:async';

import 'package:logging/logging.dart';
import 'package:taqo_common/model/event.dart';
import 'package:taqo_common/model/experiment.dart';
import 'package:taqo_common/storage/dart_file_storage.dart';
import 'package:taqo_common/util/zoned_date_time.dart';
import 'package:taqo_shared_prefs/taqo_shared_prefs.dart';

import '../experiment_service_local.dart';
import '../sqlite_database/sqlite_database.dart';
import '../utils.dart';

const appNameField = 'WM_CLASS';
const windowNameField = '_NET_WM_NAME';
const urlNameField = '_NET_URL_NAME';

final _logger = Logger('PalEventHelper');

typedef CreateEventFunc = Future<Event> Function(
    Experiment experiment, String groupname, Map<String, dynamic> response);

Future<List<Event>> createLoggerPacoEvents(Map<String, dynamic> response,
    {CreateEventFunc pacoEventCreator}) async {
  final events = <Event>[];

  final storageDir = DartFileStorage.getLocalStorageDir().path;
  final sharedPrefs = TaqoSharedPrefs(storageDir);
  final experimentService = await ExperimentServiceLocal.getInstance();
  final experiments = await experimentService.getJoinedExperiments();

  for (var e in experiments) {
    final paused = await sharedPrefs.getBool("${sharedPrefsExperimentPauseKey}_${e.id}");
    if (e.isOver() || (paused ?? false)) {
      continue;
    }

    for (var g in e.groups) {
      if (g.isAppUsageLoggingGroup) {
        events.add(await pacoEventCreator(e, g.name, response));
      }
    }
  }

  return events;
}

const _participantId = 'participantId';
const _responseName = 'name';
const _responseAnswer = 'answer';

Event _createPacoEvent(Experiment experiment, String groupName) {
  var group;
  try {
    group = experiment.groups.firstWhere((g) => g.name == groupName);
  } catch (e) {
    _logger.warning('Failed to get experiment group $groupName for $experiment');
  }

  final event = Event.of(experiment, group);
  event.responseTime = ZonedDateTime.now();

  event.responses = <String, dynamic>{
      _responseName: _participantId,
      _responseAnswer: 'TODO:participantId',
  };

  return event;
}

const _loggerStarted = 'started';
const _loggerStopped = 'stopped';

Future<Event> createLoggerStatusPacoEvent(Experiment experiment, String groupName,
    String loggerName, bool status) async {
  final event = await _createPacoEvent(experiment, groupName);
  final responses = <String, dynamic>{
    loggerName: status ? _loggerStarted : _loggerStopped,
  };
  event.responses.addAll(responses);
  return event;
}

const appsUsedKey = 'apps_used';
const _appContentKey = 'app_content';
const _appsUsedRawKey = 'apps_used_raw';

Future<Event> createAppUsagePacoEvent(Experiment experiment, String groupName,
    Map<String, dynamic> response) async {
  final event = await _createPacoEvent(experiment, groupName);
  final responses = <String, dynamic>{
      appsUsedKey: response[appNameField],
      _appContentKey: response[windowNameField],
      _appsUsedRawKey: '${response[appNameField]}:${response[windowNameField]}',
  };
  event.responses.addAll(responses);
  return event;
}

//const _uidKey = 'uid';
const _pidKey = 'pid';
const cmdRawKey = 'cmd_raw';
const _cmdRetKey = 'cmd_ret';

Future<Event> createCmdUsagePacoEvent(Experiment experiment, String groupName,
    Map<String, dynamic> response) async {
  final event = await _createPacoEvent(experiment, groupName);
  final responses = <String, String>{
      //_uidKey: response[_uidKey],
      _pidKey: '${response[_pidKey]}',
      _cmdRetKey: '${response[_cmdRetKey]}',
      cmdRawKey: response[cmdRawKey].trim(),
  };
  event.responses.addAll(responses);
  return event;
}

void storePacoEvent(List<Event> events) async {
  final database = await SqliteDatabase.get();
  for (var e in events) {
    await database.insertEvent(e);
  }
}
