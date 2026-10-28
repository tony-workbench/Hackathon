# Produce Inspection

## How it works

- While streaming, the camera button sends the current video frame to inspection (and also takes a regular photo for the preview). See `ControlsView` in `StreamView.swift`.
- `ProduceInspectionViewModel.swift` sends the frame as a JPEG to the backend (`POST /inspect-produce`), which asks Gemini to rate freshness and damage and recommend an action.
- `ProduceInspectionView.swift` shows the result.
- The backend URL comes from `AppConfiguration`, the same one live translation uses.

## Common problems

| Problem | Likely cause | Fix |
| --- | --- | --- |
| "Photo capture failed" alert | The stream is not live yet, or a capture is already running. | Wait until video shows, then tap once. |
| "Inspection request failed" | The backend is stopped, the tunnel address changed, or Gemini rejected the request. | Keep the backend and tunnel running; after restarting a quick tunnel, put the new address in Settings. |
| HTTP 404 for `/inspect-produce` | The backend at that address is the minimal `server.py`, which only translates. | Use the FastAPI backend in `backend/translation-backend`. |
| HTTP 502 | The Gemini request failed or came back empty. | Check the backend terminal, your API key and your quota. |
| The result says it cannot assess the produce | The frame does not clearly show produce. | Move closer, add light, and fill the frame with the produce. |
| With the mock device, nothing is inspected | The mock device has no camera feed. | In the mock device menu, set **Camera Source** to a video file or a phone camera first. |
