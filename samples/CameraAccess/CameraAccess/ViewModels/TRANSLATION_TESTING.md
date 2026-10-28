# Testing Live Translation

## What happens when you speak

1. **Start translation** (or **Translate** while streaming) opens the translation screen. Pick a direction: English ↔ Spanish or English ↔ Mandarin.
2. Tap the microphone button and speak. The app records from the phone's audio input, which is the glasses when they are connected.
3. Tap stop. The app trims silence from both ends, converts the clip to 16 kHz mono WAV and sends it to the backend (`POST /translate-audio`).
4. The backend asks Gemini for a transcript and a translation. The app shows both and reads the translation aloud.

Short sentences work best. Each request waits at most 15 seconds.

## Test without a backend

In `LiveTranslationViewModel.swift`, set `useMockTranslation` to `true`. The app then shows a fixed English/Spanish sentence after half a second. Set it back to `false` when done.

In Debug builds, the translation screen also has a **Test** button that checks the backend connection.

## Common errors

| Message | Cause | Fix |
| --- | --- | --- |
| HTTP 530 | The Cloudflare tunnel is down. | Restart `cloudflared tunnel --url http://localhost:8000`, then put the new address in Settings. |
| Request timed out | The backend or Gemini is slow or unreachable. | Check the backend terminal for errors; try a shorter sentence. |
| No speech detected | The clip was silent or too quiet. | Speak louder or closer to the microphone. |
| Microphone permission is required | Microphone access was denied. | Allow it in the iPhone Settings app under CameraAccess. |

## Logs

Run from Xcode and watch the console. Each request logs the direction, audio size, response time, transcript and translation. Debug builds also save each clip as a WAV file in the app's Documents folder. To get the files, open Xcode > Devices and Simulators, select CameraAccess, and choose Download Container.
