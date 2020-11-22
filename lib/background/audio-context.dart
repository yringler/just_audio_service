import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_service/background/audio-state-base.dart';
import 'package:just_audio_service/background/audio-states/none-state.dart';
import 'package:rxdart/rxdart.dart';

// TODO: The control buttons should be configurable.

const playControl = MediaControl(
  androidIcon: 'drawable/ic_action_play_arrow',
  label: 'Play',
  action: MediaAction.play,
);

const pauseControl = MediaControl(
  androidIcon: 'drawable/ic_action_pause',
  label: 'Pause',
  action: MediaAction.pause,
);

const stopControl = MediaControl(
  androidIcon: 'drawable/ic_action_stop',
  label: 'Stop',
  action: MediaAction.stop,
);

/// just_audio_plugin implements the state pattern.
/// There is one class, [AudioContext] which serves as the center point to the
/// changing states, and several state classes inherited from [MediaStateBase]
/// which define and handle audio events and commands appropriately in
/// accordance to the state which they are designed to handle.

/// Audio settings which effect all audio.
class GeneralPlaybackSettings {
  /// The current speed.
  final double speed;

  /// The current volume.
  final double volume;

  GeneralPlaybackSettings({this.speed, this.volume});

  GeneralPlaybackSettings copyWith({double speed, double volume}) =>
      GeneralPlaybackSettings(
          speed: speed ?? this.speed, volume: volume ?? this.volume);
}

/// Audio state information which isn't usable now, but will be used when
/// possible. After it is used, it should be set to null.
///
/// For example, when no audio is loaded we can't seek, but we can set that
/// when we can seek, go to a certain position.
class UpcomingPlaybackSettings {
  final Duration position;

  UpcomingPlaybackSettings({@required this.position});
}

extension UpcomingPlaybackSettingsExtensions on UpcomingPlaybackSettings {
  copyWith({Duration position}) =>
      UpcomingPlaybackSettings(position: position ?? this?.position);
}

/// Functionality which the [MediaStateBase] classes will use to mantain state.
abstract class AudioContextBase {
  final AudioPlayer mediaPlayer;

  MediaStateBase stateHandler;

  AudioContextBase({@required this.mediaPlayer}) {
    stateHandler = NoneState(context: this);

    mediaPlayer.playbackEventStream
        .listen((e) => stateHandler.onPlaybackEvent(e));
  }

  Stream<PlaybackState> get mediaStateStream;

  /// Get current media item.
  MediaItem get mediaItem;

  /// Set current media item.
  set mediaItem(MediaItem item);

  /// Get the current playback state.
  PlaybackState get playBackState;

  /// Usually, the URL is the ID. Sometimes (eg when the url which is being played
  /// is a file URL), it isn't. Here, map URLs to IDs.
  Map<String, String> urlToIdMap = {};

  /// Returns the correct ID for the URL, even if the URL is e.g. a file url.
  String getIdFromUrl(String url) => urlToIdMap[url] ?? url;

  /// Set the current playback state.
  Future<void> setPlaybackState(PlaybackState playbackState);

  GeneralPlaybackSettings get generalPlaybackSettings;
  set generalPlaybackSettings(GeneralPlaybackSettings generalPlaybackSettings);

  UpcomingPlaybackSettings get upcomingPlaybackSettings;
  set upcomingPlaybackSettings(
      UpcomingPlaybackSettings upcomingPlaybackSettings);
}

class AudioContext extends AudioContextBase {
  MediaItem _mediaItem;
  BehaviorSubject<PlaybackState> _mediaStateSubject = BehaviorSubject();

  AudioContext() : super(mediaPlayer: AudioPlayer());

  @override
  GeneralPlaybackSettings generalPlaybackSettings;

  @override
  MediaItem get mediaItem => _mediaItem;
  @override
  set mediaItem(MediaItem item) {
    AudioServiceBackground.setMediaItem(item);
    _mediaItem = item;
  }

  @override
  PlaybackState get playBackState => _mediaStateSubject.value;

  @override
  Future<void> setPlaybackState(PlaybackState state) async {
    await AudioServiceBackground.setState(
        controls: state.playing ? [pauseControl] : [playControl],
        systemActions: state.actions?.toList() ?? List(),
        playing: state.playing,
        bufferedPosition: state.bufferedPosition,
        processingState: state.processingState,
        position: state.position,
        speed: state.speed,
        updateTime: state.updateTime);

    _mediaStateSubject.value = state;
  }

  @override
  Stream<PlaybackState> get mediaStateStream =>
      _mediaStateSubject.asBroadcastStream();

  @override
  UpcomingPlaybackSettings upcomingPlaybackSettings;
}
