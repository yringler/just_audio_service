import 'package:audio_service/audio_service.dart';
import 'package:just_audio_service/position-manager/position.dart';
import 'package:just_audio_service/position-manager/positioned-audio-task.dart';
import 'package:just_audio_service/position-manager/position-data-manager.dart';
import 'package:rxdart/rxdart.dart';

/// Simplifies knowlage of current position (no more lag after a seek).
/// Interacts with a [BackgroundAudioTask] (such as [PositionedAudioTask]) to get last
/// held position of a media.
class PositionManager {
  // Ensure that seeks don't happen to frequently.
  final BehaviorSubject<Position> _seekingValues = BehaviorSubject.seeded(null);
  final BehaviorSubject<Position> _positionSubject =
      BehaviorSubject.seeded(Position(id: null, position: Duration.zero));

  final IPositionDataManager positionDataManager;

  PositionManager({this.positionDataManager}) {
    // Make sure that we always keep up to date on audio_service media position.
    Rx.combineLatest2<PlaybackState, dynamic, Position>(
            AudioService.playbackStateStream
                .where((state) => state?.basicState != BasicPlaybackState.none),
            Stream.periodic(Duration(milliseconds: 20)),
            (state, _) => _toDisplayPosition(state))
        .where((position) => position != null)
        .listen((position) => _positionSubject.value = position);

    // Seek, but not to often.
    _seekingValues
        .sampleTime(Duration(milliseconds: 50))
        .where((position) => position != null)
        .listen(_realSeek);

    _seekingValues
        .where((position) => position != null)
        .listen((event) => _positionSubject.value = event);
  }

  /// Stream of media position, not only of current media.
  Stream<Duration> get positionStream => _positionSubject.stream
      .where((event) => event.id == AudioService.currentMediaItem?.id)
      .map((event) => event.position);

  /// Updates the current location in given media, for the given ID. If ID is ommited,
  /// will effect current media.
  void seek(Duration location, {String id}) {
    _seekingValues.add(
        Position(id: AudioService.currentMediaItem.id, position: location));
  }

  /// Skips the requested time span for the given id. If ID is ommited, will
  /// effect current media.
  Future<void> skip(Duration duration, {String id}) async {
    Duration currentLocation;

    if (id == null || id == AudioService.currentMediaItem?.id) {
      currentLocation = _positionSubject.value?.position;
    } else if (positionDataManager != null) {
      currentLocation = await positionDataManager.getPosition(id);
    }

    seek(currentLocation + duration, id: id);
  }

  void dispose() {
    _seekingValues.close();
    _positionSubject.close();
  }

  /// Returns the audio service position, only if we aren't seeking right now.
  Position _toDisplayPosition(PlaybackState state) {
    if (state == null) {
      return null;
    }

    // Return null if we're currently seeking, and we have a diffirent position
    // to show based on that.
    if ((state.basicState == BasicPlaybackState.fastForwarding ||
            state.basicState == BasicPlaybackState.rewinding) &&
        _seekingValues.value != null &&
        _seekingValues.value.id == AudioService.currentMediaItem.id) {
      return null;
    }

    int position;

    if (state.basicState == BasicPlaybackState.stopped) {
      position = 0;
    } else {
      position = state.currentPosition;
    }

    return Position(
        id: AudioService.currentMediaItem?.id,
        position: Duration(milliseconds: position));
  }

  /// Actually change the position of the media (or save what to start at in a diffirent, not
  /// playing yet media).
  void _realSeek(Position event) {
    if (event.id == null || event.id == AudioService.currentMediaItem?.id) {
      AudioService.seekTo((event.position.inMilliseconds));
    } else if (positionDataManager != null) {
      positionDataManager.setPosition(event);
    }
  }
}
