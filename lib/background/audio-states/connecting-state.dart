import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_service/background/audio-context.dart';
import 'package:just_audio_service/background/audio-state-base.dart';
import 'package:just_audio_service/background/audio-states/playing-state.dart';

class ConnectingState extends MediaStateBase {
  bool isSettingUrl = false;
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
    if (isSettingUrl) {
      didRequestPlayWhileLoading = true;
    } else {
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

    isSettingUrl = true;
    final duration = await context.mediaPlayer.setUrl(url);

    // If we switched to something else while this file was loading,
    // forget about it.
    if (url != context.mediaItem.id) {
      return;
    }

    isSettingUrl = false;

    // Notify length of media.
    context.mediaItem =
        safeMediaItem.copyWith(duration: duration.inMilliseconds);
    super.setMediaState(state: BasicPlaybackState.stopped);

    // It can take some time before audio_player is aware state.
    await context.mediaPlayer.playbackStateStream
        .firstWhere((state) => state == AudioPlaybackState.stopped);

    super.reactToStream = true;

    // Play media if play was requested while loading.
    if (didRequestPlayWhileLoading) {
      play();
    }
  }
}
