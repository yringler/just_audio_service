import 'package:audio_service/audio_service.dart';

extension PlaybackStateExtensions on PlaybackState {
  PlaybackState copyWith(
      {AudioProcessingState processingState,
      Set<MediaAction> actions,
      int position,
      double speed,
      int updateTime}) {
    final stateUpdateTime = updateTime ??
        (position == null
            ? this.updateTime
            : DateTime.now().millisecondsSinceEpoch);

    return PlaybackState(
      actions: actions ?? this.actions,
      processingState: processingState ?? this.processingState,
      position: position ?? this.position,
      speed: speed ?? this.speed,
      updateTime: stateUpdateTime,
      playing: this.playing,
      bufferedPosition: this.bufferedPosition,
      repeatMode: this.repeatMode,
      shuffleMode: this.shuffleMode,
    );
  }
}
