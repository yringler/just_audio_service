# just_audio_service

# :warning: Quickly becoming obsolete
This plugin works for what I need, and I'm using it in a production app with 600+ users, but it is very dated.
All of the complicated code, most of the work, is working around limitations in the just_audio plugin, audio_service, and hive - limitations which either _do not exist anymore_ or quickly won't be an issue.
I do intend to update to the latest audio_service/just_audio, but right now I'm busy with other parts of the app, and the audio play back works fine.

# :warning: Disclaimer :warning:
As is enumerated below and in the project issues, this plugin doesn't support some basic things, and is not sufficiant for most use cases. I can only recommend
it's use if at least one of the following is true:
1. You are aware of and OK with the limitations, and are comfortable fixing any bugs which may bug you
1. You are willing to make PRs for any features which it doesn't have yet.
1. You want to fork this entirely and make you're own, better plugin

It is because of these limitations that I haven't published this to pub.dev yet.

# Summary
In beta, and in production use (in an app of mine).<br>
<br>
Intended to be a robust, well written, easy to use implementation of audio_service using just_audio.<br>
Note that initial goal is only to support a limited set of requirements (i.e. mine), not to be properly configurable.
For example, it doesn't support 
1. playlists
2. customizing the buttons on the android notification.
3. playing audio from any source other than URL
4. setting audio metadata - album, artist, etc

That being said, I hope that it is a good starting point for others to base their implementations off, and PRs (or feature requests, or forks) are most welcome.

# Installation
This is not yet available on pub.dev, but can be used from git
```yaml
  just_audio_service:
    git:
      url: https://github.com/yringler/just_audio_service.git
```

# Setup
See documention for [audio_service](https://github.com/ryanheise/audio_service). This plugin is currently on version 0.10.0, but will be kept up to date with the latest audio_service plugin for the foreseeable future.

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

To use `PositionManager`: you'd want to make sure to only have one instance per app, either using provider, some other DI mechanism, or saving it to a static property.
To take advantage of the position streams, seek via the `seek` method, not directly with `AudioService` method.
Note that if you opt to save position, (For example, by using the `PositionedAudioTask.standard()` constructor, you can call seek on a media which isn't active, and playback for that media will start from the seeked-to position.

There is now also a `DownloadAudioTask`, which is used with `DownloadManager` on the client to download audio files for
offline playback. It is somewhat progressive - if audio is streaming and then downloaded, when the download is finished the
playback will switch to the offline file.

### Motivation
My initial audio BackgroundAudioTask quickly descended into a labyrinth of spaghetti code, inhabited by hosts of minotaur quick to consume any who hoped to maintain it.

Therefore, I set out to try again. This time, I have perhaps gone to the other extreme, and am relying heavily on the [state pattern](https://refactoring.guru/design-patterns/state). Each just_audio state has it's own class, which handles media operations (play, pause, etc) as best as it can, and hands off to another state class as soon as possible.
