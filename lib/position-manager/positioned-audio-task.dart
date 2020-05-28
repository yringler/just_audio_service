import 'dart:isolate';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio_service/background/audio-task-decorator.dart';
import 'package:just_audio_service/position-manager/position-data-manager.dart';
import 'package:just_audio_service/position-manager/position-manager.dart';

/// The background component to [PositionManager]. Decorates an audio task by persisting
/// current media position, if it has an ID.
class PositionedAudioTask extends AudioTaskDecorater {
  static const String SendPortID = "position_send_port";
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
  }

  // TODO: Implement
  void _answerPortMessage(message) {}
}
