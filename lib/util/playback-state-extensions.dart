import 'package:audio_service/audio_service.dart';

extension PlaybackStateExtensions on PlaybackState {
  PlaybackState copyWith(
      {BasicPlaybackState basicState,
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
        basicState: basicState ?? this.basicState,
        position: position ?? this.position,
        speed: speed ?? this.speed,
        updateTime: stateUpdateTime);
  }
}
