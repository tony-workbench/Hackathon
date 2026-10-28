# Setup

- [Repository README](../../../../README.md): everything from a fresh clone to running on an iPhone.
- [CameraAccess README](../../README.md): the app on its own, including the mock device for testing without glasses.
- [Backend README](../../backend/translation-backend/README.md): the FastAPI backend, the Cloudflare tunnel, and optional Twilio calls.

The one value you must set in the app is the backend URL. Set it in `AppConfiguration.swift` (`defaultBackendURL`) or in the app under the gear icon, then **Settings**. Both live translation and produce inspection use it.
