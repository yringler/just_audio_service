# just_audio_service

In development, but there is currently a working example project!<br>
<br>
Intended to be a robust, well written, easy to use implementation of audio_service using just_audio.<br>
It also has a background audio task which supports saving current position in a media file, and accessing that from
either background or UI thread.<br>
Note that initial goal is only to support a limited set of requirements, not to be properly configurable.<br>
That being said, I hope that it is a good starting point for others to base their implementations off, and PRs (or feature requests) are most welcome.

# Usage
This package has two things, a regular implementation of `BackgroundAudioTask`, and a `PositionedAudioTask` which, together with a `PositionManager` on the UI side, helps keep track of current position (no more ui lag for position sliders) and optionaly save a position (with hivedb).
The example app uses the position abilities, which comes down to a few snippets.
Note that
* A backing audio task is passed in
* A position data manager, which persists the position, is passed in
* The position data manager is optional. Don't pass it in, everything else will still work. (TODO: add a `MemoryPositionManager`, which keeps track of positions in memory, per app run)
* If you don't want the persistance, you can just use AudioTask()
* You can get the help with seeking (a new stream which doesn't lag with constant location updates) with just using the regular `AudioTask`
```dart
// A simple example, if you don't want to use DI.
// Possibly this will be available staticaly from the package in the future
final positionManager = PositionManager(
    positionDataManager: PositionDataManager(storePath: "hive"));

...

// NOTE: Your entrypoint MUST be a top-level function.
void _audioPlayerTaskEntrypoint() async {
  AudioServiceBackground.run(
      () => PositionedAudioTask(audioTask: AudioTask(), storePath: "hive"));
}
```

### Motivation
My initial audio BackgroundAudioTask quickly descended into a labyrinth of spaghetti code, inhabited by hosts of minotaur quick to consume any who hoped to maintain it.

Therefore, I set out to try again. This time, I have perhaps gone to the other extreme, and am relying heavily on the [state pattern](https://refactoring.guru/design-patterns/state). Each just_audio state has it's own class, which handles media operations (play, pause, etc) as best as it can, and hands off to another state class as soon as possible.
