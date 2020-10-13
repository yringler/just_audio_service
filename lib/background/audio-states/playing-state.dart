import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio_service/background/audio-context.dart';
import 'package:just_audio_service/background/audio-state-base.dart';
import 'package:just_audio_service/background/audio-states/connecting-state.dart';
import 'package:just_audio_service/background/audio-states/seeking-state.dart';

class PlayingState extends MediaStateBase {
  PlayingState({@required AudioContext context}) : super(context: context);

  @override
  Future<void> pause() => context.mediaPlayer.pause();

  @override
  Future<void> seek(Duration position) async {
    context.stateHandler = SeekingState(context: context);
    await context.stateHandler.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    await super.setSpeed(speed);

    if (context.playBackState.playing) {
      await context.mediaPlayer.setSpeed(speed);
    }
  }

  @override
  Future<void> play() async {
    context.mediaPlayer.play();

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
    // No need to connect if we already did.
    // TODO: this check is in every change to ConnectingState. This should be less manual.
    if (url == context.mediaItem.id) {
      return;
    }

    context.stateHandler = ConnectingState(context: context);
    await context.stateHandler.setUrl(url);
  }
}
