import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_service/background/audio-context.dart';

/// Deals with state for a given state.
abstract class MediaStateBase {
  static const stateToStateMap = {
    AudioPlaybackState.connecting: BasicPlaybackState.connecting,
    AudioPlaybackState.none: BasicPlaybackState.none,
    AudioPlaybackState.paused: BasicPlaybackState.paused,
    AudioPlaybackState.playing: BasicPlaybackState.playing,
    AudioPlaybackState.completed: BasicPlaybackState.stopped,
    AudioPlaybackState.stopped: BasicPlaybackState.stopped
  };

  static const stateToActionsMap = {
    AudioPlaybackState.connecting: {MediaAction.playFromMediaId},
    AudioPlaybackState.none: {MediaAction.playFromMediaId},
    AudioPlaybackState.paused: {
      MediaAction.playPause,
      MediaAction.stop,
      MediaAction.playFromMediaId,
      MediaAction.fastForward,
      MediaAction.rewind,
      MediaAction.seekTo
    },
    AudioPlaybackState.playing: {
      MediaAction.playPause,
      MediaAction.stop,
      MediaAction.playFromMediaId,
      MediaAction.fastForward,
      MediaAction.rewind,
      MediaAction.seekTo
    },
    AudioPlaybackState.completed: {MediaAction.playFromMediaId},
    AudioPlaybackState.stopped: {MediaAction.playFromMediaId}
  };

  final AudioContextBase context;

  /// Whether media player state streams should be ignored.
  bool reactToStream;

  MediaStateBase({this.context});

  /// Called by [AudioContext] whenever [AudioPlayer] raises an event.
  /// Uses [reactToStream] to ignore events if a particular [MediaStateBase] doesn't
  /// want that event to be handled for whatever reason.
  void onPlaybackEvent(AudioPlaybackEvent event) {
    if (reactToStream) {
      context.playBackState = PlaybackState(
          basicState: stateToStateMap[event.state],
          actions: null,
          position: event.position.inMilliseconds,
          updateTime: event.updateTime.inMilliseconds,
          speed: event.speed);
    }
  }

  Future<void> setUrl(String url);
  Future<void> pause();
  Future<void> play();
  Future<void> seek(Duration position);
  Future<void> stop();

  Future<void> setVolume(double volume) =>
      context.mediaPlayer.setVolume(volume);

  /// Set playback speed. By default, updates the [AudioContext.generalPlaybackSettings] but not the
  /// speed, to allow changing speed while paused without returning to play.
  Future<void> setSpeed(double speed) async => context.generalPlaybackSettings =
      context.generalPlaybackSettings?.copyWith(speed: speed) ??
          GeneralPlaybackSettings(speed: speed);

  /// Set the audio service state to a null, default state.
  void setNullState() {
    context.mediaItem = null;
    context.playBackState =
        PlaybackState(basicState: BasicPlaybackState.none, actions: null);
  }

  /// Returns the current [MediaItem] from [AudioContextBase.context], or a default value if null.
  MediaItem get safeMediaItem =>
      context.mediaItem ?? MediaItem(id: "", album: "lessons", title: "lesson");

  void setMediaState({@required BasicPlaybackState state, Duration position}) {
    position ??= context.upcomingPlaybackSettings?.position?.inMilliseconds ??
        Duration.zero;

    context.playBackState = PlaybackState(
        basicState: state,
        actions: MediaStateBase.stateToActionsMap[state],
        position: position.inMilliseconds,
        updateTime: DateTime.now().millisecondsSinceEpoch,
        speed: context.generalPlaybackSettings.speed);
  }

  /// Set the [UpcomingPlaybackSettings.position] of [AudioContextBase.upcomingPlaybackSettings] to the given position.
  void setFutureSeekValue(Duration position) =>
      context.upcomingPlaybackSettings =
          UpcomingPlaybackSettings(position: position);
}
