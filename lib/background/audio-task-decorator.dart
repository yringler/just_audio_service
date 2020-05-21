import 'package:audio_service/audio_service.dart';

/// Supports mixing and matching audio tasks
class AudioTaskDecorater extends BackgroundAudioTask 
{
  final BackgroundAudioTask baseTask;

  AudioTaskDecorater({this.baseTask});

  @override
  Future<void> onStart() => baseTask.onStart();

  @override
  void onStop() => baseTask.onStop();

  @override
  void onPause() => baseTask.onPause();

  @override
  void onPlay() => baseTask.onPlay();

  @override
  void onPlayFromMediaId(String mediaId) => baseTask.onPlayFromMediaId(mediaId);

  @override
  void onFastForward() => baseTask.onFastForward();

  @override
  void onRewind() => baseTask.onRewind();

  @override
  void onSeekTo(int position) => baseTask.onSeekTo(position);
  @override
  void onCustomAction(String name, dynamic arguments) => baseTask.onCustomAction(name, arguments);

  @override
  void onAudioFocusGained() {}
  @override
  void onAudioFocusLost() {}
  @override
  void onAudioFocusLostTransient() {}
  @override
  void onAudioFocusLostTransientCanDuck() {}
  @override
  void onAudioBecomingNoisy() {}
  @override
  void onClick(MediaButton button) {}
  @override
  void onPrepare() {}
  @override
  void onPrepareFromMediaId(String mediaId) {}
  @override
  void onAddQueueItem(MediaItem mediaItem) {}
  @override
  void onAddQueueItemAt(MediaItem mediaItem, int index) {}
  @override
  void onRemoveQueueItem(MediaItem mediaItem) {}
  @override
  void onSkipToNext() {}
  @override
  void onSkipToPrevious() {}
  @override
  void onSkipToQueueItem(String mediaId) {}
  @override
  void onSetRating(Rating rating, Map<dynamic, dynamic> extras) {}
}