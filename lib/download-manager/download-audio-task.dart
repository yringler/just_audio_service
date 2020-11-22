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
  ReceivePort _completedPort = ReceivePort();
  ReceivePort _newAdded = ReceivePort();
  String _downloadPath;

  DownloadAudioTask({@required IContextAudioTask audioTask})
      : super(baseTask: audioTask);

  DownloadAudioTask.standard() : this(audioTask: AudioTask());

  String _getFilePath(String url) =>
      getFullDownloadPathAsync(saveFolder: _downloadPath, url: url);

  /// Called from UI to create the params needed to start task.
  static Map<String, dynamic> createStartParams(
          ForgroundDownloadManager manager) =>
      {'completed': manager.completedUrls, 'id_to_url': manager.downloadIds};

  // Must be passed a set of all completed downloads on start.
  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    try {
      completedDownloads =
          (params['completed'] as List<dynamic>).cast<String>().toSet();
      idToUrlMap =
          (params['id_to_url'] as Map<dynamic, dynamic>).cast<String, String>();
    } catch (e) {
      print(
          'Error: failed type cast: possible missing start params to download audio task');
      throw e;
    }

    _downloadPath = await getDownloadFolder();
    context.urlToIdMap.addEntries(idToUrlMap.values.map((url) => MapEntry(
        getFullDownloadPathAsync(saveFolder: _downloadPath, url: url), url)));

    IsolateNameServer.removePortNameMapping(completedDownloadPortName);
    IsolateNameServer.registerPortWithName(
        _completedPort.sendPort, completedDownloadPortName);

    _completedPort.listen((message) async {
      final String taskId = message;
      assert(idToUrlMap.containsKey(taskId));

      final webUrl = idToUrlMap[taskId];
      final fileUrl = _getFilePath(webUrl);
      completedDownloads.add(webUrl);
      context.urlToIdMap[fileUrl] = webUrl;

      if (context.mediaItem.id == webUrl) {
        final currentPosition = context.playBackState.currentPosition;
        context.stateHandler.setUrl(fileUrl).then((value) {
          context.stateHandler.seek(currentPosition);
          context.stateHandler.play();
        });
      }
    });

    IsolateNameServer.removePortNameMapping(updateTaskIdUrlPortName);
    IsolateNameServer.registerPortWithName(
        _newAdded.sendPort, updateTaskIdUrlPortName);

    _newAdded.listen((message) {
      final entry = message as MapEntry<String, String>;
      idToUrlMap.addEntries([entry]);
    });

    super.onStart(params);
  }

  @override
  Future<void> onPlayFromMediaId(String mediaId) async {
    final playURL =
        completedDownloads.contains(mediaId) ? _getFilePath(mediaId) : mediaId;

    super.onPlayFromMediaId(playURL);
  }
}
