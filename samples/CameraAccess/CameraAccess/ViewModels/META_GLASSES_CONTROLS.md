# Glasses Controls for Translation

Start and stop live translation from the glasses instead of the phone screen.

## How it works

When translation is open, the app registers as the phone's "now playing" audio app (title **Live Translation**). Media controls then reach the app:

| Control | Action |
| --- | --- |
| Play | Start listening |
| Pause | Stop listening and translate what you said |
| Play/pause toggle (a tap on the glasses touchpad) | Start or stop, depending on the current state |

The code is `setupRemoteCommandCenter()` and `updateNowPlayingInfo(isListening:)` in `LiveTranslationViewModel.swift`.

## If the glasses do nothing

- Check that the glasses are connected to the phone over Bluetooth as an audio device.
- Open the translation screen first. The commands are registered when it opens.
- Another app playing audio (music, a podcast) takes the controls. Stop it and try again.
- Use the on-screen button to check that translation itself works.
