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
    // If we're in the middle of loading a file, try to wait untill that's done.
    if (isSettingUrl) {
      await context.mediaPlayer.playbackStateStream
          .firstWhere(
              (event) => event == AudioPlaybackState.stopped && !isSettingUrl)
          .timeout(Duration(seconds: 5),
              onTimeout: () => AudioPlaybackState.stopped);
    }

    super.reactToStream = false;

    super.setNullState();

    // Notify that connecting to media.
    context.mediaItem = safeMediaItem.copyWith(id: url);
    super.setMediaState(state: BasicPlaybackState.connecting);

    isSettingUrl = true;
    final duration = await context.mediaPlayer.setUrl(url);
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
