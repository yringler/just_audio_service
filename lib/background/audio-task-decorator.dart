import 'package:audio_service/audio_service.dart';
import 'package:just_audio_service/background/audio-context.dart';
import 'package:just_audio_service/background/icontext-audio-task.dart';

/// Supports mixing and matching audio tasks
class AudioTaskDecorater extends BackgroundAudioTask
    implements IContextAudioTask {
  final IContextAudioTask baseTask;

  @override
  AudioContext get context => baseTask.context;

  AudioTaskDecorater({this.baseTask});

  @override
  Future<void> onStart(Map<String, dynamic> params) => baseTask.onStart(params);

  @override
  // (base task is responsible to call super.onStop())
  // ignore: must_call_super
  Future<void> onStop() => baseTask.onStop();

  @override
  Future<void> onPause() => baseTask.onPause();

  @override
  Future<void> onPlay() => baseTask.onPlay();

  @override
  Future<void> onPlayFromMediaId(String mediaId) =>
      baseTask.onPlayFromMediaId(mediaId);

  @override
  Future<void> onFastForward() => baseTask.onFastForward();

  @override
  Future<void> onRewind() => baseTask.onRewind();

  @override
  Future<void> onSeekTo(Duration position) => baseTask.onSeekTo(position);
  @override
  Future<dynamic> onCustomAction(String name, dynamic arguments) =>
      baseTask.onCustomAction(name, arguments);

  @override
  Future<void> onSetSpeed(double speed) => baseTask.onSetSpeed(speed);

  @override
  Future<void> onTaskRemoved() => baseTask.onTaskRemoved();

  @override
  Future<void> onClose() => baseTask.onClose();
}
