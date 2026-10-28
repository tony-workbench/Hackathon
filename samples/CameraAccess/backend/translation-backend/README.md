# Backend (FastAPI)

The backend the app talks to. It translates short audio clips (English ↔ Spanish, English ↔ Mandarin), inspects produce photos with Google Gemini, and can place a Twilio phone call with the inspection result. The Gemini key stays here, not in the app.

## What you need

- Python 3.10 or later (`python3 --version`)
- A Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey)
- `cloudflared`, so the iPhone can reach this backend over HTTPS: `brew install cloudflared`, or see [Cloudflare's downloads](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/)
- Optional, for the phone-call alert: a [Twilio](https://www.twilio.com/) account with a phone number

## Steps

1. Go to this folder and install:

   ```bash
   cd samples/CameraAccess/backend/translation-backend
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

2. Copy the example settings:

   ```bash
   cp .env.example .env
   ```

3. Open `.env` and set `GEMINI_API_KEY` to your key. Fill in the `TWILIO_…`, `BOB_PHONE_NUMBER` and `BACKEND_PUBLIC_URL` lines only if you want real phone calls; left empty, the app plays a demo call.

4. Start the backend:

   ```bash
   uvicorn app:app --host 0.0.0.0 --port 8000
   ```

   It stops and tells you to set `GEMINI_API_KEY` if the key is missing.

5. In a second terminal, open a tunnel:

   ```bash
   cloudflared tunnel --url http://localhost:8000
   ```

   It prints an address like `https://<random-words>.trycloudflare.com`. Use this address as the backend URL in the app. It changes each time you restart the tunnel.

Steps 1, 2 and 4 are also in `./run_local.sh`, and step 5 is in `./run_quick_tunnel.sh`.

## Check it works

```bash
curl http://localhost:8000/
```

Returns `{"status":"ok",...,"callsConfigured":false}` (`true` once Twilio is set up). Run the same command with your tunnel address to check the tunnel.

## Optional: a fixed address

A quick tunnel gets a new address on every restart. For an address that stays the same, you need a domain on Cloudflare.

1. Log in and create a tunnel:

   ```bash
   cloudflared tunnel login
   cloudflared tunnel create cameraaccess-translation
   cloudflared tunnel route dns cameraaccess-translation translate.yourdomain.com
   ```

2. Copy `cloudflared-config.example.yml` to `config.yml`. Fill in the tunnel ID and credentials file path that `tunnel create` printed, and your hostname.
3. Run it:

   ```bash
   cloudflared tunnel --config config.yml run cameraaccess-translation
   ```

4. Use `https://translate.yourdomain.com` as the backend URL in the app.
