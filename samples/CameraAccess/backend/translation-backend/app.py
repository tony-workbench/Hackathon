import base64
import json
import os
from typing import Literal
from urllib.parse import parse_qs

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from google import genai
from google.genai import types
from pydantic import BaseModel
from twilio.rest import Client as TwilioClient
from twilio.twiml.voice_response import VoiceResponse

load_dotenv()



def setting(name: str, default: str | None = None) -> str | None:
    # .env.example ships "replace_with_..." placeholders; treat them as unset.
    value = (os.getenv(name) or "").strip()
    if not value or value.startswith("replace_with"):
        return default
    return value


GEMINI_API_KEY = setting("GEMINI_API_KEY")
GEMINI_MODEL = setting("GEMINI_MODEL", "gemini-2.5-flash-lite")
TWILIO_ACCOUNT_SID = setting("TWILIO_ACCOUNT_SID")
TWILIO_AUTH_TOKEN = setting("TWILIO_AUTH_TOKEN")
TWILIO_PHONE_NUMBER = setting("TWILIO_PHONE_NUMBER")
BOB_PHONE_NUMBER = setting("BOB_PHONE_NUMBER")
BACKEND_PUBLIC_URL = setting("BACKEND_PUBLIC_URL")

if not GEMINI_API_KEY:
    raise RuntimeError("Set GEMINI_API_KEY in .env (get a key at https://aistudio.google.com/apikey)")

client = genai.Client(api_key=GEMINI_API_KEY)
twilio_client = (
    TwilioClient(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
    if TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN
    else None
)

app = FastAPI(title="Live Translation Backend")
call_statuses: dict[str, dict[str, object]] = {}
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


class TranslationRequest(BaseModel):
    direction: Literal["englishToSpanish", "spanishToEnglish", "englishToMandarin", "mandarinToEnglish"]
    mimeType: str
    audioBase64: str


class TranslationResponse(BaseModel):
    transcript: str
    translation: str


class ProduceInspectionRequest(BaseModel):
    mimeType: str
    imageBase64: str


class ProduceInspectionResponse(BaseModel):
    summary: str
    freshness: str
    damage: str
    status: str
    severity: str
    issues: list[str]
    recommendations: list[str]
    action: str


class CallBobRequest(BaseModel):
    summary: str
    freshness: str
    damage: str
    status: str


class CallBobResponse(BaseModel):
    callSid: str
    message: str


class CallStatusResponse(BaseModel):
    status: str
    answered: bool
    terminal: bool


@app.get("/")
def health_check() -> dict[str, object]:
    return {
        "status": "ok",
        "service": "live-translation-backend",
        "model": GEMINI_MODEL,
        "callsConfigured": not missing_twilio_settings(),
    }


@app.post("/translate-audio", response_model=TranslationResponse)
def translate_audio(request: TranslationRequest) -> TranslationResponse:
    try:
        audio_bytes = base64.b64decode(request.audioBase64, validate=True)
    except Exception as error:
        raise HTTPException(status_code=400, detail="Invalid base64 audio payload") from error

    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Audio payload is empty")

    source_language, target_language = languages_for(request.direction)
    prompt = build_prompt(source_language=source_language, target_language=target_language)

    try:
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=[
                prompt,
                types.Part.from_bytes(
                    data=audio_bytes,
                    mime_type=request.mimeType,
                ),
            ],
        )
    except Exception as error:
        raise HTTPException(status_code=502, detail=f"Gemini request failed: {error}") from error

    raw_text = strip_markdown_code_fences((response.text or "").strip())
    try:
        parsed = json.loads(raw_text)
    except json.JSONDecodeError as error:
        raise HTTPException(
            status_code=502,
            detail=f"Gemini returned invalid JSON: {raw_text}",
        ) from error

    transcript = str(parsed.get("transcript", "")).strip()
    translation = str(parsed.get("translation", "")).strip()
    return TranslationResponse(transcript=transcript, translation=translation)


@app.post("/inspect-produce", response_model=ProduceInspectionResponse)
def inspect_produce(request: ProduceInspectionRequest) -> ProduceInspectionResponse:
    try:
        image_bytes = base64.b64decode(request.imageBase64, validate=True)
    except Exception as error:
        raise HTTPException(status_code=400, detail="Invalid base64 image payload") from error

    if not image_bytes:
        raise HTTPException(status_code=400, detail="Image payload is empty")

    try:
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=[
                build_produce_prompt(),
                types.Part.from_bytes(
                    data=image_bytes,
                    mime_type=request.mimeType,
                ),
            ],
        )
    except Exception as error:
        raise HTTPException(status_code=502, detail=f"Gemini request failed: {error}") from error

    raw_text = strip_markdown_code_fences((response.text or "").strip())
    try:
        parsed = json.loads(raw_text)
    except json.JSONDecodeError as error:
        raise HTTPException(
            status_code=502,
            detail=f"Gemini returned invalid JSON: {raw_text}",
        ) from error

    summary = str(parsed.get("summary", "")).strip()
    freshness = str(parsed.get("freshness", "")).strip()
    damage = str(parsed.get("damage", "")).strip()
    status = str(parsed.get("status", "")).strip()
    severity = str(parsed.get("severity", "")).strip()
    issues = [str(item).strip() for item in parsed.get("issues", []) if str(item).strip()]
    recommendations = [
        str(item).strip() for item in parsed.get("recommendations", []) if str(item).strip()
    ]
    action = str(parsed.get("action", "")).strip()

    if not all([summary, freshness, damage, status, severity, issues, recommendations, action]):
        raise HTTPException(status_code=502, detail="Gemini returned an empty inspection result")

    return ProduceInspectionResponse(
        summary=summary,
        freshness=freshness,
        damage=damage,
        status=status,
        severity=severity,
        issues=issues,
        recommendations=recommendations,
        action=action,
    )


@app.post("/call-bob", response_model=CallBobResponse)
def call_bob(request: CallBobRequest) -> CallBobResponse:
    missing = missing_twilio_settings()
    if missing:
        raise HTTPException(
            status_code=503,
            detail=f"Twilio is not configured. Missing: {', '.join(missing)}",
        )

    message = generate_call_message(request)
    voice_response = VoiceResponse()
    voice_response.say(
        message,
        voice="alice",
        language="en-US",
    )

    try:
        call = twilio_client.calls.create(
            to=BOB_PHONE_NUMBER,
            from_=TWILIO_PHONE_NUMBER,
            twiml=str(voice_response),
            timeout=20,
            status_callback=f"{BACKEND_PUBLIC_URL.rstrip('/')}/twilio/call-status",
            status_callback_event=["initiated", "ringing", "answered", "completed"],
            status_callback_method="POST",
        )
    except Exception as error:
        raise HTTPException(status_code=502, detail=f"Twilio call failed: {error}") from error

    call_statuses[call.sid] = {
        "status": call.status or "queued",
        "answered": False,
    }
    return CallBobResponse(callSid=call.sid, message=message)


@app.post("/twilio/call-status")
async def receive_twilio_call_status(request: Request) -> dict[str, str]:
    body = (await request.body()).decode("utf-8")
    params = parse_qs(body)
    call_sid = params.get("CallSid", [""])[0]
    call_status = params.get("CallStatus", [""])[0]

    if call_sid:
        previous = call_statuses.get(call_sid, {"status": "unknown", "answered": False})
        answered = bool(previous.get("answered")) or call_status == "in-progress"
        call_statuses[call_sid] = {
            "status": call_status or str(previous.get("status", "unknown")),
            "answered": answered,
        }

    return {"status": "ok"}


@app.get("/call-status/{call_sid}", response_model=CallStatusResponse)
def get_call_status(call_sid: str) -> CallStatusResponse:
    record = call_statuses.get(call_sid)
    if not record:
        raise HTTPException(status_code=404, detail="Unknown call")

    status = str(record["status"])
    terminal = status in {"completed", "busy", "failed", "no-answer", "canceled"}
    return CallStatusResponse(
        status=status,
        answered=bool(record["answered"]),
        terminal=terminal,
    )


LANGUAGES = {
    "englishToSpanish": ("English", "Spanish"),
    "spanishToEnglish": ("Spanish", "English"),
    "englishToMandarin": ("English", "Mandarin Chinese (Simplified characters)"),
    "mandarinToEnglish": ("Mandarin Chinese", "English"),
}


def languages_for(direction: str) -> tuple[str, str]:
    return LANGUAGES[direction]


def missing_twilio_settings() -> list[str]:
    return [
        name
        for name, value in {
            "TWILIO_ACCOUNT_SID": TWILIO_ACCOUNT_SID,
            "TWILIO_AUTH_TOKEN": TWILIO_AUTH_TOKEN,
            "TWILIO_PHONE_NUMBER": TWILIO_PHONE_NUMBER,
            "BOB_PHONE_NUMBER": BOB_PHONE_NUMBER,
            "BACKEND_PUBLIC_URL": BACKEND_PUBLIC_URL,
        }.items()
        if not value
    ]


def build_prompt(source_language: str, target_language: str) -> str:
    return f"""
You are a speech transcription and translation engine.

Task:
1. Transcribe the spoken {source_language} audio exactly.
2. Translate that transcript into {target_language}.

Return only valid JSON in this exact shape:
{{
  "transcript": "...",
  "translation": "..."
}}

Rules:
- Do not include markdown.
- Do not include explanations.
- If there is no intelligible speech, return empty strings for both fields.
- Preserve the meaning naturally in the translation.
""".strip()


def strip_markdown_code_fences(text: str) -> str:
    if not text.startswith("```"):
        return text

    lines = text.splitlines()
    if len(lines) >= 3 and lines[-1].strip() == "```":
        return "\n".join(lines[1:-1]).strip()

    return text


def build_produce_prompt() -> str:
    return """
You are a produce quality inspection assistant.

Analyze the image and return only valid JSON in this exact shape:
{
  "summary": "...",
  "freshness": "...",
  "damage": "...",
  "status": "...",
  "severity": "...",
  "issues": ["..."],
  "recommendations": ["..."],
  "action": "..."
}

Focus on:
- freshness
- bruising or visible damage
- spoilage indicators
- packaging or handling concerns

Rules:
- `summary` must be one concise paragraph for an operations team.
- `freshness` must be a short label such as "High", "Medium", "Low", or "Unclear".
- `damage` must be a short label such as "None", "Low", "Moderate", "High", or "Unclear".
- `status` must be a short label such as "Pass", "Review", "Reject", or "Unclear".
- `severity` must be a short label such as "Low", "Medium", "High", or "Unclear".
- `issues` must contain 1 to 4 concise observations.
- `recommendations` must contain 1 to 4 concise next steps.
- `action` must be one short operational instruction.
- If the image does not clearly show produce, say that produce cannot be confidently assessed from this image.
- Do not use markdown.
- Do not invent exact percentages.
- Keep `summary` under 80 words.
""".strip()


def generate_call_message(request: CallBobRequest) -> str:
    prompt = f"""
Write a short spoken phone alert for Bob about a produce inspection.

Inspection summary: {request.summary}
Freshness: {request.freshness}
Damage: {request.damage}
Status: {request.status}

Rules:
- Keep it under 45 words.
- Be calm, specific, and action-oriented.
- Mention that this is an automated field inspection alert.
- Do not use markdown.
""".strip()

    try:
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=[prompt],
        )
    except Exception:
        return fallback_call_message(request)

    message = (response.text or "").strip()
    return message or fallback_call_message(request)


def fallback_call_message(request: CallBobRequest) -> str:
    return (
        "Automated field inspection alert. "
        f"Produce status is {request.status}. "
        f"Freshness is {request.freshness} and damage is {request.damage}. "
        "Please review the latest inspection result."
    )
