# Call Alert

## When it appears

After an inspection, the result screen shows an **Escalation** section when the produce is marked for review or rejection. It has:

- **Open Call Session**: opens a screen where **Start Call** phones the primary contact ("Bob") with a short spoken summary of the inspection.
- **Manual contacts**: a list of numbers you can call yourself from the phone. The list is `helpContacts` in `ProduceInspectionViewModel.swift`. Edit it for your own contacts.

## Real call or demo call

- **Real call:** the app sends the inspection result to the backend (`POST /call-bob`). The backend asks Gemini for a short message and has Twilio phone `BOB_PHONE_NUMBER` and read it out. The app then checks the call status every 3 seconds.
- **Demo call:** the app plays a scripted transcript on screen and places no call. This happens when **Use demo call mode** is on in Settings, or when the backend has no Twilio settings (it answers with HTTP 503).

## Set up real calls

1. Create a [Twilio](https://www.twilio.com/) account and get a phone number.
2. In the backend's `.env`, fill in `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER`, `BOB_PHONE_NUMBER` (the number to call) and `BACKEND_PUBLIC_URL` (your tunnel address, so Twilio can report call status).
3. Restart the backend. `curl http://localhost:8000/` now shows `"callsConfigured":true`.
4. In the app, turn off **Use demo call mode** in Settings.

On a Twilio trial account, you can only call numbers you have verified in the Twilio console.
