import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:hive/hive.dart';
import 'package:just_audio_service/position-manager/position.dart';
import 'package:just_audio_service/position-manager/positioned-audio-task.dart';

abstract class IPositionDataManager {
  Future<Duration> getPosition(String id);

  Future<List<Position>> getPositions(List<String> ids);

  Future<void> setPosition(String id, Duration position);
}

class PositionDataManager implements IPositionDataManager {
  final HivePositionDataManager _hiveManager;
  final AudioServicePositionManager _serviceManager =
      AudioServicePositionManager();

  PositionDataManager({String storePath})
      : _hiveManager = HivePositionDataManager(storePath: storePath);

  IPositionDataManager get _activeManager => AudioService.connected ? _serviceManager : _hiveManager;

  Future<void> isStartingAudioService() async {
    await _hiveManager.closeStorage();
  }

  @override
  Future<Duration> getPosition(String id) => _activeManager.getPosition(id);

  @override
  Future<List<Position>> getPositions(List<String> ids) => _activeManager.getPositions(ids);

  @override
  Future<void> setPosition(String id, Duration position) => _activeManager.setPosition(id, position);
}

class HivePositionDataManager implements IPositionDataManager {
  static const positionBoxName = "positions";
  static const int maxSavedPositions = 2000;

  final String storePath;
  Box<Position> positionBox;
  HivePositionDataManager({this.storePath});

  /// Connect to disk storage.
  Future<void> openStorage() async {
    if (!Hive.isBoxOpen(positionBoxName)) {
      Hive.init(storePath);
      Hive.registerAdapter(PositionAdapter());
    }

    positionBox = await Hive.openBox<Position>(positionBoxName);

    await _constrainBoxSize();
  }

  /// Close connection to disk storage.
  /// This is done to allow a diffirent isolate access.
  Future<void> closeStorage() async {
    await Hive.close();
  }

  Future<Duration> getPosition(String id) async {
    assert(Hive.isBoxOpen(positionBoxName));
    return positionBox.get(id) ?? Duration.zero;
  }

  Future<List<Position>> getPositions(List<String> ids) async {
    assert(Hive.isBoxOpen(positionBoxName));

    return ids.map((id) => positionBox.get(id)).toList();
  }

  Future<void> setPosition(String id, Duration position) async {
    assert(Hive.isBoxOpen(positionBoxName));
    await positionBox.put(id, Position(position: position));
  }

  /// Make sure we don't try to hold too many positions in memory.
  /// TODO: Implement
  Future<void> _constrainBoxSize() async {}
}

class AudioServicePositionManager implements IPositionDataManager {
  @override
  Future<Duration> getPosition(String id) async {
    final sendPort =
        IsolateNameServer.lookupPortByName(PositionedAudioTask.SendPortID);

    if (sendPort == null) {
      return null;
    }

    final receivePort = ReceivePort();
    sendPort.send([receivePort.sendPort, id]);

    final positionMilliseconds = await receivePort.first;
    receivePort.close();

    return Duration(milliseconds: positionMilliseconds);
  }

  @override
  Future<List<Position>> getPositions(List<String> ids) async {
    final sendPort =
        IsolateNameServer.lookupPortByName(PositionedAudioTask.SendPortID);

    if (sendPort == null) {
      return null;
    }

    final receivePort = ReceivePort();
    sendPort.send([receivePort.sendPort, ids]);
    final positions = await receivePort.first;
    receivePort.close();

    return (positions as List).cast<List>().map((positionList) {
      final id = positionList[0] as String;
      final positionMilliseconds = positionList[1] as int;

      return Position(
          id: id, position: Duration(milliseconds: positionMilliseconds));
    });
  }

  @override
  Future<void> setPosition(String id, Duration position) async {
    final sendPort =
        IsolateNameServer.lookupPortByName(PositionedAudioTask.SendPortID);

    if (sendPort == null) {
      return null;
    }

    final receivePort = ReceivePort();
    sendPort.send([receivePort.sendPort, id, position.inMilliseconds]);
    await receivePort.first;
  }
}
