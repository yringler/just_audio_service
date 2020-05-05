import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';

class PositionManager {
  // Ensure that seeks don't happen to frequently.
  final BehaviorSubject<Duration> _seekingValues = BehaviorSubject.seeded(null);
  final BehaviorSubject<Duration> _positionSubject = BehaviorSubject.seeded(Duration.zero);

  void init() {
    Rx.combineLatest3<PlaybackState, dynamic, Duration, Duration>(
            AudioService.playbackStateStream
                .where((state) => state?.basicState != BasicPlaybackState.none),
            Stream.periodic(Duration(milliseconds: 20)),
            _seekingValues,
            (state, _, displaySeek) => _toDisplayPosition(state, displaySeek))
        .listen((position) => _positionSubject.value = position);

    // Seek, but not to often.
    _seekingValues
        .sampleTime(Duration(milliseconds: 50))
        .where((position) => position != null)
        .listen((position) => AudioService.seekTo(
            position.inMilliseconds < 0 ? 0 : position.inMilliseconds));
  }

  /// Updates the current location in given media.
  void seek(Duration location) {
    _seekingValues.add(location);
  }

  void skip(Duration duration) {
    final currentLocation = _positionSubject.value;
    seek(currentLocation + duration);
  }

  void dispose() {
    _seekingValues.close();
    _positionSubject.close();
  }

  /// Returns the position which should be used for UI, which isn't neccessarily
  /// the current, real position of the media player.
  Duration _toDisplayPosition(PlaybackState state, Duration displaySeek) {
    if (state == null) {
      return Duration(milliseconds: AudioService.playbackState?.position ?? 0);
    }

    int position;

    if ((state.basicState == BasicPlaybackState.fastForwarding ||
            state.basicState == BasicPlaybackState.rewinding) &&
        displaySeek != null) {
      position = displaySeek.inMilliseconds;
    } else if (state.basicState == BasicPlaybackState.stopped) {
      position = 0;
    } else {
      position = state.currentPosition;
    }

    return Duration(milliseconds: position);
  }
}
