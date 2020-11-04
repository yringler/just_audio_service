import 'package:just_audio_service/background/audio-task-decorator.dart';

class DownloadAudioTask extends AudioTaskDecorater {
  // Must be passed a set of all completed downloads on start.
  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    
  }
}
