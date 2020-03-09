import 'package:flutter/foundation.dart';
import 'package:just_audio_service/background/audio-context.dart';
import 'package:just_audio_service/background/audio-state-base.dart';
import 'package:just_audio_service/background/audio-states/connecting-state.dart';
import 'package:just_audio_service/background/audio-states/playing-state.dart';

class StoppedState extends MediaStateBase {
  StoppedState({@required AudioContext context}) : super(context: context);

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async =>
      super.setFutureSeekValue(position);

  @override
  Future<void> stop() async {
    await context.mediaPlayer.stop();
  }

  @override
  Future<void> play() async {
    if (context.mediaItem != null) {
      context.stateHandler = PlayingState(context: context);
      await context.stateHandler.play();
    }
  }

  @override
  Future<void> setUrl(String url) async {
    context.stateHandler = ConnectingState(context: context);
    await context.stateHandler.setUrl(url);
  }
}
