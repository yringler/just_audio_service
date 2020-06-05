import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio_service/background/audio-task-decorator.dart';
import 'package:just_audio_service/background/icontext-audio-task.dart';
import 'package:just_audio_service/position-manager/position-data-manager.dart';
import 'package:just_audio_service/position-manager/position-manager.dart';
import 'package:just_audio_service/position-manager/position.dart';

typedef Future<IPositionDataManager> PositionDataManagerFactory();

/// The background component to [PositionManager]. Decorates an audio task by persisting
/// current media position, if it has an ID.
class PositionedAudioTask extends AudioTaskDecorater {
  static const String SendPortID = 'position_send_port';
  static const String GetPositionsCommand = 'getPosition';
  static const String SetPositionCommand = 'setPosition';

  final PositionDataManagerFactory positionDataManagerFactory;
  IPositionDataManager dataManager;

  final ReceivePort _receivePort = ReceivePort();

  /// Messages can come in before any backing data service is initilized.
  /// Here, we keep track of when things are ready. This is awaited in [_answerPortMessage(message)].
  final Completer<void> _readyToAnswerMessages = Completer();

  PositionedAudioTask(
      {IContextAudioTask audioTask, this.positionDataManagerFactory})
      : super(baseTask: audioTask) {
    IsolateNameServer.removePortNameMapping(SendPortID);
    IsolateNameServer.registerPortWithName(_receivePort.sendPort, SendPortID);

    _receivePort.listen((data) => _answerPortMessage(data as List<dynamic>));
  }

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    dataManager ??= await positionDataManagerFactory();
    await dataManager.init();
    _readyToAnswerMessages.complete();

    final subscription = context.mediaStateStream
        // The only thing we don't want to update for is stopped.
        // stop - is tricky, because by convention stop means to reset the saved position, but
        // currently [onStop()] is also called if user kills background service manually, eg by
        // swiping away the notification.
        // I opened up an issue with audio_service, for now I'll persist in the [onStop()] callback.
        .where((event) =>
            event.playing ||
            event.processingState == AudioProcessingState.ready)
        .listen((state) => dataManager.setPosition(Position(
            id: context.mediaItem.id, position: state.currentPosition)));

    await baseTask.onStart(params);

    IsolateNameServer.removePortNameMapping(SendPortID);
    _receivePort.close();
    subscription.cancel();
    await dataManager.close();
  }

  @override
  void onStop() => _onStop();
  Future<void> _onStop() async {
    await dataManager.setPosition(Position(
        id: context.mediaItem.id,
        position: context.playBackState.currentPosition));
    super.onStop();
  }

  /// Send the correct response according to the message that we recieved from
  /// the UI isolate.
  /// The first item in the list will always be a [SendPort].
  /// The second is the name of the command, for example [GetPositionsCommand].
  void _answerPortMessage(List<dynamic> message) async {
    await _readyToAnswerMessages.future;

    final sendPort = message[0] as SendPort;
    final command = message[1] as String;

    switch (command) {
      case GetPositionsCommand:

        /// The final arguments are the IDs to retrieve.
        final idsToGetPositionOf = (message[2] as List<dynamic>).cast<String>();
        final sendablePositions = (await dataManager
                .getPositions(idsToGetPositionOf))
            .map((position) => [position.id, position.position.inMilliseconds])
            .toList();
        sendPort.send(sendablePositions);
        break;
      case SetPositionCommand:

        /// The final arguments are the ID and position to set.
        final idToSet = message[2] as String;
        final position = Position(
            id: idToSet, position: Duration(milliseconds: message[3] as int));
        await dataManager.setPosition(position);
        break;
    }
  }
}
