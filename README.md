# just_audio_service

In early stages of development.
Intended to be a robust, well written, easy to use implementation of audio_service using just_audio.
Note that initial goal is only to support a limited set of requirements, not to be properly configurable.
That being said, I hope that it is a good starting point for others to base their implementations off.

### Motivation
My initial audio BackgroundAudioTask quickly descended into a labarynth of spaghetti code, inhabited by hosts of minotaur quick to consume any who hoped to mantain it.

Therefore, I set out to try again. This time, I have perhaps gone to the other extreme, and am relying heavily on the [state pattern](https://refactoring.guru/design-patterns/state). Each just_audio state has it's own class, which handles media operations (play, pause, etc) as best as it can, and hands off to another state class as soon as possible.
