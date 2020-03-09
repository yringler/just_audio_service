import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_service/background/audio-context.dart';
import 'package:just_audio_service/background/audio-state-base.dart';
import 'package:just_audio_service/playback-state-extensions.dart';

class PlayingState extends MediaStateBase {
  PlayingState({@required AudioContext context}) : super(context: context);

  @override
  Future<void> pause() {
    return context.mediaPlayer.pause();
  }

  @override
  Future<void> seek(Duration position) {
    super.reactToStream = false;

    final basicState =
        position.inMilliseconds > context.playBackState.currentPosition
            ? BasicPlaybackState.fastForwarding
            : BasicPlaybackState.rewinding;

    setMediaState(state: basicState, position: position);

    super.reactToStream = true;
  }

  @override
  Future<void> setSpeed(double speed) {
    // TODO: implement setSpeed
    return null;
  }

  @override
  Future<void> stop() {
    // TODO: implement stop
    return null;
  }

  @override
  Future<void> play() {
    // TODO: implement play
    return null;
  }

  @override
  Future<void> setUrl(String url) {
    // TODO: implement setUrl
    return null;
  }
}
