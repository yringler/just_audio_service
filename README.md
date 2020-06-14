# just_audio_service

In beta. There is a working example.<br>
<br>
Intended to be a robust, well written, easy to use implementation of audio_service using just_audio.<br>
Note that initial goal is only to support a limited set of requirements (i.e. mine), not to be properly configurable.
For example, it doesn't support 
1. playlists
2. customizing the buttons on the android notification.
3. playing audio from any source other than URL
4. setting audio metadata - album, artist, etc
5. losing focus, that on noise callback - doesn't take advantage of a bunch of `BackgroundAudioTask` functionality

That being said, I hope that it is a good starting point for others to base their implementations off, and PRs (or feature requests, or forks) are most welcome.

# Installation
This is not yet available on pub.dev, but can be used from git
```yaml
  just_audio_service:
    git:
      url: https://github.com/yringler/just_audio_service.git
```

# Setup
See documention for [just_audio](https://github.com/ryanheise/audio_service). This plugin is currently on version 0.10.0, but will be kept up to date with the latest audio_service plugin for the foreseeable future.

# Usage
This package has two things, a regular implementation of `BackgroundAudioTask`, and a `PositionedAudioTask` which, together with a `PositionManager` on the UI side, helps keep track of current position and optionaly can save a position (with hivedb).
Note that
* If you don't want the persistance, you can just use AudioTask()
* (TODO: add a MemoryPositionManager, which keeps track of positions in memory, per app run)
* You can still use the `PositionManager`, which provides a stream which doesn't lag with constant location updates, with the regular `AudioTask`

You can either use `AudioTask` in your top level audio_service `_audioPlayerTaskEntrypoint` or `PositionedAudioTask`

Here's a sample (from the example project) of everything which you have to do to start an audio task which will persist
position in media
```dart
// NOTE: Your entrypoint MUST be a top-level function.
void _audioPlayerTaskEntrypoint() {
  AudioServiceBackground.run(() => PositionedAudioTask.standard());
}
```
`PositionedAudioTask` has another constructor which lets you customize the base audio task and the persistance mechanism.

### Motivation
My initial audio BackgroundAudioTask quickly descended into a labyrinth of spaghetti code, inhabited by hosts of minotaur quick to consume any who hoped to maintain it.

Therefore, I set out to try again. This time, I have perhaps gone to the other extreme, and am relying heavily on the [state pattern](https://refactoring.guru/design-patterns/state). Each just_audio state has it's own class, which handles media operations (play, pause, etc) as best as it can, and hands off to another state class as soon as possible.
