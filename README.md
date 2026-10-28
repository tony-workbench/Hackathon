# Hackathon Prototype: Meta AI Glasses Assistant

A hackathon prototype: an iPhone app for Meta AI glasses that translates speech live (English ↔ Spanish, English ↔ Mandarin) and inspects produce from a photo taken with the glasses. A small Python backend calls Google Gemini so the API key never ships in the app.

**Built on** Meta's [Wearables Device Access Toolkit for iOS](https://github.com/facebook/meta-wearables-dat-ios) and its CameraAccess sample. Use of the toolkit is subject to the [Meta Wearables Developer Terms](https://wearables.developer.meta.com/terms) and [Acceptable Use Policy](https://wearables.developer.meta.com/acceptable-use-policy). See [LICENSE](LICENSE).

## What you need

- **A Mac with Xcode 16 or later.** Get it from the [Mac App Store](https://apps.apple.com/app/xcode/id497799835).
- **An iPhone on iOS 17 or later**, plus an Apple ID signed in to Xcode so you can install the app on it.
- **Meta AI glasses** paired in the [Meta AI app](https://www.meta.com/ai-glasses/app/), with Developer Mode turned on. No glasses? Debug builds include a mock device you can use instead.
- **Python 3.10 or later.** Check with `python3 --version`. Get it from [python.org](https://www.python.org/downloads/).
- **A Gemini API key.** Create one for free at [Google AI Studio](https://aistudio.google.com/apikey).
- **cloudflared**, to give your backend an HTTPS address the phone can reach. Install with `brew install cloudflared` or see [Cloudflare's downloads](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/).
- Optional: a [Twilio](https://www.twilio.com/) account, only if you want the produce alert to place a real phone call. Without it the app plays a demo call.

## Steps

1. **Clone the repo.**

   ```bash
   git clone https://github.com/tony-workbench/Hackathon.git
   cd Hackathon
   ```

2. **Start the backend.**

   ```bash
   cd samples/CameraAccess/backend/translation-backend
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   cp .env.example .env
   ```

   Open `.env` and set `GEMINI_API_KEY` to your key. Then start it:

   ```bash
   uvicorn app:app --host 0.0.0.0 --port 8000
   ```

3. **Give the backend an HTTPS address.** In a second terminal:

   ```bash
   cloudflared tunnel --url http://localhost:8000
   ```

   Copy the `https://….trycloudflare.com` address it prints. It changes every time you restart the tunnel.

4. **Open the Xcode project.** In a third terminal, from the `Hackathon` folder:

   ```bash
   open samples/CameraAccess/CameraAccess.xcodeproj
   ```

   Wait for Xcode to finish downloading the package `meta-wearables-dat-ios`.

5. **Set the backend URL.** Open `samples/CameraAccess/CameraAccess/ViewModels/AppConfiguration.swift` and replace `https://your-backend.example.com` with the address from step 3. You can change it later in the app: tap the gear icon, then **Settings**.

6. **Set up signing.** Select the **CameraAccess** target, open **Signing & Capabilities**, choose your own Team, and change the Bundle Identifier to something unique (for example `com.yourname.cameraaccess`).

7. **Run on your iPhone.** Plug in the phone, select it as the run destination, and press **Cmd+R**.

8. **Connect the glasses.** In the app, tap **Connect my glasses** and approve the request in the Meta AI app.

## Check it works

- On your Mac, `curl http://localhost:8000/` returns `{"status":"ok",...}`.
- In the app, tap **Start translation**, pick **English → Spanish**, and speak. You see your words and the Spanish translation.

## More detail

- [CameraAccess app](samples/CameraAccess/README.md): building, mock device, using the features
- [Backend (FastAPI)](samples/CameraAccess/backend/translation-backend/README.md): the backend used above, with a stable Cloudflare hostname
- [Minimal backend](samples/CameraAccess/backend/README.md): translation-only backend with no dependencies
- [DisplayAccess sample](samples/DisplayAccess/README.md): unchanged upstream sample for Meta Ray-Ban Display glasses
- [Upstream SDK documentation](https://wearables.developer.meta.com/docs/develop/)
