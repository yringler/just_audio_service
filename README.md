# just_audio_service

In development, but there is currently a working example project!<br>
<br>
Intended to be a robust, well written, easy to use implementation of audio_service using just_audio.<br>
It also has a background audio task which supports saving current position in a media file, and accessing that from
either background or UI thread.<br>
Note that initial goal is only to support a limited set of requirements, not to be properly configurable.<br>
That being said, I hope that it is a good starting point for others to base their implementations off, and PRs (or feature requests) are most welcome.

### Motivation
My initial audio BackgroundAudioTask quickly descended into a labyrinth of spaghetti code, inhabited by hosts of minotaur quick to consume any who hoped to maintain it.

Therefore, I set out to try again. This time, I have perhaps gone to the other extreme, and am relying heavily on the [state pattern](https://refactoring.guru/design-patterns/state). Each just_audio state has it's own class, which handles media operations (play, pause, etc) as best as it can, and hands off to another state class as soon as possible.
