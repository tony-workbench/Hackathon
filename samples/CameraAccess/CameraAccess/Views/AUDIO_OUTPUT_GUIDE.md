# Spoken Translation Output

## How it works

After each translation, the app speaks the translated text with the iPhone's built-in text-to-speech (`AVSpeechSynthesizer`). The voice matches the target language:

| Target language | Voice |
| --- | --- |
| Spanish | `es-ES` |
| Mandarin | `zh-CN` |
| English | `en-US` |

Speech rate is 0.5 (normal). A new translation interrupts one that is still being spoken. The code is `speakTranslation(_:language:)` in `LiveTranslationViewModel.swift`.

The speaker button on the translation screen turns spoken output on or off. It is on by default.

## Hearing it in the glasses

The audio session allows Bluetooth output, so sound goes to the glasses when they are the phone's active audio device. If you hear it from the phone instead:

1. Open Control Center, tap the audio output button, and choose the glasses.
2. Check that the glasses are paired in the iPhone's Bluetooth settings, not only in the Meta AI app.

If a voice sounds wrong or is missing, download it on the iPhone under Settings > Accessibility > Spoken Content > Voices.
