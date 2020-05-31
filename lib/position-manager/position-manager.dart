import 'package:audio_service/audio_service.dart';
import 'package:just_audio_service/position-manager/position.dart';
import 'package:just_audio_service/position-manager/positioned-audio-task.dart';
import 'package:just_audio_service/position-manager/position-data-manager.dart';

import 'package:rxdart/rxdart.dart';

/// Simplifies knowlage of current position (no more lag after a seek).
/// Interacts with a [BackgroundAudioTask] (such as [PositionedAudioTask]) to get last
/// held position of a media.
class PositionManager {
  /// How often the position stream is updated from audio_service.
  /// Note that when seeking (eg, draggin a position slider), the "position" is updated constantly.
  static const positionUpdateTime = Duration(milliseconds: 50);

  // Ensure that seeks don't happen to frequently.
  final BehaviorSubject<Position> _seekingValues = BehaviorSubject.seeded(null);
  final BehaviorSubject<Position> _positionSubject =
      BehaviorSubject.seeded(Position(id: null, position: Duration.zero));

  final IPositionDataManager positionDataManager;

  /// When a seek is requested, ignore position updates from audio_service for a little bit,
  /// to give it time to react to the seek.
  DateTime _ignoreAudioServiceUntil;

  PositionManager({this.positionDataManager}) {
    // Make sure that we always keep up to date on audio_service media position.
    Rx.combineLatest2<PlaybackState, dynamic, PlaybackState>(
            AudioService.playbackStateStream.where((state) =>
                (state?.basicState ?? BasicPlaybackState.none) !=
                BasicPlaybackState.none),
            Stream.periodic(positionUpdateTime),
            (state, _) => state)
        .where((_) => isAudioServiceEventRelevant())
        .listen((state) => _positionSubject.value = Position(
            id: AudioService.currentMediaItem.id,
            position: Duration(milliseconds: state.currentPosition)));

    // Seek, but not to often.
    _seekingValues
        .sampleTime(positionUpdateTime)
        .where((position) => position != null)
        .listen(_realSeek);

    _seekingValues.where((position) => position != null).listen((event) {
      _positionSubject.value = event;
      _ignoreAudioServiceUntil = DateTime.now().add(positionUpdateTime * 2);
    });
  }

  // An event from audio_service is only relevant if we aren't in the middle of seeking.
  bool isAudioServiceEventRelevant() {
    if (_ignoreAudioServiceUntil == null) {
      return true;
    }

    if (_ignoreAudioServiceUntil.isBefore(DateTime.now())) {
      return false;
    }

    // After the time to ignore audio_service events has passed, set ignore time to null.
    // This whole is more verbose then just checking against current time, but avoids constantly checking
    // the current time. This may or may not be a case of premature optimization.

    _ignoreAudioServiceUntil = null;

    return true;
  }

  /// Stream of media position, not only of current media.
  Stream<Duration> get positionStream => _positionSubject.stream
      .where((event) => event.id == AudioService.currentMediaItem?.id)
      .map((event) => event.position);

  /// Updates the current location in given media, for the given ID. If ID is ommited,
  /// will effect current media.
  void seek(Duration location, {String id}) {
    _seekingValues.add(Position(
        id: id ?? AudioService.currentMediaItem.id, position: location));
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
