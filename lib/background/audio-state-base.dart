import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_service/background/audio-context.dart';

/// Deals with state for a given state.
abstract class MediaStateBase {
  static const stateToStateMap = {
    AudioPlaybackState.connecting: AudioProcessingState.connecting,
    AudioPlaybackState.none: AudioProcessingState.none,
    AudioPlaybackState.paused: AudioProcessingState.ready,
    AudioPlaybackState.playing: AudioProcessingState.ready,
    AudioPlaybackState.completed: AudioProcessingState.completed,
    AudioPlaybackState.stopped: AudioProcessingState.stopped
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
  bool reactToStream = true;

  MediaStateBase({this.context});

  /// Called by [AudioContext] whenever [AudioPlayer] raises an event.
  /// Uses [reactToStream] to ignore events if a particular [MediaStateBase] doesn't
  /// want that event to be handled for whatever reason.
  void onPlaybackEvent(AudioPlaybackEvent event) {
    if (reactToStream) {
      context.playBackState = PlaybackState(
          processingState: stateToStateMap[event.state],
          actions: stateToActionsMap[event.state],
          position: event.position,
          updateTime: event.updateTime,
          playing: event.state == AudioPlaybackState.playing,
          bufferedPosition: event.bufferedPosition,
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

  void setMediaState({@required AudioProcessingState state, Duration position}) {
    position ??= context.upcomingPlaybackSettings?.position ??
        Duration.zero;

    context.playBackState = PlaybackState(
        processingState: state,
        actions: MediaStateBase.stateToActionsMap[state],
        position: position,
        updateTime: Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
        speed: context.generalPlaybackSettings?.speed ?? 1,
        playing: context.mediaPlayer.playbackState == AudioPlaybackState.playing,
        bufferedPosition: context.mediaPlayer.playbackEvent.bufferedPosition);
  }

  /// Set the [UpcomingPlaybackSettings.position] of [AudioContextBase.upcomingPlaybackSettings] to the given position.
  void setFutureSeekValue(Duration position) =>
      context.upcomingPlaybackSettings =
          UpcomingPlaybackSettings(position: position);
}
