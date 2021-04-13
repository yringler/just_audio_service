import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
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
    reactToStream = false;
    final currentPosition = context.playBackState.position;
    await context.mediaPlayer.stop();

    // TODO: pausing and swiping notification is treated like a stop, and sends a
    // state of position zero. To work around that, we always ignore the stop state
    // in the stream, and handle it manually here. Really, there should be a way
    // to diffirentiate.
    await setMediaState(
        // Set state to none.
        state: AudioProcessingState.none,
        justAudioState: ProcessingState.idle,
        position: currentPosition);
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
