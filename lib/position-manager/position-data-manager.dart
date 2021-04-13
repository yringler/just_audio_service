import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:hive/hive.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:just_audio_service/position-manager/position.dart';
import 'package:just_audio_service/position-manager/positioned-audio-task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dart_extensions/dart_extensions.dart';

/// Save position, and get it back.
abstract class IPositionDataManager {
  Future<Duration> getPosition(String id);

  Future<List<Position>?> getPositions(List<String> ids);

  Future<void> setPosition(Position position);

  Future<void> init() async {}
  Future<void> close() async {}
}

/// Wrapper around the two position manager implementations.
/// If the audio task is running, interacts with it to get/set postions.
/// Otherwise, uses disk.
class PositionDataManager extends IPositionDataManager {
  HivePositionDataManager? _hiveManager;
  final AudioServicePositionManager _serviceManager =
      AudioServicePositionManager();

  PositionDataManager() {
    // Disconnect hive whenever audio state is running.
    AudioService.playbackStateStream
        .map((state) => (state.processingState) != AudioProcessingState.none)
        .distinct()
        .where((isAudioServiceRunning) => isAudioServiceRunning)
        .listen((isAudioServiceRunning) {
      _hiveManager?.close();
      _hiveManager = null;
    });
  }

  IPositionDataManager get _activeManager => AudioService.running
      ? _serviceManager
      : _hiveManager ??= HivePositionDataManager();

  @override
  Future<Duration> getPosition(String id) => _activeManager.getPosition(id);

  @override
  Future<List<Position>?> getPositions(List<String> ids) =>
      _activeManager.getPositions(ids);

  @override
  Future<void> setPosition(Position position) =>
      _activeManager.setPosition(position);
}

/// Saves position to disk.
class HivePositionDataManager extends IPositionDataManager {
  static final positionHive = HiveImpl();
  static const positionBoxName = "positions";
  static const int maxSavedPositions = 200;

  HivePositionDataManager();

  Future<Box<Position>> getPositionBox() async {
    final box = await positionHive.openBox<Position>(positionBoxName);

    assert(box.isOpen, 'How can it not be open??');

    return box;
  }

  /// Connect to disk storage.
  @override
  Future<Box<Position>> init() async {
    if (positionHive.isBoxOpen(positionBoxName)) {
      return await getPositionBox();
    } else {
      final hivePath = await getApplicationDocumentsDirectory();

      positionHive.init("${hivePath.path}/just_audio_service_hive");

      if (!positionHive.isAdapterRegistered(0)) {
        positionHive.registerAdapter(PositionAdapter());
      }
    }

    final box = await getPositionBox();
    await _constrainBoxSize(box);
    return box;
  }

  /// Close connection to disk storage.
  /// This is done to allow a diffirent isolate access.
  @override
  Future<void> close() async {
    try {
      await positionHive.close();
    } catch (err) {
      print(err);
    }
  }

  Future<Duration> getPosition(String id) async =>
      (await getPositions([id]))[0].position;

  Future<List<Position>> getPositions(List<String> ids) async {
    final positionBox = await init();
    // Take only last 255 charachters because of HiveDB limits
    return ids
        .map((id) =>
            positionBox.get(id.limitFromEnd(255)) ??
            Position(id: id, position: Duration.zero))
        .toList();
  }

  Future<void> setPosition(Position position) async {
    final positionBox = await init();

    if (position.position != Duration.zero) {
      await positionBox.put(position.id.limitFromEnd(255), position);
    } else {
      // No need to clutter the DB with zeros - that's the default, anyway.
      await positionBox.delete(position.id.limitFromEnd(255));
    }
  }

  /// Make sure we don't try to hold too many positions in memory.
  Future<void> _constrainBoxSize(Box<Position> positionBox) async {
    // E.g: There are 3 items, we're aloud max of 2, we need to delete 1.
    int amountPositionsToDelete = positionBox.length - maxSavedPositions;

    if (amountPositionsToDelete < 1) {
      return;
    }

    final positions = positionBox.values.toList();

    positions.sort((p1, p2) => p1.createdDate.compareTo(p2.createdDate));
    final positionsToDelete = positions.take(amountPositionsToDelete);

    await Stream.fromFutures(
        positionsToDelete.map((position) => position.delete())).last;
  }
}

/// Saves and retrieves position by interacting with the background audio task isolate.
class AudioServicePositionManager extends IPositionDataManager {
  static _getSendPort() =>
      IsolateNameServer.lookupPortByName(PositionedAudioTask.SendPortID);

  @override
  Future<Duration> getPosition(String id) async =>
      (await getPositions([id]))!.first.position;

  @override
  Future<List<Position>?> getPositions(List<String> ids) async {
    var sendPort;

    // Wait for the send port to be available.
    await Future.doWhile(() async {
      sendPort = _getSendPort();

      if (sendPort != null) {
        return false;
      }

      await Future.delayed(Duration(milliseconds: 100));
      // Try again...
      return true;
    }).timeout(Duration(seconds: 2), onTimeout: () async {
      // If I make this a lambda, it's an error. This is a bit clumsy - dart
      // should be able to do better.
      print("error: timeout for port");
      return false;
    });

    assert(sendPort != null);

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
