import 'package:flutter/foundation.dart';
import 'package:just_audio_service/background/audio-context.dart';
import 'package:just_audio_service/background/audio-state-base.dart';

class StoppedState extends MediaStateBase {
  StoppedState({@required AudioContext audioContext}) : super(context: audioContext);

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