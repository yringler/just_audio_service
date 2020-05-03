import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_service/background/audio-context.dart';
import 'package:just_audio_service/background/audio-state-base.dart';
import 'package:just_audio_service/background/audio-states/connecting-state.dart';
import 'package:just_audio_service/background/audio-states/stopped-state.dart';

class PlayingState extends MediaStateBase {
  Completer<void> _doneSeeking = Completer();

  PlayingState({@required AudioContext context}) : super(context: context);

  @override
  Future<void> pause() async {
    if (!_doneSeeking.isCompleted) {
      await _doneSeeking.future;
    }

    if (context.mediaPlayer.playbackState == AudioPlaybackState.playing) {
      await context.mediaPlayer.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (position.inMilliseconds > context.mediaItem.duration) {
      return;
    }

    super.reactToStream = false;

    if (position < Duration.zero) {
      position = Duration.zero;
    }

    if (_doneSeeking.isCompleted) {
      _doneSeeking = Completer();
    }

    final basicState =
        position.inMilliseconds > context.playBackState.currentPosition
            ? BasicPlaybackState.fastForwarding
            : BasicPlaybackState.rewinding;

    // We're trying to get to that spot.
    setMediaState(state: basicState, position: position);

    // Don't await. I'm not sure if it will complete before or after it's finished seeking,
    // so I'll check myself for when it reaches the correct position later.
    context.mediaPlayer.seek(position);

    final reachedPositionState = await context.mediaPlayer.playbackEventStream
        .firstWhere((event) => event.position == position);

    if (reachedPositionState.buffering) {
      await context.mediaPlayer.playbackEventStream
          .firstWhere((event) => !event.buffering)
          .timeout(Duration(milliseconds: 250), onTimeout: () => null);
    }

    // We made it to wanted place in media.
    setMediaState(
        state:
            MediaStateBase.stateToStateMap[context.mediaPlayer.playbackState],
        position: position);

    // Only notify pause method that seeking was completed after everything was done.
    // This simplifies state considerations.
    // It also in theory might create a moment of unwanted playback, so we'll see if this
    // has to change.
    _doneSeeking.complete();

    super.reactToStream = true;
  }

  @override
  Future<void> setSpeed(double speed) async {
    context.generalPlaybackSettings =
        context.generalPlaybackSettings.copyWith(speed: speed);

    if (context.playBackState.basicState == BasicPlaybackState.playing) {
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

      // CHeck that we're at the right volume.
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
