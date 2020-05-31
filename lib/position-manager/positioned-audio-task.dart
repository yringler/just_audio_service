import 'dart:isolate';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio_service/background/audio-task-decorator.dart';
import 'package:just_audio_service/position-manager/position-data-manager.dart';
import 'package:just_audio_service/position-manager/position-manager.dart';
import 'package:just_audio_service/position-manager/position.dart';

/// The background component to [PositionManager]. Decorates an audio task by persisting
/// current media position, if it has an ID.
class PositionedAudioTask extends AudioTaskDecorater {
  static const String SendPortID = 'position_send_port';
  static const String GetPositionsCommand = 'getPosition';
  static const String SetPositionCommand = 'setPosition';

  final String storePath;
  final HivePositionDataManager dataManager;
  ReceivePort _receivePort;

  PositionedAudioTask({BackgroundAudioTask audioTask, this.storePath})
      : this.dataManager = HivePositionDataManager(storePath: storePath),
        super(baseTask: audioTask);

  @override
  Future<void> onStart() async {
    await dataManager.openStorage();
    _receivePort = ReceivePort();

    IsolateNameServer.removePortNameMapping(SendPortID);
    IsolateNameServer.registerPortWithName(_receivePort.sendPort, SendPortID);

    _receivePort.listen(_answerPortMessage);

    await baseTask.onStart();
    IsolateNameServer.removePortNameMapping(SendPortID);
    _receivePort.close();
    await dataManager.closeStorage();
  }

  void _answerPortMessage(List<dynamic> message) async {
    final sendPort = message[0] as SendPort;
    final command = message[1] as String;

    switch (command) {
      case GetPositionsCommand:
        final idsToGetPositionOf = (message[2] as List<dynamic>).cast<String>();
        final sendablePositions = (await dataManager
                .getPositions(idsToGetPositionOf))
            .map((position) => [position.id, position.position.inMilliseconds]);
        sendPort.send(sendablePositions);
        break;
      case SetPositionCommand:
        final idToSet = message[2] as String;
        final position = Position(
            id: idToSet, position: Duration(milliseconds: message[3] as int));
        await dataManager.setPosition(position);
        break;
    }
  }
}
