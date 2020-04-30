import 'package:just_audio/just_audio.dart';

extension AudioPlayerExtensions on AudioPlayer {
  bool get canPlay => this.playbackState.canPlay;
}

extension AudioPlaybackStateExtensions on AudioPlaybackState {
    bool get canPlay => this != AudioPlaybackState.none && this != AudioPlaybackState.connecting;
}