import 'package:audio_service/audio_service.dart';

extension BasicPlaybackStateExtensions on BasicPlaybackState {
  bool get isSeeking => this == BasicPlaybackState.fastForwarding || this == BasicPlaybackState.rewinding;
}