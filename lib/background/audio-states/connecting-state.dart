import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_service/background/audio-context.dart';
import 'package:just_audio_service/background/audio-state-base.dart';
import 'package:just_audio_service/background/audio-states/playing-state.dart';

class ConnectingState extends MediaStateBase {
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
    // Transition to play state and play if media was already loaded.
    // Otherwise, schedule a play to happen when loading finishes.

    // Make sure that the media we want to play has been loaded.

    // Creation of a connecting-state is always followed by a call to setUrl, which
    // sets the context media item to null. If its not null, it must be that
    // the media was already loaded successfully.
    if (context.mediaItem == null) {
      await context.mediaStateStream.firstWhere(
          (state) => state.basicState == BasicPlaybackState.stopped);
    }

    assert(context.mediaItem != null,
        'It shouldn\'t be possible for media to be null.');

    if (context.mediaItem != null) {
      context.stateHandler = PlayingState(context: context);
      await context.stateHandler.play();
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
  }
}
