#!/usr/bin/env python3
"""Minimal translation backend: takes short audio clips from the iPhone app and
returns a Gemini transcript and translation as JSON. The Gemini key stays here.

Gemini's standard audio API is not realtime, so the app sends short clips
instead of a continuous stream.
"""

from __future__ import annotations

import base64
import json
import os
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib import error, request

HOST = os.environ.get("HOST", "0.0.0.0")
PORT = int(os.environ.get("PORT", "8080"))
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
if GEMINI_API_KEY in ("", "replace_me"):  # placeholder from .env.example
    GEMINI_API_KEY = None
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash-lite")
GEMINI_ENDPOINT = (
    f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"
)

SUPPORTED_DIRECTIONS = {
    "englishToSpanish": ("English", "Spanish"),
    "spanishToEnglish": ("Spanish", "English"),
    "englishToMandarin": ("English", "Mandarin Chinese (Simplified characters)"),
    "mandarinToEnglish": ("Mandarin Chinese", "English"),
}


class TranslationHandler(BaseHTTPRequestHandler):
    server_version = "CameraAccessTranslationBackend/1.0"

    def do_GET(self) -> None:  # noqa: N802
        if self.path in ("/", "/health"):
            self._send_json({"ok": True, "model": GEMINI_MODEL})
            return
        self._send_json({"error": "Not found"}, HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:  # noqa: N802
        if self.path != "/translate-audio":
            self._send_json({"error": "Not found"}, HTTPStatus.NOT_FOUND)
            return

        print("[translate-audio] request received")

        if not GEMINI_API_KEY:
            self._send_json(
                {"error": "Server is missing GEMINI_API_KEY"},
                HTTPStatus.INTERNAL_SERVER_ERROR,
            )
            return

        try:
            payload = self._read_json()
            audio_base64 = self._required_string(payload, "audioBase64")
            mime_type = self._required_string(payload, "mimeType")
            direction = self._required_string(payload, "direction")
            source_language, target_language = SUPPORTED_DIRECTIONS[direction]
            self._validate_audio(audio_base64)
        except KeyError as exc:
            self._send_json({"error": f"Missing or invalid field: {exc.args[0]}"}, HTTPStatus.BAD_REQUEST)
            return
        except ValueError as exc:
            self._send_json({"error": str(exc)}, HTTPStatus.BAD_REQUEST)
            return

        gemini_payload = self._build_gemini_payload(
            audio_base64=audio_base64,
            mime_type=mime_type,
            source_language=source_language,
            target_language=target_language,
        )

        try:
            gemini_response = self._call_gemini(gemini_payload)
            result = self._extract_json_result(gemini_response)
        except RuntimeError as exc:
            print(f"[translate-audio] failed: {exc}")
            self._send_json({"error": str(exc)}, HTTPStatus.BAD_GATEWAY)
            return

        print(
            "[translate-audio] result "
            f"transcript_len={len(result['transcript'])} "
            f"translation_len={len(result['translation'])}"
        )
        print("[translate-audio] completed successfully")
        self._send_json(result)

    def log_message(self, format: str, *args: Any) -> None:
        # Keep output concise and avoid logging request bodies/audio.
        print(f"[{self.log_date_time_string()}] {self.address_string()} - {format % args}")

    def _read_json(self) -> dict[str, Any]:
        content_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(content_length)
        try:
            parsed = json.loads(raw_body.decode("utf-8"))
        except json.JSONDecodeError as exc:
            raise ValueError("Request body must be valid JSON") from exc
        if not isinstance(parsed, dict):
            raise ValueError("Request body must be a JSON object")
        return parsed

    def _required_string(self, payload: dict[str, Any], field: str) -> str:
        value = payload.get(field)
        if not isinstance(value, str) or not value.strip():
            raise KeyError(field)
        if field == "direction" and value not in SUPPORTED_DIRECTIONS:
            raise ValueError("direction must be one of: " + ", ".join(SUPPORTED_DIRECTIONS))
        return value

    def _validate_audio(self, audio_base64: str) -> None:
        try:
            decoded = base64.b64decode(audio_base64, validate=True)
        except Exception as exc:  # noqa: BLE001
            raise ValueError("audioBase64 must be valid base64") from exc
        if not decoded:
            raise ValueError("audioBase64 must not be empty")
        if len(decoded) > 10 * 1024 * 1024:
            raise ValueError("audio chunk is too large; keep chunks under 10 MB")

    def _build_gemini_payload(
        self,
        *,
        audio_base64: str,
        mime_type: str,
        source_language: str,
        target_language: str,
    ) -> dict[str, Any]:
        prompt = (
            "You are a speech translation service. "
            f"The speaker is using {source_language}. "
            f"Return a JSON object with exactly two keys: transcript and translation. "
            f"transcript must be the spoken words in {source_language}. "
            f"translation must be the natural {target_language} translation. "
            "If no clear speech is present, return empty strings for both values."
        )
        return {
            "contents": [
                {
                    "parts": [
                        {"text": prompt},
                        {
                            "inlineData": {
                                "mimeType": mime_type,
                                "data": audio_base64,
                            }
                        },
                    ]
                }
            ],
            "generationConfig": {
                "responseMimeType": "application/json",
                "temperature": 0.2,
            },
        }

    def _call_gemini(self, payload: dict[str, Any]) -> dict[str, Any]:
        body = json.dumps(payload).encode("utf-8")
        retryable_status_codes = {500, 503}
        max_attempts = 3

        for attempt in range(1, max_attempts + 1):
            gemini_request = request.Request(
                GEMINI_ENDPOINT,
                data=body,
                method="POST",
                headers={
                    "Content-Type": "application/json",
                    "x-goog-api-key": GEMINI_API_KEY,
                },
            )
            try:
                with request.urlopen(gemini_request, timeout=60) as response:
                    return json.loads(response.read().decode("utf-8"))
            except error.HTTPError as exc:
                details = exc.read().decode("utf-8", errors="replace")
                if exc.code in retryable_status_codes and attempt < max_attempts:
                    delay = 2 ** (attempt - 1)
                    print(f"[gemini] transient HTTP {exc.code}; retrying in {delay}s")
                    time.sleep(delay)
                    continue
                raise RuntimeError(f"Gemini request failed with HTTP {exc.code}: {details}") from exc
            except error.URLError as exc:
                if attempt < max_attempts:
                    delay = 2 ** (attempt - 1)
                    print(f"[gemini] network error {exc.reason}; retrying in {delay}s")
                    time.sleep(delay)
                    continue
                raise RuntimeError(f"Gemini request failed: {exc.reason}") from exc

        raise RuntimeError("Gemini request failed after retries")

    def _extract_json_result(self, response_payload: dict[str, Any]) -> dict[str, str]:
        try:
            text = response_payload["candidates"][0]["content"]["parts"][0]["text"]
            parsed = json.loads(self._strip_markdown_json_fence(text))
            transcript = parsed.get("transcript", "")
            translation = parsed.get("translation", "")
        except (KeyError, IndexError, TypeError, json.JSONDecodeError) as exc:
            print(f"[translate-audio] unexpected Gemini response payload: {json.dumps(response_payload)[:2000]}")
            raise RuntimeError("Gemini returned an unexpected response format") from exc

        if not isinstance(transcript, str) or not isinstance(translation, str):
            raise RuntimeError("Gemini returned non-string transcript or translation")
        return {"transcript": transcript, "translation": translation}

    def _strip_markdown_json_fence(self, text: str) -> str:
        stripped = text.strip()
        if stripped.startswith("```json"):
            stripped = stripped[len("```json"):].strip()
        elif stripped.startswith("```"):
            stripped = stripped[len("```"):].strip()
        if stripped.endswith("```"):
            stripped = stripped[:-len("```")].strip()
        return stripped

    def _send_json(self, payload: dict[str, Any], status: HTTPStatus = HTTPStatus.OK) -> None:
        encoded = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


def main() -> None:
    server = ThreadingHTTPServer((HOST, PORT), TranslationHandler)
    print(f"Listening on http://{HOST}:{PORT}")
    if GEMINI_API_KEY:
        print("GEMINI_API_KEY is configured.")
    else:
        print("Warning: GEMINI_API_KEY is not configured.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
