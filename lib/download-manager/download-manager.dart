import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart' as paths;
import 'package:rxdart/rxdart.dart';
import 'package:slugify/slugify.dart';
import 'package:path/path.dart' as p;

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
  /// Map of urls to progress. Use URLs so that we can have a stream even before
  /// download begins.
  Map<String, BehaviorSubject<MinimalDownloadState>> _progressStreams = {};

  /// Map of ids to URls. We need this in the download listener, which only is passed
  /// the task id.
  Map<String, String> _downloadIds = {};

  ReceivePort _port = ReceivePort();

  String _saveDir;

  /// Listen for download updates, keep streams in sync with progress.
  Future<void> init() async {
    IsolateNameServer.removePortNameMapping(fullProgressPortName);
    IsolateNameServer.registerPortWithName(
        _port.sendPort, fullProgressPortName);

    WidgetsFlutterBinding.ensureInitialized();
    await FlutterDownloader.initialize(debug: true);
    FlutterDownloader.registerCallback(downloadCallback);

    _saveDir = (Platform.isIOS
            ? await paths.getLibraryDirectory()
            : await paths.getExternalStorageDirectory())
        .path;

    final allTasks = await FlutterDownloader.loadTasks();
    final verifiedTasks = await verifyTasks(allTasks);

    _downloadIds =
        Map.fromEntries(verifiedTasks.map((e) => MapEntry(e.taskId, e.url)));

    _progressStreams = Map.fromEntries(verifiedTasks.map((e) =>
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

      _progressStreams[_downloadIds[id]].value =
          MinimalDownloadState(progress: progress, status: status, taskId: id);
    });
  }

  void dispose() {
    IsolateNameServer.removePortNameMapping(fullProgressPortName);
  }

  String getFullDownloadPathFromUrl({String url}) {
    return p.join(_saveDir, sanatizeFileName(url: url));
  }

  Future<Stream<MinimalDownloadState>> download(String url) async {
    if (_progressStreams.containsKey(url)) {
      return getProgressStreamFromUrl(url);
    }

    _progressStreams[url] = BehaviorSubject.seeded(
        MinimalDownloadState(status: DownloadTaskStatus.enqueued));

    final downloadId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: _saveDir,
        fileName: sanatizeFileName(url: url),
        showNotification: true,
        openFileFromNotification: false);

    _downloadIds[downloadId] = url;

    return _progressStreams[url];
  }

  Stream<MinimalDownloadState> getProgressStreamFromUrl(String url) {
    if (!_progressStreams.containsKey(url)) {
      return _progressStreams[url] = BehaviorSubject.seeded(null);
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

  // Makes sure that any task with progress hasn't been deleted. If it has been,
  // remove the task.
  Future<List<DownloadTask>> verifyTasks(List<DownloadTask> allTasks) async {
    final fileExistsFutures = allTasks
        .where((element) => element.progress ?? 0 > 0)
        .toList()
        .map((e) async {
      if (!await File(p.join(e.savedDir, e.filename)).exists()) {
        await FlutterDownloader.remove(taskId: e.taskId);
        return e;
      }

      return null;
    });

    final tasksWhichDontExist = await Future.wait(fileExistsFutures);

    return List.from(
        Set.from(allTasks).difference(Set.from(tasksWhichDontExist)));
  }
}

void downloadCallback(String id, DownloadTaskStatus status, int progress) {
  IsolateNameServer.lookupPortByName(fullProgressPortName)
      ?.send([id, status, progress]);

  IsolateNameServer.lookupPortByName(completedDownloadPortName)
      ?.send(status == DownloadTaskStatus.complete);
}

class MinimalDownloadState {
  final String taskId;
  final DownloadTaskStatus status;
  final int progress;

  MinimalDownloadState({this.taskId, this.status, this.progress});
}
