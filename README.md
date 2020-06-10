# just_audio_service

In development, but there is currently a working example project!<br>
<br>
Intended to be a robust, well written, easy to use implementation of audio_service using just_audio.<br>
Note that initial goal is only to support a limited set of requirements, not to be properly configurable.<br>
That being said, I hope that it is a good starting point for others to base their implementations off, and PRs (or feature requests) are most welcome.

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
