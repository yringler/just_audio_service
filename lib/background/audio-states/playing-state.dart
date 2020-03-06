import 'package:flutter/foundation.dart';
import 'package:just_audio_service/background/audio-context.dart';
import 'package:just_audio_service/background/audio-state-base.dart';

class PlayingState extends MediaStateBase {
  PlayingState({@required AudioContext context}) : super(context: context);

  @override
  Future<void> pause() {
    // TODO: implement pause
    return null;
  }

  @override
  Future<void> seek(Duration position) {
    // TODO: implement seek
    return null;
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