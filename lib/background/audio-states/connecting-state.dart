import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_service/background/audio-context.dart';
import 'package:just_audio_service/background/audio-state-base.dart';
import 'package:just_audio_service/background/audio-states/playing-state.dart';

class ConnectingState extends MediaStateBase {
  /// True if user called play while a connection was being made.
  /// If that is done, playback will start as soon as connection to audio
  /// has been established.
  bool didRequestPlayWhileLoading;

  ConnectingState({@required AudioContext context}) : super(context: context);

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async =>
      super.setFutureSeekValue(position);

  @override
  Future<void> stop() async {}

  @override
  Future<void> play() async {
    // Creation of a connecting-state is always followed by a call to setUrl
    // (the connection); that's the only reason to create this.
    // setUrl sets the context media item to null; if its not null, it must be that
    // we loaded the media successfully, and a call to play should transition to the play
    // state.
    if (context.mediaItem != null){
      context.stateHandler = PlayingState(context: context);
      await context.stateHandler.play();
    } else {
      didRequestPlayWhileLoading = true;
    }
  }

  @override
  Future<void> setUrl(String url) async {
      // If URL is called multiple times with same value, ignore.
      if (url == context.mediaItem.id) {
        return;
      }

    super.reactToStream = false;

    super.setNullState();

    // Notify that connecting to media.
    context.mediaItem = safeMediaItem.copyWith(id: url);
    super.setMediaState(state: BasicPlaybackState.connecting);

    final duration = await context.mediaPlayer.setUrl(url);

    // If we switched to something else while this file was loading,
    // forget about it.
    // (setUrl returns null if interrupted by another)
    if (duration == null) {
      return;
    }

    // Notify length of media.
    context.mediaItem =
        safeMediaItem.copyWith(duration: duration.inMilliseconds);
    super.setMediaState(state: BasicPlaybackState.stopped);

    super.reactToStream = true;

    // Play media if play was requested while loading.
    if (didRequestPlayWhileLoading) {
      await play();
    }
  }
}
