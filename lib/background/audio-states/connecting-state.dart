import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_service/background/audio-context.dart';
import 'package:just_audio_service/background/audio-state-base.dart';
import 'package:just_audio_service/background/audio-states/playing-state.dart';
import 'package:just_audio_service/util/audioplayer-extensions.dart';

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

    assert(context.mediaItem != null,
        'It shouldn\'t be possible for media to be null.');

    if (!context.mediaPlayer.canPlay) {
      await context.mediaPlayer.playbackStateStream
          .firstWhere((state) => state.canPlay);
    }

    context.stateHandler = PlayingState(context: context);
    await context.stateHandler.play();
  }

  @override
  Future<void> setUrl(String url) async {
    // If URL is called multiple times with same value, ignore.
    if (url == context.mediaItem?.id) {
      return;
    }

    super.reactToStream = false;

    // Set state to none in between media items, to give a clear indication of what state events
    // apply to which media.
    // (On startup, before anything happens, AudioService has a none state, and context.playBackState is null
    // because it gets its value when only when this plugin code sets it.)
    if (context.playBackState != null && context.playBackState.basicState != BasicPlaybackState.none) {
      setMediaState(state: BasicPlaybackState.none);
    }

    // Notify that connecting to media.
    context.mediaItem = MediaItem(id: url, album: "lessons", title: "lesson");
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
        context.mediaItem.copyWith(duration: duration.inMilliseconds);
    super.setMediaState(state: BasicPlaybackState.stopped);

    super.reactToStream = true;
  }
}
