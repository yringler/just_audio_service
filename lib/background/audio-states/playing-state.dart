import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_service/background/audio-context.dart';
import 'package:just_audio_service/background/audio-state-base.dart';
import 'package:just_audio_service/background/audio-states/connecting-state.dart';
import 'package:just_audio_service/background/audio-states/seeking-state.dart';
import 'package:just_audio_service/background/audio-states/stopped-state.dart';

class PlayingState extends MediaStateBase {
  PlayingState({@required AudioContext context}) : super(context: context);

  @override
  Future<void> pause() async {
    if (context.mediaPlayer.playbackState == AudioPlaybackState.playing) {
      await context.mediaPlayer.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    context.stateHandler = SeekingState(context: context);
    await context.stateHandler.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    context.generalPlaybackSettings =
        context.generalPlaybackSettings.copyWith(speed: speed);

    if (context.playBackState.playing) {
      await context.mediaPlayer.setSpeed(speed);
    }

    // There shouldn't be a need to explicitly update the audio_service state here, as just_audio
    // should trigger an event when speed is changed.
  }

  @override
  Future<void> stop() async {
    context.stateHandler = StoppedState(context: context);
    await context.stateHandler.stop();
  }

  @override
  Future<void> play() async {
    await context.mediaPlayer.play();

    // Respond to seek request that was placed before playback started (when seeking wasn't neccessarily
    // possible yet).
    if (context.upcomingPlaybackSettings?.position != null) {
      await seek(context.upcomingPlaybackSettings.position);
      // Reset the upcoming position. We don't want to go back there every time
      // user plays, for example after a pause.
      super.setFutureSeekValue(null);
    }

    if (context.generalPlaybackSettings != null) {
      if (context.generalPlaybackSettings.speed != null) {
        await setSpeed(context.generalPlaybackSettings.speed);
      }

      // Check that we're at the right volume.
      final desiredVolume = context.generalPlaybackSettings.volume;
      if (desiredVolume != null &&
          desiredVolume != context.mediaPlayer.volume) {
        // Don't await the set volume future - doesn't effect any other state.
        context.mediaPlayer.setVolume(desiredVolume);
      }
    }
  }

  @override
  Future<void> setUrl(String url) async {
    context.stateHandler = ConnectingState(context: context);
    await context.stateHandler.setUrl(url);
  }
}
