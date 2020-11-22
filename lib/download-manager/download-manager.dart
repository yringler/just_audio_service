import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart' as paths;
import 'package:rxdart/rxdart.dart';
import 'package:slugify/slugify.dart';
import 'package:path/path.dart' as p;
import 'package:dart_extensions/dart_extensions.dart';

/// Name of port which provides access to the full download progress.
const fullProgressPortName = 'downloader_send_port';

/// Name of port which just reports when a download is completed.
const completedDownloadPortName = 'completed_send_port';

/// Name of port used to notify background audio task that a new task/URL mapping
/// is available.
const updateTaskIdUrlPortName = 'update_task_url_port';

/// Convert URL into a valid file name for android and iOS
String sanatizeFileName({String url}) {
  // Android is around 150, iOS is closer to 200, but this should be unique, and
  // not cause errors.
  const maxSize = 120;

  try {
    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.last;
    final nameParts = fileName.split('.');
    final suffix = nameParts.removeLast();
    final sluggifiedName = Slugify(nameParts.join(), delimiter: '_') as String;

    return sluggifiedName.limitFromStart(maxSize) + '.$suffix';
  } catch (err) {
    print(err);
    return null;
  }
}

String getFullDownloadPathAsync({String url, String saveFolder}) {
  return p.join(saveFolder, sanatizeFileName(url: url));
}

Future<String> getFullDownloadPath({String url}) async =>
    getFullDownloadPathAsync(saveFolder: await getDownloadFolder(), url: url);

Future<String> getDownloadFolder() async => (Platform.isIOS
        ? await paths.getApplicationDocumentsDirectory()
        : await paths.getExternalStorageDirectory())
    .path;

/// Used by forground. Downloads the file, provides status updates.
class ForgroundDownloadManager {
  /// Map of urls to progress. Use URLs so that we can have a stream even before
  /// download begins (when we don't have a task ID yet).
  Map<String, BehaviorSubject<MinimalDownloadState>> _progressStreams = {};

  /// Map of ids to URls. We need this in the download listener, which is only passed
  /// the task id.
  Map<String, String> downloadIds = {};

  /// The greatest number of downloads which we allow untill we start deleting
  /// the oldest. Defaults to no limit.
  final int maxDownloads;

  /// Port to recieve all the progress updates from flutter_downloader.
  ReceivePort _port = ReceivePort();

  String _saveDir;

  List<String> get completedUrls => downloadIds.values.toList();

  ForgroundDownloadManager({this.maxDownloads});

  /// Listen for download updates, keep streams in sync with progress.
  Future<void> init() async {
    IsolateNameServer.removePortNameMapping(fullProgressPortName);
    IsolateNameServer.registerPortWithName(
        _port.sendPort, fullProgressPortName);

    WidgetsFlutterBinding.ensureInitialized();
    await FlutterDownloader.initialize(debug: true);
    FlutterDownloader.registerCallback(downloadCallback);

    _saveDir = await getDownloadFolder();

    final allTasks = await FlutterDownloader.loadTasks();
    final verifiedTasks = await verifyTasks(allTasks);
    final allowedTasks = await _deleteExtraTasks(verifiedTasks);

    downloadIds =
        Map.fromEntries(allowedTasks.map((e) => MapEntry(e.taskId, e.url)));

    _progressStreams = Map.fromEntries(allowedTasks.map((e) => MapEntry(
        e.url,
        BehaviorSubject.seeded(MinimalDownloadState(
          progress: e.progress,
          status: e.status,
          taskId: e.taskId,
        )))));

    _port.listen((data) {
      final String id = data[0];
      final DownloadTaskStatus status = data[1];
      final int progress = data[2];

      // When the download is started, a message may be passed before the start
      // method returns an ID, so the map won't have a value yet.
      // So we'll maybe miss one update.
      if (!downloadIds.containsKey(id)) {
        return;
      }

      _progressStreams[downloadIds[id]].value =
          MinimalDownloadState(progress: progress, status: status, taskId: id);
    });
  }

  void dispose() {
    IsolateNameServer.removePortNameMapping(fullProgressPortName);
  }

  /// Delete the file downloaded from the given URL.
  Future<void> delete(String url) async {
    final taskId = _progressStreams[url]?.value?.taskId;

    if (taskId == null) {
      return;
    }

    await FlutterDownloader.remove(taskId: taskId, shouldDeleteContent: true);
  }

  /// Initiate download of the given [url]. Returns stream of progress updates.
  Future<Stream<MinimalDownloadState>> download(String url) async {
    final currentStatus =
        _progressStreams[url]?.value?.status ?? DownloadTaskStatus.undefined;
    if (![
      DownloadTaskStatus.undefined,
      DownloadTaskStatus.canceled,
      DownloadTaskStatus.failed
    ].contains(currentStatus)) {
      return getProgressStreamFromUrl(url);
    }

    final newState = MinimalDownloadState(status: DownloadTaskStatus.enqueued);
    _progressStreams[url]?.value = newState;
    _progressStreams[url] ??= BehaviorSubject.seeded(newState);

    final downloadId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: _saveDir,
        fileName: sanatizeFileName(url: url),
        showNotification: true,
        openFileFromNotification: false);

    downloadIds[downloadId] = url;
    // Notify the background task of the new url/taskId pair.
    IsolateNameServer.lookupPortByName(updateTaskIdUrlPortName)
        ?.send(MapEntry(downloadId, url));

    return _progressStreams[url];
  }

  Stream<MinimalDownloadState> getProgressStreamFromUrl(String url) {
    if (!_progressStreams.containsKey(url)) {
      _progressStreams[url] = BehaviorSubject.seeded(
          MinimalDownloadState(status: DownloadTaskStatus.undefined));

      // Don't clutter memory with not downloaded streams.
      _progressStreams[url].onCancel = () {
        if (_progressStreams[url].value.status ==
            DownloadTaskStatus.undefined) {
          _progressStreams.remove(url);
        }
      };

      return _progressStreams[url];
    }

    return _progressStreams[url];
  }

  // Makes sure that any task with progress hasn't been deleted. If it has been,
  // remove the task.
  Future<List<DownloadTask>> verifyTasks(List<DownloadTask> allTasks) async {
    final fileExistsFutures = allTasks
        .where((element) => (element.progress ?? 0) > 0)
        .toList()
        .map((e) async {
      if (!await File(
              getFullDownloadPathAsync(url: e.url, saveFolder: _saveDir))
          .exists()) {
        await FlutterDownloader.remove(taskId: e.taskId);
        return e;
      }

      return null;
    });

    final tasksWhichDontExist = (await Future.wait(fileExistsFutures))
        .where((element) => element != null)
        .toList();

    return List.from(
        Set.from(allTasks).difference(Set.from(tasksWhichDontExist)));
  }

  Future<List<DownloadTask>> _deleteExtraTasks(List<DownloadTask> tasks) async {
    if (maxDownloads == null || tasks.length <= maxDownloads) {
      return tasks;
    }

    final amountToDelete = tasks.length - maxDownloads;
    // Delete the oldest items.
    final toDelete = tasks
        .sortBy((task) => task.timeCreated)
        .toList()
        .take(amountToDelete)
        .toList();

    await Future.wait(toDelete.map((e) async {
      // I would rely on flutter downloader remove with remove, but IDK if it works
      // on iOS between app versions.
      await FlutterDownloader.remove(taskId: e.taskId);
      await File(getFullDownloadPathAsync(saveFolder: _saveDir, url: e.url))
          .delete();
    }));

    return (tasks.subtract(toDelete) as Set<DownloadTask>).toList();
  }
}

void downloadCallback(String id, DownloadTaskStatus status, int progress) {
  IsolateNameServer.lookupPortByName(fullProgressPortName)
      ?.send([id, status, progress]);

  if (status == DownloadTaskStatus.complete) {
    IsolateNameServer.lookupPortByName(completedDownloadPortName)?.send(id);
  }
}

class MinimalDownloadState {
  final String taskId;
  final DownloadTaskStatus status;
  final int progress;

  MinimalDownloadState({this.taskId, this.status, this.progress});
}
