import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_service/background/audio-context.dart';
import 'package:just_audio_service/background/audio-state-base.dart';
import 'package:just_audio_service/background/audio-states/connecting-state.dart';
import 'package:just_audio_service/background/audio-states/playing-state.dart';

class SeekingState extends MediaStateBase {
  /// In case a seek is requested in the middle of another, this state isn't
  /// finished untill that seek is done.
  int numSeeking = 0;

  /// Keep track of if we give up on seeking in the middle. For example, connect to other media.
  bool get didAbandonSeek => !didPersistSeek;

  /// Keep track of if we give up on seeking in the middle. For example, connect to other media.
  bool get didPersistSeek => this == context.stateHandler;

  final Completer<void> _doneSeeking = Completer();

  SeekingState({@required AudioContextBase context}) : super(context: context);

  @override
  Future<void> pause() async {
    await _doneSeeking.future;
    if (didPersistSeek) await context.stateHandler.pause();
  }

  @override
  Future<void> play() async {
    await _doneSeeking.future;
    if (didPersistSeek) await context.stateHandler.play();
  }

  @override
  Future<void> seek(Duration position) async {
    if (position > context.mediaItem.duration) {
      return;
    }

    super.reactToStream = false;

    if (position < Duration.zero) {
      position = Duration.zero;
    }

    ++numSeeking;

    final basicState = position > context.playBackState.currentPosition
        ? AudioProcessingState.fastForwarding
        : AudioProcessingState.rewinding;

    // We're trying to get to that spot.
    await setMediaState(
        state: basicState,
        justAudioState: context.mediaPlayer.playerState.processingState,
        position: position);

    // Don't await. I'm not sure if it will complete before or after it's finished seeking,
    // so I'll check myself for when it reaches the correct position later.
    // TODO: This section could use some work.
    await context.mediaPlayer.seek(position);

    // TODO :remove commented out code, update previous comment.
    // final reachedPositionState = await context.mediaPlayer.playbackEventStream
    //     .firstWhere(
    //       (event) => event.updatePosition == position,
    //       orElse: () => null,
    //     )
    //     .timeout(Duration(milliseconds: 250), onTimeout: () => null);

    if (didAbandonSeek) return;

    // if ((reachedPositionState?.processingState == ProcessingState.buffering) ??
    //     false) {
    //   await context.mediaPlayer.playbackEventStream
    //       .firstWhere(
    //           (event) => event.processingState != ProcessingState.buffering)
    //       .timeout(Duration(milliseconds: 250), onTimeout: () => null);
    // }

    --numSeeking;

    if (numSeeking > 0 || didAbandonSeek) {
      return;
    }

    // We made it to wanted place in media.
    await setMediaState(
        state: MediaStateBase
            .stateToStateMap[context.mediaPlayer.playerState.processingState],
        justAudioState: context.mediaPlayer.processingState,
        position: position);

    // Set the state handler before calling complete() on doneSeeking.
    // This ensures that any calls to play() or pause() go to the playing state, not
    // an unending recursive call.
    context.stateHandler = PlayingState(context: context);

    // Only notify pause method that seeking was completed after everything was done.
    // This simplifies state considerations.
    // It also in theory might create a moment of unwanted playback, so we'll see if this
    // has to change.
    _doneSeeking.complete();

    super.reactToStream = true;
  }

  @override
  Future<void> setUrl(String url) async {
    if (url == context.mediaItem.id) {
      return;
    }

    context.stateHandler = ConnectingState(context: context);
    await context.stateHandler.setUrl(url);
  }
}
