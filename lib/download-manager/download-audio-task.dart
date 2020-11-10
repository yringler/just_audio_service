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

  /// Called from UI to create the params needed to start task.
  static Map<String, dynamic> createStartParams(
          ForgroundDownloadManager manager) =>
      {
        'completed': manager.completedUrls.toSet(),
        'id_to_url': manager.downloadIds
      };

  // Must be passed a set of all completed downloads on start.
  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    if (!params.containsKey('completed') ||
        !params['completed'] is Set<String> ||
        !params.containsKey('id_to_url') ||
        !params['id_to_url'] is Map<String, String>) {
      throw ArgumentError('Note passed in completed files');
    }

    completedDownloads = params['completed'] as Set<String>;
    idToUrlMap = params['id_to_url'] as Map<String, String>;

    final downloadPath = await getDownloadFolder();
    context.urlToIdMap.addEntries(idToUrlMap.values.map((e) => MapEntry(
        e, getFullDownloadPathAsync(saveFolder: downloadPath, url: e))));

    IsolateNameServer.removePortNameMapping(completedDownloadPortName);
    IsolateNameServer.registerPortWithName(
        _port.sendPort, completedDownloadPortName);

    _port.listen((message) async {
      final String taskId = message;
      assert(idToUrlMap.containsKey(taskId));
      final url = idToUrlMap[taskId];
      completedDownloads.add(url);
      context.urlToIdMap[
          getFullDownloadPathAsync(saveFolder: downloadPath, url: url)] = url;

      if (context.mediaItem.id == url) {
        context.stateHandler
            .setUrl(Uri.file(await getFullDownloadPath(url: url)).toString());
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
}
