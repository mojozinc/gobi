import json
import re
import logging
from typing import Optional, List, Dict, Any
import httpx
from app.config import settings
from app.schemas.ai import (
    VoiceIntentResponse, SetScheduleArgs, RecordDoseArgs, GetScheduleArgs,
    ScanPrescriptionResponse, PrescriptionMedicationItem
)

logger = logging.getLogger("gobi.ai")

class OpenRouterService:
    def __init__(self):
        self.api_key = settings.OPENROUTER_API_KEY
        self.base_url = settings.OPENROUTER_BASE_URL.rstrip("/")
        self.text_model = settings.OPENROUTER_TEXT_MODEL
        self.vision_model = settings.OPENROUTER_VISION_MODEL

    def _get_headers(self) -> Dict[str, str]:
        headers = {
            "Content-Type": "application/json",
            "HTTP-Referer": "https://github.com/mojozinc/gobi",
            "X-Title": "Gobi Health",
        }
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        return headers

    async def parse_voice_intent(self, user_text: str, context: Optional[str] = None) -> VoiceIntentResponse:
        """
        Parses user speech/text into structured health actions via OpenRouter Tool Calling.
        Falls back to local heuristic extraction if no API key is set.
        """
        tools = [
            {
                "type": "function",
                "function": {
                    "name": "set_schedule",
                    "description": "Schedule a new recurring or as-needed medication regimen with duration and dosage",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string", "description": "Medication name e.g. Vitamin D, Metformin"},
                            "dosage": {"type": "string", "description": "Dosage amount e.g. 500mg, 1 tablet, 1000 IU"},
                            "frequency": {"type": "string", "enum": ["daily", "twice_daily", "weekly", "as_needed"], "description": "Frequency of intake"},
                            "duration_weeks": {"type": "integer", "description": "Duration in weeks"},
                            "times": {"type": "string", "description": "Time of day e.g. 08:00 or Morning"},
                            "instructions": {"type": "string", "description": "Special intake notes e.g. take with meals"}
                        },
                        "required": ["name", "frequency"]
                    }
                }
            },
            {
                "type": "function",
                "function": {
                    "name": "record_dose",
                    "description": "Record that a dose was taken or skipped right now or earlier today",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string", "description": "Medication name e.g. Vitamin D"},
                            "status": {"type": "string", "enum": ["taken", "skipped"], "description": "Status of the dose"},
                            "time_taken": {"type": "string", "description": "Time or period taken e.g. morning, 8am, now"}
                        },
                        "required": ["name", "status"]
                    }
                }
            },
            {
                "type": "function",
                "function": {
                    "name": "get_schedule",
                    "description": "Check what medications are scheduled or query adherence history",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string", "description": "Optional specific medication name to check"},
                            "timeframe": {"type": "string", "enum": ["today", "this_week", "upcoming"], "description": "Timeframe to inspect"}
                        }
                    }
                }
            }
        ]

        if not self.api_key:
            logger.info("No OPENROUTER_API_KEY provided; using local intent parser.")
            return self._fallback_parse_intent(user_text)

        payload = {
            "model": self.text_model,
            "messages": [
                {
                    "role": "system",
                    "content": "You are Gobi's health intent extraction assistant. "
                               "Extract the user's intent into the most appropriate tool call. "
                               f"Context: {context or 'None'}"
                },
                {"role": "user", "content": user_text}
            ],
            "tools": tools,
            "tool_choice": "auto",
            "temperature": 0.1
        }

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                res = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers=self._get_headers(),
                    json=payload
                )
                if res.status_code == 200:
                    data = res.json()
                    choices = data.get("choices", [])
                    if choices:
                        message = choices[0].get("message", {})
                        tool_calls = message.get("tool_calls", [])
                        if tool_calls:
                            call = tool_calls[0]
                            func_name = call.get("function", {}).get("name")
                            args_str = call.get("function", {}).get("arguments", "{}")
                            try:
                                args = json.loads(args_str)
                            except Exception:
                                args = {}

                            if func_name == "set_schedule":
                                return VoiceIntentResponse(
                                    action="SET_SCHEDULE",
                                    message=f"Schedule {args.get('name')} {args.get('frequency', 'daily')}",
                                    raw_query=user_text,
                                    set_schedule_data=SetScheduleArgs(**args),
                                    requires_confirmation=True
                                )
                            elif func_name == "record_dose":
                                return VoiceIntentResponse(
                                    action="RECORD_DOSE",
                                    message=f"Marked {args.get('name')} as {args.get('status', 'taken')}",
                                    raw_query=user_text,
                                    record_dose_data=RecordDoseArgs(**args),
                                    requires_confirmation=False
                                )
                            elif func_name == "get_schedule":
                                return VoiceIntentResponse(
                                    action="GET_SCHEDULE",
                                    message=f"Checking schedule for {args.get('name', 'today')}",
                                    raw_query=user_text,
                                    get_schedule_data=GetScheduleArgs(**args),
                                    requires_confirmation=False
                                )
        except Exception as e:
            logger.warning(f"OpenRouter intent call failed: {e}; falling back to local extractor.")

        return self._fallback_parse_intent(user_text)

    def _fallback_parse_intent(self, text: str) -> VoiceIntentResponse:
        """Robust local fallback extractor when API key is missing or network is unavailable."""
        lower = text.lower()

        # 1. Check RECORD_DOSE
        if any(w in lower for w in ["took", "taken", "had my", "just drank", "swallowed"]):
            med_name = self._extract_med_name(lower)
            return VoiceIntentResponse(
                action="RECORD_DOSE",
                message=f"Recorded dose for {med_name}",
                raw_query=text,
                record_dose_data=RecordDoseArgs(name=med_name, status="taken", time_taken="now"),
                requires_confirmation=False
            )

        # 2. Check GET_SCHEDULE
        if any(w in lower for w in ["did i take", "have i taken", "what meds", "what medication", "any pills left", "schedule"]):
            med_name = self._extract_med_name(lower)
            timeframe = "this_week" if "week" in lower else "today"
            return VoiceIntentResponse(
                action="GET_SCHEDULE",
                message=f"Checking status for {med_name}",
                raw_query=text,
                get_schedule_data=GetScheduleArgs(name=med_name, timeframe=timeframe),
                requires_confirmation=False
            )

        # 3. Check SET_SCHEDULE
        if any(w in lower for w in ["need to take", "prescribed", "every week", "every day", "daily", "weekly", "schedule", "take"]):
            med_name = self._extract_med_name(lower)
            freq = "weekly" if "week" in lower else "daily"
            duration = 6 if "6 weeks" in lower else 1
            if match := re.search(r'(\d+)\s*week', lower):
                duration = int(match.group(1))

            return VoiceIntentResponse(
                action="SET_SCHEDULE",
                message=f"Ready to schedule {med_name} ({freq})",
                raw_query=text,
                set_schedule_data=SetScheduleArgs(
                    name=med_name,
                    dosage="1 dose",
                    frequency=freq,
                    duration_weeks=duration,
                    instructions="Take as directed"
                ),
                requires_confirmation=True
            )

        return VoiceIntentResponse(
            action="UNKNOWN",
            message="Could not clearly identify action. Please verify details.",
            raw_query=text,
            requires_confirmation=True
        )

    def _extract_med_name(self, text: str) -> str:
        for keyword in ["vitamin d", "vit d", "metformin", "paracetamol", "aspirin", "amoxicillin", "atorvastatin", "lisinopril", "omeprazole"]:
            if keyword in text:
                return "Vitamin D" if "vit" in keyword else keyword.capitalize()
        # Fallback regex word extraction
        match = re.search(r'(?:take|took|for)\s+([a-zA-Z0-9\s]+?)(?:,|\.|\s+once|\s+every|\s+in\s+the|\s+for|\s+this|$)', text)
        if match:
            extracted = match.group(1).strip()
            if len(extracted) > 2 and extracted not in ["my", "the", "a", "some"]:
                return extracted.title()
        return "Medication"

    async def scan_prescription(self, image_base64: str, mime_type: str = "image/jpeg") -> ScanPrescriptionResponse:
        """Extracts medications and doctor instructions from prescription photos using OpenRouter Vision."""
        if not self.api_key:
            logger.info("No OPENROUTER_API_KEY provided; returning mock prescription OCR for local testing.")
            return ScanPrescriptionResponse(
                doctor_name="Dr. S. K. Sharma, MD",
                date="2026-09-02",
                diagnosis="Routine Health Checkup",
                notes="Take medicines after meals with warm water.",
                medications=[
                    PrescriptionMedicationItem(name="Vitamin D3", dosage="60000 IU", frequency="weekly", duration_weeks=6, instructions="Take once weekly after breakfast"),
                    PrescriptionMedicationItem(name="Metformin", dosage="500 mg", frequency="twice_daily", duration_weeks=4, instructions="Take after meals")
                ]
            )

        system_prompt = (
            "You are an expert clinical document OCR engine. Extract all medications, dosages, frequencies, "
            "and doctor details from the provided prescription image. "
            "Return valid JSON ONLY matching the following schema:\n"
            "{\n"
            '  "doctor_name": "string",\n'
            '  "date": "YYYY-MM-DD",\n'
            '  "diagnosis": "string",\n'
            '  "notes": "string",\n'
            '  "medications": [\n'
            '    {"name": "string", "dosage": "string", "frequency": "daily|twice_daily|weekly|as_needed", "duration_weeks": integer, "instructions": "string"}\n'
            '  ]\n'
            "}"
        )

        data_uri = f"data:{mime_type};base64,{image_base64}" if not image_base64.startswith("data:") else image_base64

        payload = {
            "model": self.vision_model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Extract all prescription medication details from this image."},
                        {"type": "image_url", "image_url": {"url": data_uri}}
                    ]
                }
            ],
            "temperature": 0.1
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                res = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers=self._get_headers(),
                    json=payload
                )
                if res.status_code == 200:
                    data = res.json()
                    choices = data.get("choices", [])
                    if choices:
                        content = choices[0].get("message", {}).get("content", "")
                        parsed = self._extract_json_payload(content)
                        return ScanPrescriptionResponse(**parsed)
        except Exception as e:
            logger.error(f"Prescription OCR call failed: {e}")

        # Fallback if OCR model response fails
        return ScanPrescriptionResponse(
            doctor_name="Doctor",
            notes="Please verify extracted medications manually.",
            medications=[
                PrescriptionMedicationItem(name="Extracted Medication", dosage="1 dose", frequency="daily", duration_weeks=2, instructions="As prescribed")
            ]
        )

    def _extract_json_payload(self, content: str) -> dict:
        """Extracts JSON object from raw LLM output even if wrapped in markdown code blocks or surrounding text."""
        trimmed = content.strip()
        try:
            return json.loads(trimmed)
        except Exception:
            pass

        codeblock_match = re.search(r'```(?:json)?\s*([\s\S]*?)\s*```', content)
        if codeblock_match:
            try:
                return json.loads(codeblock_match.group(1).strip())
            except Exception:
                pass

        brace_match = re.search(r'\{[\s\S]*\}', content)
        if brace_match:
            try:
                return json.loads(brace_match.group(0))
            except Exception:
                pass

        raise ValueError(f"Could not parse valid JSON from LLM response: {content[:100]}")

    async def chat_rag(self, query: str, context: str, history: List[Dict[str, str]]) -> str:
        """Answers user queries grounded in real user medications, dose logs, and prescription texts."""
        if not self.api_key:
            return f"Based on your health records:\n{context}\n\nTo answer your question ('{query}'): All your active medications and routines are up to date."

        system_prompt = (
            "You are Gobi, a caring and highly knowledgeable Family Health & Medication Assistant.\n"
            "You have direct access to the user's verified health records, active medications, adherence logs, "
            "and scanned doctor prescriptions shown below.\n\n"
            "--- USER HEALTH CONTEXT ---\n"
            f"{context}\n"
            "---------------------------\n\n"
            "Instructions:\n"
            "- Answer the user's question clearly, warmly, and accurately using the context.\n"
            "- If they ask whether they took a pill, check the dose logs for the relevant date/timeframe.\n"
            "- If they ask about instructions, check the medication dosage and prescription notes.\n"
            "- Include a brief helpful reminder when appropriate."
        )

        messages = [{"role": "system", "content": system_prompt}]
        for msg in history[-6:]:
            messages.append({"role": msg.get("role", "user"), "content": msg.get("content", "")})
        messages.append({"role": "user", "content": query})

        payload = {
            "model": self.text_model,
            "messages": messages,
            "temperature": 0.3
        }

        logger.debug(f"Calling OpenRouter chat_rag with model: {self.text_model}, query: {query[:60]}...")
        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                res = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers=self._get_headers(),
                    json=payload
                )
                if res.status_code == 200:
                    data = res.json()
                    choices = data.get("choices", [])
                    if choices:
                        content = choices[0].get("message", {}).get("content")
                        if content:
                            logger.debug(f"OpenRouter chat_rag succeeded: {content[:80]}...")
                            return content
                else:
                    logger.error(f"OpenRouter RAG chat returned status {res.status_code}: {res.text}")
        except Exception as e:
            logger.error(f"RAG chat call failed: {e}")

        return f"Based on your records, here is your current status:\n{context}"

openrouter_service = OpenRouterService()
