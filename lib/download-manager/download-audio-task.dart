import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:just_audio_service/background/audio-task-decorator.dart';
import 'package:just_audio_service/background/icontext-audio-task.dart';
import 'package:just_audio_service/background/audio-task.dart';
import 'package:just_audio_service/download-manager/download-manager.dart';

/// Audio task which will play offline audio if available, and switch to it if it
/// is ready while streaming.
/// Note that to work, the map of flutter_downloader ids to urls must be passed in
/// on start.
class DownloadAudioTask extends AudioTaskDecorater {
  Set<String> completedDownloads = {};
  Map<String, String> idToUrlMap = {};
  ReceivePort _port = ReceivePort();
  ReceivePort _newAdded = ReceivePort();

  DownloadAudioTask({@required IContextAudioTask audioTask})
      : super(baseTask: audioTask);

  DownloadAudioTask.standard() : this(audioTask: AudioTask());

  // Must be passed a set of all completed downloads on start.
  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    if (!params.containsKey('completed') ||
        !params['completed'] is Map<String, String> ||
        !params.containsKey('alltasks') ||
        !params['alltasks'] is Map<String, String>) {
      throw ArgumentError('Note passed in completed files');
    }

    completedDownloads = params['completed'] as Set<String>;
    idToUrlMap = params['alltasks'] as Map<String, String>;

    IsolateNameServer.removePortNameMapping(completedDownloadPortName);
    IsolateNameServer.registerPortWithName(
        _port.sendPort, completedDownloadPortName);

    _port.listen((message) {});

    IsolateNameServer.removePortNameMapping(updateTaskIdUrlPortName);
    IsolateNameServer.registerPortWithName(
        _newAdded.sendPort, updateTaskIdUrlPortName);

    _newAdded.listen((message) {});
    super.onStart(params);
  }
}
