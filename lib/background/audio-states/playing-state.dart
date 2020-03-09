import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_service/background/audio-context.dart';
import 'package:just_audio_service/background/audio-state-base.dart';
import 'package:just_audio_service/background/audio-states/connecting-state.dart';
import 'package:just_audio_service/background/audio-states/stopped-state.dart';
import 'package:just_audio_service/playback-state-extensions.dart';

class PlayingState extends MediaStateBase {
  PlayingState({@required AudioContext context}) : super(context: context);

  @override
  Future<void> pause() {
    return context.mediaPlayer.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    if (position < Duration.zero) {
      position = Duration.zero;
    }

    if (position.inMilliseconds > context.mediaItem.duration) {
      return;
    }

    super.reactToStream = false;

    final basicState =
        position.inMilliseconds > context.playBackState.currentPosition
            ? BasicPlaybackState.fastForwarding
            : BasicPlaybackState.rewinding;

    // We're trying to get to that spot.
    setMediaState(state: basicState, position: position);

    context.mediaPlayer.seek(position);

    await context.mediaPlayer.playbackEventStream
        .firstWhere((event) => event.position == position);

    // We made it to wanted place in media.
    setMediaState(
        state:
            MediaStateBase.stateToStateMap[context.mediaPlayer.playbackState],
        position: position);

    super.reactToStream = true;
  }

  @override
  Future<void> setSpeed(double speed) async {
    context.generalPlaybackSettings =
        context.generalPlaybackSettings.copyWith(speed: speed);

    await context.mediaPlayer.setSpeed(speed);

    context.playBackState = context.playBackState.copyWith(speed: speed);
  }

  @override
  Future<void> stop() async {
    context.stateHandler = StoppedState(context: context);
    await context.stateHandler.stop();
  }

  @override
  Future<void> play() async {
    context.mediaPlayer.play();

    if (context.upcomingPlaybackSettings?.position != null) {
      await seek(context.upcomingPlaybackSettings.position);
    }
  }

  @override
  Future<void> setUrl(String url) async {
    context.stateHandler = ConnectingState(context: context);
    await context.stateHandler.setUrl(url);
  }
}
