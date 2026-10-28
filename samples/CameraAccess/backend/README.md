# Minimal Backend

A one-file backend that only does live translation. It uses only the Python standard library, so there is nothing to install. It does not support produce inspection or phone calls; for those, use the [FastAPI backend](translation-backend/README.md).

## What you need

- Python 3.9 or later (`python3 --version`)
- A Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey)
- `cloudflared` if the app runs on a real iPhone: `brew install cloudflared`

## Steps

1. Go to this folder and copy the example settings:

   ```bash
   cd samples/CameraAccess/backend
   cp .env.example .env
   ```

2. Open `.env` and set `GEMINI_API_KEY` to your key.

3. Load the settings and start the server:

   ```bash
   set -a; source .env; set +a
   python3 server.py
   ```

   It listens on port 8080.

4. In a second terminal, open a tunnel and use the `https://` address it prints as the backend URL in the app:

   ```bash
   cloudflared tunnel --url http://localhost:8080
   ```

## Check it works

```bash
curl http://localhost:8080/health
```

Returns `{"ok": true, "model": "gemini-2.5-flash-lite"}`.
