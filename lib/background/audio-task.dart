import 'package:audio_service/audio_service.dart';
import 'package:just_audio_service/background/audio-context.dart';

class AudioTask extends BackgroundAudioTask {
  AudioContext context;

  @override
  Future<void> onStart() async {

  }

  @override
  void onStop() {
    // TODO: implement onStop
  }
  
}