import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_service/background/audio-context.dart';
import 'package:just_audio_service/background/icontext-audio-task.dart';

class AudioTask extends BackgroundAudioTask implements IContextAudioTask {
  final AudioContext context = AudioContext();

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    // This will be changed when we support playlists.
    // Then, on media completion we'll check if there's another file to play.
    context.mediaPlayer.playerStateStream
        .where((state) => state.processingState == ProcessingState.completed)
        .listen((_) => _dispose());

    final session = await AudioSession.instance;
    session.configure(AudioSessionConfiguration.speech());
  }

  @override
  // (calls super in dispose)
  // ignore: must_call_super
  Future<void> onStop() async { 
    await context.stateHandler.stop();
    await _dispose();
  }

  @override
  Future<void> onPause() => context.stateHandler.pause();

  @override
  Future<void> onPlay() => context.stateHandler.play();

  @override
  Future<void> onPlayFromMediaId(String mediaId) async {
    final future = context.stateHandler.setUrl(mediaId);
    context.stateHandler.play();
    await future;
  }

  @override
  Future<void> onFastForward() =>
      onSeekTo((context.playBackState?.currentPosition ?? Duration.zero) +
          Duration(seconds: 15));

  @override
  Future<void> onRewind() =>
      onSeekTo((context.playBackState?.currentPosition ?? Duration.zero) -
          Duration(seconds: 15));

  @override
  Future<void> onSeekTo(Duration position) =>
      context.stateHandler.seek(position);

  @override
  Future<dynamic> onCustomAction(String name, dynamic arguments) async {}

  Future<void> _dispose() async {
    await context.mediaPlayer.dispose();
    await super.onStop();
  }

  @override
  Future<void> onSetSpeed(double speed) => context.stateHandler.setSpeed(speed);
}
