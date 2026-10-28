# CameraAccess App

The iPhone app: Meta's CameraAccess sample, extended. It streams the camera from Meta AI glasses, translates speech live between English and Spanish or Mandarin, and inspects produce from a photo taken with the glasses.

## What you need

- A Mac with Xcode 16 or later
- An iPhone on iOS 17 or later
- Meta AI glasses with Developer Mode on in the Meta AI app, or the built-in mock device (debug builds only)
- The backend running and reachable over HTTPS. See [the backend README](backend/translation-backend/README.md).

## Steps

1. Start the backend and its Cloudflare tunnel by following [the backend README](backend/translation-backend/README.md). Copy the `https://` address.
2. Open `CameraAccess.xcodeproj` in Xcode. Wait until the package `meta-wearables-dat-ios` finishes downloading.
3. Open `CameraAccess/ViewModels/AppConfiguration.swift` and replace `https://your-backend.example.com` with your backend address. You can change it later in the app: tap the gear icon, then **Settings**.
4. Select the **CameraAccess** target, open **Signing & Capabilities**, choose your Team, and set a unique Bundle Identifier.
5. Connect your iPhone, select it as the run destination, and press **Cmd+R**.
6. In the app, tap **Connect my glasses** and approve the request in the Meta AI app.

### Without glasses

1. Run a Debug build (the default when you press **Cmd+R**).
2. Tap the ladybug button on the right edge of the screen.
3. Tap **Enable MockDeviceKit**, then **Pair RayBan Meta**.
4. Close the menu and tap **Connect my glasses**.

## Use the features

- **Live translation:** tap **Start translation** (or **Translate** while streaming), pick a direction (English ↔ Spanish or English ↔ Mandarin), and speak.
- **Produce inspection:** tap **Start streaming**, point the glasses at produce, and tap the camera button. You get freshness, damage, and a recommended action.
- **Call alert:** when an inspection marks the produce for review or rejection, tap **Open Call Session**, then **Start Call**, to phone a contact through Twilio. If Twilio is not set up on the backend, the app plays a demo call instead.
- **Settings:** tap the gear icon, then **Settings**, to change the backend URL, test the connection, or always use demo calls.

## Check it works

1. On your Mac, run `curl https://YOUR-TUNNEL-ADDRESS/`. It returns `{"status":"ok",...}`.
2. In the app, speak in English on the translation screen. The transcript and Spanish translation appear within a few seconds.

## Docs

- [Screens and buttons](CameraAccess/ViewModels/UI_REFERENCE.md)
- [Testing live translation](CameraAccess/ViewModels/TRANSLATION_TESTING.md), [Mandarin](CameraAccess/Views/UI_REDESIGN.md), [spoken output](CameraAccess/Views/AUDIO_OUTPUT_GUIDE.md), [glasses controls](CameraAccess/ViewModels/META_GLASSES_CONTROLS.md)
- [Produce inspection](CameraAccess/Views/PRODUCE_INSPECTION_INTEGRATION_NOTES.md), [camera button](CameraAccess/Views/UI_BUTTON_MERGE.md), [call alert](CameraAccess/ViewModels/LIVE_SUPPORT_GUIDE.md)

## Help

- [Meta Wearables developer documentation](https://wearables.developer.meta.com/docs/develop/)
- [Upstream SDK discussions](https://github.com/facebook/meta-wearables-dat-ios/discussions)

Licensed under the [LICENSE](../../LICENSE) file in the repository root.
