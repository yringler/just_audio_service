import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart' as paths;
import 'package:rxdart/rxdart.dart';
import 'package:slugify/slugify.dart';

/// Name of port which provides access to the full download progress.
const fullProgressPortName = 'downloader_send_port';

/// Name of port which just reports when a download is completed.
const completedDownloadPortName = 'completed_send_port';

/// Convert URL into a valid file name for android and iOS
String sanatizeFileName({String url}) {
  // Android is around 150, iOS is closer to 200, but this should be unique, and
  // not cause errors.
  const maxSize = 100;

  try {
    final uri = Uri.parse(url);
    final sluggifiedName =
        Slugify(uri.pathSegments.last, delimiter: '_') as String;
    final nameParts = sluggifiedName.split('.');
    final suffix = '.' + nameParts.removeLast();
    final fileName = nameParts.join('.');

    return fileName.substring(0, maxSize - suffix.length) + suffix;
  } catch (err) {
    print(err);
    return null;
  }
}

/// Used by forground. Downloads the file, provides status updates.
class ForgroundDownloadManager {
  /// Map of urls to progress.
  Map<String, BehaviorSubject<int>> _progressStreams = {};

  /// Map of ids to URls. We need this in the download listener, which only is passed
  /// the task id.
  Map<String, String> _downloadIds = {};

  ReceivePort _port = ReceivePort();

  /// Listen for download updates, keep streams in sync with progress.
  Future<void> init() async {
    IsolateNameServer.removePortNameMapping(fullProgressPortName);
    IsolateNameServer.registerPortWithName(
        _port.sendPort, fullProgressPortName);

    WidgetsFlutterBinding.ensureInitialized();
    await FlutterDownloader.initialize(debug: true);
    FlutterDownloader.registerCallback(downloadCallback);

    final allTasks = await FlutterDownloader.loadTasks();

    _downloadIds =
        Map.fromEntries(allTasks.map((e) => MapEntry(e.taskId, e.url)));

    _progressStreams = Map.fromEntries(allTasks.map((e) =>
        MapEntry(e.url, BehaviorSubject.seeded(_getProgressFromTask(e)))));

    _port.listen((data) {
      final String id = data[0];
      final DownloadTaskStatus status = data[1];
      final int progress = data[2];

      // the call to enqueue the download calls the port before it returns an ID,
      // the map won't have a value yet. So we'll maybe miss one update.
      if (!_downloadIds.containsKey(id)) {
        return;
      }

      _progressStreams[_downloadIds[id]].value = _getProgressFromTask(
          DownloadTask(status: status, progress: progress));
    });
  }

  void dispose() {
    IsolateNameServer.removePortNameMapping(fullProgressPortName);
  }

  Future<Stream<int>> download(String url) async {
    if (_progressStreams.containsKey(url)) {
      return getProgressStreamFromUrl(url);
    }

    final saveDir = Platform.isIOS
        ? await paths.getLibraryDirectory()
        : await paths.getExternalStorageDirectory();

    _progressStreams[url] = BehaviorSubject.seeded(null);

    final downloadId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: saveDir.path,
        showNotification: true,
        openFileFromNotification: false);

    _downloadIds[downloadId] = url;

    return _progressStreams[url];
  }

  Stream<int> getProgressStreamFromUrl(String url) {
    if (!_progressStreams.containsKey(url)) {
      _progressStreams[url] = BehaviorSubject.seeded(null);
    }

    return _progressStreams[url];
  }

  static _getProgressFromTask(DownloadTask task) {
    if (task.status == DownloadTaskStatus.complete) {
      return 100;
    } else if (task.status == DownloadTaskStatus.running ||
        task.status == DownloadTaskStatus.paused ||
        task.status == DownloadTaskStatus.enqueued) {
      return task.progress ?? 0;
    } else {
      return null;
    }
  }
}

void downloadCallback(String id, DownloadTaskStatus status, int progress) {
  IsolateNameServer.lookupPortByName(fullProgressPortName)
      ?.send([id, status, progress]);

  IsolateNameServer.lookupPortByName(completedDownloadPortName)
      ?.send(status == DownloadTaskStatus.complete);
}
