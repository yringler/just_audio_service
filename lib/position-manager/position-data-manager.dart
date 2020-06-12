import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:hive/hive.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:just_audio_service/position-manager/position.dart';
import 'package:just_audio_service/position-manager/positioned-audio-task.dart';
import 'package:path_provider/path_provider.dart';

/// Save position, and get it back.
abstract class IPositionDataManager {
  Future<Duration> getPosition(String id);

  Future<List<Position>> getPositions(List<String> ids);

  Future<void> setPosition(Position position);

  Future<void> init() async {}
  Future<void> close() async {}
}

/// Wrapper around the two position manager implementations.
/// If the audio task is running, interacts with it to get/set postions.
/// Otherwise, uses disk.
class PositionDataManager extends IPositionDataManager {
  final HivePositionDataManager _hiveManager = HivePositionDataManager();
  final AudioServicePositionManager _serviceManager =
      AudioServicePositionManager();

  PositionDataManager() {
    // Disconnect hive whenever audio state is running.
    AudioService.playbackStateStream
        .map((state) =>
            (state?.processingState ?? AudioProcessingState.none) !=
            AudioProcessingState.none)
        .distinct()
        .where((isAudioServiceRunning) => isAudioServiceRunning)
        .listen((isAudioServiceRunning) {
      _hiveManager.close();
    });
  }

  IPositionDataManager get _activeManager =>
      AudioService.running ? _serviceManager : _hiveManager;

  @override
  Future<Duration> getPosition(String id) => _activeManager.getPosition(id);

  @override
  Future<List<Position>> getPositions(List<String> ids) =>
      _activeManager.getPositions(ids);

  @override
  Future<void> setPosition(Position position) =>
      _activeManager.setPosition(position);
}

/// Saves position to disk.
class HivePositionDataManager extends IPositionDataManager {
  static final positionHive = HiveImpl();
  static const positionBoxName = "positions";
  static const int maxSavedPositions = 2000;

  Box<Position> positionBox;
  HivePositionDataManager();

  /// Connect to disk storage.
  @override
  Future<void> init() async {
    if (positionHive.isBoxOpen(positionBoxName)) {
      return;
    } else {
      try {
        final hivePath = await getApplicationDocumentsDirectory();

        positionHive.init("${hivePath.path}/just_audio_service_hive");
        positionHive.registerAdapter(PositionAdapter());
      } catch (ex) {
        print("Error opening hive: position");
        print(ex);
      }
    }

    positionBox = await positionHive.openBox<Position>(positionBoxName);

    await _constrainBoxSize();
  }

  @override

  /// Close connection to disk storage.
  /// This is done to allow a diffirent isolate access.
  Future<void> close() async {
    await positionHive.close();
  }

  Future<Duration> getPosition(String id) async =>
      (await getPositions([id]))[0].position;

  Future<List<Position>> getPositions(List<String> ids) async {
    await init();
    return ids
        .map((id) =>
            positionBox.get(id) ?? Position(id: id, position: Duration.zero))
        .toList();
  }

  Future<void> setPosition(Position position) async {
    await init();

    if (position.position != Duration.zero) {
      await positionBox.put(position.id, position);
    } else {
      // No need to clutter the DB with zeros - that's the default, anyway.
      await positionBox.delete(position.id);
    }
  }

  /// Make sure we don't try to hold too many positions in memory.
  Future<void> _constrainBoxSize() async {
    int amountPositionsToDelete = positionBox.length - maxSavedPositions;

    if (amountPositionsToDelete < 1) {
      return;
    }

    final positions = positionBox.values.toList();
    positions.sort((p1, p2) =>
        p2.createdDate.millisecondsSinceEpoch -
        p1.createdDate.millisecondsSinceEpoch);
    final positionsToDelete = positions.take(amountPositionsToDelete);

    await Stream.fromFutures(
        positionsToDelete.map((position) => position.delete())).last;
  }
}

/// Saves and retrieves position by interacting with the background audio task isolate.
class AudioServicePositionManager extends IPositionDataManager {
  @override
  Future<Duration> getPosition(String id) async =>
      (await getPositions([id])).first.position;

  @override
  Future<List<Position>> getPositions(List<String> ids) async {
    final sendPort =
        IsolateNameServer.lookupPortByName(PositionedAudioTask.SendPortID);

    if (sendPort == null) {
      return null;
    }

    final receivePort = ReceivePort();
    sendPort.send(
        [receivePort.sendPort, PositionedAudioTask.GetPositionsCommand, ids]);
    final positions = await receivePort.first;
    receivePort.close();

    return (positions as List).cast<List>().map((positionList) {
      final id = positionList[0] as String;
      final positionMilliseconds = positionList[1] as int;

      return Position(
          id: id, position: Duration(milliseconds: positionMilliseconds));
    }).toList();
  }

  @override
  Future<void> setPosition(Position position) async {
    final sendPort =
        IsolateNameServer.lookupPortByName(PositionedAudioTask.SendPortID);

    if (sendPort == null) {
      return null;
    }

    final receivePort = ReceivePort();
    sendPort.send([
      receivePort.sendPort,
      PositionedAudioTask.SetPositionCommand,
      position.id,
      position.position.inMilliseconds
    ]);
    await receivePort.first;
  }
}
