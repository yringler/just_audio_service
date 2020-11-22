import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:path/path.dart' as p;
import 'package:just_audio_service/background/audio-context.dart';
import 'package:just_audio_service/background/audio-state-base.dart';
import 'package:just_audio_service/background/audio-states/playing-state.dart';

class ConnectingState extends MediaStateBase {
  Completer<void> _completer = Completer();

  // This handler handles state itself.
  ConnectingState({@required AudioContext context})
      : super(context: context, reactToStream: false);

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async =>
      // TODO: This should also update the client position (instead of just relying on
      // the position manager)
      super.setFutureSeekValue(position);

  @override
  Future<void> play() async {
    await _completer.future;

    context.stateHandler = PlayingState(context: context);
    await context.stateHandler.play();
  }

  @override
  Future<void> setUrl(String url) async {
    reactToStream = false;
    try {
      // If URL is called multiple times with same value, ignore.
      if (url == context.mediaItem?.id) {
        return;
      }

      // In case we connect to diffirent media items, without playing in the middle.
      if (_completer.isCompleted) {
        _completer = Completer();
      }

      // Set state to none in between media items, to give a clear indication of what state events
      // apply to which media.
      // (On startup, before anything happens, AudioService has a none state, and context.playBackState is null
      // because it gets its value when only when this plugin code sets it.)

      // Commenting out - this probably isn't neccesary...
      // if (context.playBackState != null && context.playBackState.basicState != BasicPlaybackState.none) {
      //   setMediaState(state: BasicPlaybackState.none);
      // }

      /*
     * Notify that connecting to media.
     */

      final publicId = context.urlToIdMap[url] ?? url;

      // Notify what is being played.
      context.mediaItem =
          MediaItem(id: publicId, album: "lessons", title: "lesson");
      // Notify the state (ie, connecting).
      super.setMediaState(
          state: AudioProcessingState.connecting,
          justAudioState: ProcessingState.loading);

      // Don't continue playing current audio when switched to new.
      await context.mediaPlayer.pause();

      if (url.startsWith(p.separator)) {
        url = Uri.file(url).toString();
      }

      final duration = await context.mediaPlayer.setUrl(url);

      // If we switched to something else while this file was loading,
      // forget about it.
      // (setUrl returns null if interrupted by another)
      if (duration == null) {
        return;
      }

      // Notify length of media.
      // TODO: Provide way to client to specify duration in media item if
      // it's already known.
      context.mediaItem = context.mediaItem.copyWith(duration: duration);

      // super.setMediaState(
      //     state: AudioProcessingState.ready,
      //     justAudioState: ProcessingState.ready);

      _completer.complete();
    } finally {
      reactToStream = true;
    }
  }
}
