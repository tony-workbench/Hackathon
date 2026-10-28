# Mandarin Translation

## How it works

The app offers four directions: `englishToSpanish`, `spanishToEnglish`, `englishToMandarin` and `mandarinToEnglish`. The direction is sent to the backend with each clip, and the backend tells Gemini which languages to use. Mandarin translations come back in Simplified Chinese characters and are spoken with the `zh-CN` voice.

In the app the Mandarin directions are labelled "English → 中文" and "中文 → English". The full-screen translation view also has quick buttons labelled "EN→中文", "中文→EN" and "EN→ES".

## Test it

1. Open a translation screen and pick **English → 中文**.
2. Say "Hello, how are you?". You should see 你好，你好吗？ or similar, and hear it in Mandarin.
3. Pick **中文 → English** and say 你好 (nǐ hǎo). You should see "Hello".

If the Mandarin voice is missing, download it on the iPhone under Settings > Accessibility > Spoken Content > Voices.
