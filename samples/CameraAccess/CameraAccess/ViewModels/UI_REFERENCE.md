# Screens and Buttons

## Home screen (glasses connected, not streaming)

- **Gear icon** (top right): opens a menu with **Settings** (backend URL, connection test, demo call mode) and **Disconnect**.
- **Start streaming**: starts the glasses camera stream. Disabled until a device is connected.
- **Start translation**: opens the translation screen. It works without streaming.
- **Ladybug button** (right edge, Debug builds only): the mock device menu, for testing without glasses.

## Streaming screen

- **Translate**: opens the full-screen translation view.
- **Stop streaming**: ends the stream and returns to the home screen.
- **Camera button**: takes a photo with the glasses and shows it in a preview, and at the same time sends the current video frame for produce inspection.

## Produce inspection result

Shows freshness, damage, status (for example review or reject), severity, issues and recommendations. When the status is review or reject, an **Escalation** section offers **Open Call Session** and a list of manual contacts. See [LIVE_SUPPORT_GUIDE.md](LIVE_SUPPORT_GUIDE.md).

## Translation screens

There are two: a compact one from **Start translation** on the home screen, and a full-screen one from **Translate** while streaming. Both have:

- a direction picker (English → Spanish, Spanish → English, English → 中文, 中文 → English);
- the transcript of what you said and its translation;
- a microphone button to start and stop listening;
- a speaker button to turn spoken output on or off;
- a microphone level indicator.

The full-screen view adds quick buttons for each direction.
