import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:just_audio_service/download-manager/download-manager.dart';

class DownloadButton extends StatelessWidget {
  final ForgroundDownloadManager downloadManager;
  final String audioUrl;

  DownloadButton({@required this.downloadManager, @required this.audioUrl});

  @override
  Widget build(BuildContext context) => StreamBuilder<MinimalDownloadState>(
        stream: downloadManager.getProgressStreamFromUrl(audioUrl),
        builder: (context, snapshot) {
          final iconSize = Theme.of(context).iconTheme.size ?? 24;

          if (!snapshot.hasData) {
            return IconButton(
                iconSize: iconSize,
                icon: Icon(Icons.download_outlined),
                onPressed: null);
          }

          final status = snapshot.data.status;

          if (status == DownloadTaskStatus.undefined ||
              status == DownloadTaskStatus.failed) {
            return IconButton(
                iconSize: iconSize,
                icon: Icon(Icons.download_rounded),
                onPressed: () => downloadManager.download(audioUrl));
          }

          if ([DownloadTaskStatus.paused, DownloadTaskStatus.enqueued]
              .contains(status)) {
            return CircularProgressIndicator();
          }

          if (status == DownloadTaskStatus.running) {
            return Theme(
              data: Theme.of(context).copyWith(accentColor: Colors.green),
              child: CircularProgressIndicator(
                  value: snapshot.data.progress / 100.0),
            );
          }

          if (status == DownloadTaskStatus.complete) {
            return IconButton(
                iconSize: iconSize,
                icon: Icon(
                  Icons.download_done_rounded,
                  color: Colors.green,
                ),
                onPressed: () => downloadManager.delete(audioUrl));
          }

          throw Exception('unusable status: $status');
        },
      );
}
