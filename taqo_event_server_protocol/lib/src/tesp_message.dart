import 'dart:convert';
import 'dart:typed_data';

import 'package:taqo_common/model/event.dart';
import 'package:taqo_event_server_protocol/src/json_utils.dart';

abstract class TespMessage {
  /// The response/request code for the message, which must fit in an 8-bit
  /// unsigned integer (0x00-0xFF).
  int get code;

  static const tespCodeRequestPalAddEvent = 0x01;
  static const tespCodeRequestPalPause = 0x02;
  static const tespCodeRequestPalResume = 0x04;
  static const tespCodeRequestPalWhiteListDataOnly = 0x06;
  static const tespCodeRequestPalAllData = 0x08;
  static const tespCodeRequestPing = 0x0A;

  static const tespCodeRequestAlarmSchedule = 0x10;
  static const tespCodeRequestAlarmCancel = 0x11;
  static const tespCodeRequestAlarmSelectAll = 0x12;
  static const tespCodeRequestAlarmSelectById = 0x13;

  static const tespCodeRequestNotificationCheckActive = 0x20;
  static const tespCodeRequestNotificationCancel = 0x21;
  static const tespCodeRequestNotificationCancelByExperiment = 0x23;
  static const tespCodeRequestNotificationSelectAll = 0x24;
  static const tespCodeRequestNotificationSelectById = 0x25;
  static const tespCodeRequestNotificationSelectByExperiment = 0x27;

  static const tespCodeRequestCreateMissedEvent = 0x31;

  static const tespCodeResponseSuccess = 0x80;
  static const tespCodeResponseError = 0x81;
  static const tespCodeResponsePaused = 0x82;
  static const tespCodeResponseInvalidRequest = 0x83;
  static const tespCodeResponseAnswer = 0x85;

  TespMessage();

  /// Create an instance of [TespMessage] with proper subtype corresponding to the
  /// message [code].
  factory TespMessage.fromCode(int code, [Uint8List encodedPayload]) {
    switch (code) {
      case tespCodeRequestPalAddEvent:
        return TespRequestPalAddEvent.withEncodedPayload(encodedPayload);
      case tespCodeRequestPalPause:
        return TespRequestPalPause();
      case tespCodeRequestPalResume:
        return TespRequestPalResume();
      case tespCodeRequestPalWhiteListDataOnly:
        return TespRequestPalWhiteListDataOnly();
      case tespCodeRequestPalAllData:
        return TespRequestPalAllData();
      case tespCodeRequestPing:
        return TespRequestPing();
      case tespCodeRequestAlarmSchedule:
        return TespRequestAlarmSchedule();
      case tespCodeRequestAlarmCancel:
        return TespRequestAlarmCancel.withEncodedPayload(encodedPayload);
      case tespCodeRequestAlarmSelectAll:
        return TespRequestAlarmSelectAll();
      case tespCodeRequestAlarmSelectById:
        return TespRequestAlarmSelectById.withEncodedPayload(encodedPayload);
      case tespCodeRequestNotificationCheckActive:
        return TespRequestNotificationCheckActive();
      case tespCodeRequestNotificationCancel:
        return TespRequestNotificationCancel.withEncodedPayload(encodedPayload);
      case tespCodeRequestNotificationCancelByExperiment:
        return TespRequestNotificationCancelByExperiment.withEncodedPayload(
            encodedPayload);
      case tespCodeRequestNotificationSelectAll:
        return TespRequestNotificationSelectAll();
      case tespCodeRequestNotificationSelectById:
        return TespRequestNotificationSelectById.withEncodedPayload(
            encodedPayload);
      case tespCodeRequestNotificationSelectByExperiment:
        return TespRequestNotificationSelectByExperiment.withEncodedPayload(
            encodedPayload);
      case tespCodeRequestCreateMissedEvent:
        return TespRequestCreateMissedEvent.withEncodedPayload(encodedPayload);
      case tespCodeResponseSuccess:
        return TespResponseSuccess();
      case tespCodeResponseError:
        return TespResponseError.withEncodedPayload(encodedPayload);
      case tespCodeResponsePaused:
        return TespResponsePaused();
      case tespCodeResponseInvalidRequest:
        return TespResponseInvalidRequest.withEncodedPayload(encodedPayload);
      case tespCodeResponseAnswer:
        return TespResponseAnswer.withEncodedPayload(encodedPayload);
      default:
        throw ArgumentError.value(code, null, 'Invalid message code');
    }
  }
}

abstract class TespRequest extends TespMessage {}

abstract class TespResponse extends TespMessage {}

mixin Payload<T> on TespMessage {
  static S identity<S>(S x) => x;
  static final jsonFactories = <Type, Function>{
    Object: identity,
    String: identity,
    int: identity,
    Event: (json) => Event.fromJson(json),
  };
  final _codec = (T == String ? utf8 : json.fuse(utf8));

  Uint8List _encodedPayload;
  T _payload;

  T get payload => _payload;

  Uint8List get encodedPayload {
    _encodedPayload ??= _codec.encode(_payload);
    return _encodedPayload;
  }

  void setPayload(T payload) {
    if (payload == null) {
      throw ArgumentError('payload must not be null for $runtimeType');
    }
    if (_payload == null) {
      _payload = payload;
    } else {
      throw StateError('payload cannot be set twice');
    }
  }

  void setPayloadWithEncoded(Uint8List encodedPayload) {
    if (encodedPayload == null) {
      throw ArgumentError('encodedPayload must not be null for $runtimeType');
    }
    setPayload(jsonFactories[T](_codec.decode(encodedPayload)));
    _encodedPayload = encodedPayload;
  }
}

class TespRequestPalAddEvent extends TespRequest with Payload<Event> {
  @override
  final code = TespMessage.tespCodeRequestPalAddEvent;

  Event get event => payload;

  TespRequestPalAddEvent(Event event) {
    setPayload(event);
  }
  TespRequestPalAddEvent.withEventJson(json) {
    setPayload(Event.fromJson(json));
  }
  TespRequestPalAddEvent.withEncodedPayload(Uint8List encodedPayload) {
    setPayloadWithEncoded(encodedPayload);
  }
}

class TespRequestPalPause extends TespRequest {
  @override
  final code = TespMessage.tespCodeRequestPalPause;
}

class TespRequestPalResume extends TespRequest {
  @override
  final code = TespMessage.tespCodeRequestPalResume;
}

class TespRequestPalWhiteListDataOnly extends TespRequest {
  @override
  final code = TespMessage.tespCodeRequestPalWhiteListDataOnly;
}

class TespRequestPalAllData extends TespRequest {
  @override
  final code = TespMessage.tespCodeRequestPalAllData;
}

class TespRequestPing extends TespRequest {
  @override
  final code = TespMessage.tespCodeRequestPing;
}

class TespRequestAlarmSchedule extends TespRequest {
  @override
  final code = TespMessage.tespCodeRequestAlarmSchedule;
}

class TespRequestAlarmCancel extends TespRequest with Payload<int> {
  @override
  final code = TespMessage.tespCodeRequestAlarmCancel;

  int get alarmId => payload;

  TespRequestAlarmCancel(int alarmId) {
    setPayload(alarmId);
  }

  TespRequestAlarmCancel.withEncodedPayload(Uint8List encodedPayload) {
    setPayloadWithEncoded(encodedPayload);
  }
}

class TespRequestAlarmSelectAll extends TespRequest {
  @override
  final code = TespMessage.tespCodeRequestAlarmSelectAll;
}

class TespRequestAlarmSelectById extends TespRequest with Payload<int> {
  @override
  final code = TespMessage.tespCodeRequestAlarmSelectById;

  int get alarmId => payload;

  TespRequestAlarmSelectById(int alarmId) {
    setPayload(alarmId);
  }

  TespRequestAlarmSelectById.withEncodedPayload(Uint8List encodedPayload) {
    setPayloadWithEncoded(encodedPayload);
  }
}

class TespRequestNotificationCheckActive extends TespRequest {
  @override
  final code = TespMessage.tespCodeRequestNotificationCheckActive;
}

class TespRequestNotificationCancel extends TespRequest with Payload<int> {
  @override
  final code = TespMessage.tespCodeRequestNotificationCancel;

  int get notificationId => payload;

  TespRequestNotificationCancel(int notificationId) {
    setPayload(notificationId);
  }

  TespRequestNotificationCancel.withEncodedPayload(Uint8List encodedPayload) {
    setPayloadWithEncoded(encodedPayload);
  }
}

class TespRequestNotificationCancelByExperiment extends TespRequest
    with Payload<int> {
  @override
  final code = TespMessage.tespCodeRequestNotificationCancelByExperiment;

  int get experimentId => payload;

  TespRequestNotificationCancelByExperiment(int experimentId) {
    setPayload(experimentId);
  }

  TespRequestNotificationCancelByExperiment.withEncodedPayload(
      Uint8List encodedPayload) {
    setPayloadWithEncoded(encodedPayload);
  }
}

class TespRequestNotificationSelectAll extends TespRequest {
  @override
  final code = TespMessage.tespCodeRequestNotificationSelectAll;
}

class TespRequestNotificationSelectById extends TespRequest with Payload<int> {
  @override
  final code = TespMessage.tespCodeRequestNotificationSelectById;

  int get notificationId => payload;

  TespRequestNotificationSelectById(int notificationId) {
    setPayload(notificationId);
  }

  TespRequestNotificationSelectById.withEncodedPayload(
      Uint8List encodedPayload) {
    setPayloadWithEncoded(encodedPayload);
  }
}

class TespRequestNotificationSelectByExperiment extends TespRequest
    with Payload<int> {
  @override
  final code = TespMessage.tespCodeRequestNotificationSelectByExperiment;

  int get experimentId => payload;

  TespRequestNotificationSelectByExperiment(int experimentId) {
    setPayload(experimentId);
  }

  TespRequestNotificationSelectByExperiment.withEncodedPayload(
      Uint8List encodedPayload) {
    setPayloadWithEncoded(encodedPayload);
  }
}

class TespRequestCreateMissedEvent extends TespRequest with Payload<Event> {
  @override
  final code = TespMessage.tespCodeRequestCreateMissedEvent;

  Event get event => payload;

  TespRequestCreateMissedEvent(Event event) {
    setPayload(event);
  }
  TespRequestCreateMissedEvent.withEventJson(json) {
    setPayload(Event.fromJson(json));
  }
  TespRequestCreateMissedEvent.withEncodedPayload(Uint8List encodedPayload) {
    setPayloadWithEncoded(encodedPayload);
  }
}

class TespResponseSuccess extends TespResponse {
  @override
  final code = TespMessage.tespCodeResponseSuccess;
}

class TespResponseError extends TespResponse with Payload<String> {
  @override
  final code = TespMessage.tespCodeResponseError;

  static const tespServerErrorUnknown = 'server-unknown';
  static const tespClientErrorResponseTimeout = 'client-response-timeout';
  static const tespClientErrorServerCloseEarly = 'client-server-close-early';
  static const tespClientErrorLostConnection = 'client-lost-connection';
  static const tespClientErrorChunkTimeout = 'client-chunk-timeout';
  static const tespClientErrorDecoding = 'client-decoding-error';
  static const tespClientErrorPayloadDecoding = 'client-payload-decoding-error';
  static const tespClientErrorUnknown = 'client-unknown';

  static const _jsonKeyCode = 'code';
  static const _jsonKeyMessage = 'message';
  static const _jsonKeyDetails = 'details';

  String _errorCode;
  String _errorMessage;
  String _errorDetails;

  String get errorCode => _errorCode;
  String get errorMessage => _errorMessage;
  String get errorDetails => _errorDetails;

  TespResponseError.withEncodedPayload(Uint8List encodedPayload) {
    setPayloadWithEncoded(encodedPayload);
    var error = json.decode(payload);
    _errorCode = error[_jsonKeyCode];
    _errorMessage = error[_jsonKeyMessage];
    _errorDetails = error[_jsonKeyDetails];
  }

  TespResponseError(this._errorCode, [this._errorMessage, this._errorDetails]) {
    var payload = json.encode({
      _jsonKeyCode: errorCode,
      _jsonKeyMessage: errorMessage,
      _jsonKeyDetails: errorDetails
    });
    setPayload(payload);
  }
}

class TespResponsePaused extends TespResponse {
  @override
  final code = TespMessage.tespCodeResponsePaused;
}

class TespResponseInvalidRequest extends TespResponse with Payload<String> {
  @override
  final code = TespMessage.tespCodeResponseInvalidRequest;

  TespResponseInvalidRequest.withPayload(String payload) {
    setPayload(payload);
  }
  TespResponseInvalidRequest.withEncodedPayload(Uint8List encodedPayload) {
    setPayloadWithEncoded(encodedPayload);
  }
}

class TespResponseAnswer extends TespResponse with Payload<Object> {
  @override
  final code = TespMessage.tespCodeResponseAnswer;

  TespResponseAnswer(dynamic object) : this.withJson(toJsonObject(object));

  TespResponseAnswer.withJson(Object json) {
    setPayload(json);
  }

  TespResponseAnswer.withEncodedPayload(Uint8List encodedPayload) {
    setPayloadWithEncoded(encodedPayload);
  }
}

/// This type of message should never be encoded or transported. It can be added
/// to a stream of TespMessage as an event to be processed.
abstract class TespEvent implements TespResponse, TespRequest {
  @override
  final code = null;
}

/// [TespEventMessageArrived] can be fired when the TESP decoder receives the last
/// byte of the encoded message, but may not have processed it.
class TespEventMessageArrived extends TespEvent {}

/// [TespEventMessageExpected] can be fired when the TESP decoder receives the
/// header of a message, but the rest of the message may be yet to arrive.
class TespEventMessageExpected extends TespEvent {}
