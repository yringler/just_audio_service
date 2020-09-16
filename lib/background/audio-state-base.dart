import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_service/background/audio-context.dart';

/// Deals with state for a given state.
abstract class MediaStateBase {
  static const stateToStateMap = {
    ProcessingState.loading: AudioProcessingState.connecting,
    ProcessingState.none: AudioProcessingState.none,
    ProcessingState.completed: AudioProcessingState.completed,
    ProcessingState.ready: AudioProcessingState.ready,
    ProcessingState.buffering: AudioProcessingState.buffering
  };

  static Set<MediaAction> getAction(ProcessingState state, bool playing) {
    switch (state) {
      case ProcessingState.loading:
      case ProcessingState.none:
      case ProcessingState.completed:
        return {MediaAction.playFromMediaId};
      default:
        return stateToActionsMap[state][playing];
    }
  }

  static const stateToActionsMap = {
    ProcessingState.ready: {
      true: {
        MediaAction.playPause,
        MediaAction.stop,
        MediaAction.playFromMediaId,
        MediaAction.fastForward,
        MediaAction.rewind,
        MediaAction.seekTo
      },
      false: {
        MediaAction.playPause,
        MediaAction.stop,
        MediaAction.playFromMediaId,
        MediaAction.fastForward,
        MediaAction.rewind,
        MediaAction.seekTo
      }
    },
  };

  final AudioContextBase context;

  /// Whether media player state streams should be ignored.
  bool reactToStream;

  MediaStateBase({this.context, bool reactToStream = true}) {
    this.reactToStream = reactToStream;
  }

  /// Called by [AudioContext] whenever [AudioPlayer] raises an event.
  /// Uses [reactToStream] to ignore events if a particular [MediaStateBase] doesn't
  /// want that event to be handled for whatever reason.
  void onPlaybackEvent(PlaybackEvent event) {
    if (reactToStream) {
      context.playBackState = PlaybackState(
          processingState: stateToStateMap[event.processingState],
          // TODO: playing should come from a stream.
          actions:
              getAction(event.processingState, context.mediaPlayer.playing),
          position: event.updatePosition,
          updateTime:
              Duration(milliseconds: event.updateTime.millisecondsSinceEpoch),
          playing: context.mediaPlayer.playing &&
              event.processingState == ProcessingState.ready,
          bufferedPosition: event.bufferedPosition,
          speed: context.mediaPlayer.speed);
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

  void setMediaState(
      {@required AudioProcessingState state,
      @required ProcessingState justAudioState,
      Duration position}) {
    // I put in this null check while trying to figure out why the wrong icon was showing up
    // in the notification. This ended up having nothing to do with it, but possibly is a good idea?
    // Probably not needed. (Late night...)
    if (context.stateHandler != this) {
      return;
    }

    position ??= context.upcomingPlaybackSettings?.position ?? Duration.zero;

    context.playBackState = PlaybackState(
        processingState: state,
        // TODO: playing should come from stream.
        actions: getAction(justAudioState, context.mediaPlayer.playing),
        position: position,
        updateTime:
            Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
        speed: context.generalPlaybackSettings?.speed ?? 1,
        // TODO: playing should come from stream.
        playing: justAudioState == ProcessingState.ready &&
            context.mediaPlayer.playing,
        bufferedPosition: context.mediaPlayer.playbackEvent.bufferedPosition);
  }

  /// Set the [UpcomingPlaybackSettings.position] of [AudioContextBase.upcomingPlaybackSettings] to the given position.
  void setFutureSeekValue(Duration position) =>
      context.upcomingPlaybackSettings =
          UpcomingPlaybackSettings(position: position);
}
