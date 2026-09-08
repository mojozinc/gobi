# ADR 0003: Server-Backed OpenRouter AI Architecture and Family Health Hub Specification

- **Status:** Accepted
- **Date:** 2026-09-08
- **Authors:** Gobi Core Architecture Team

---

## 1. Context and Problem Statement

The initial prototype attempted to leverage Android's native Gemini / Google Assistant App Actions (`shortcuts.xml`) and a pure local-first zero-backend model. However:
1. **Google Assistant / Gemini App Actions Limitations:** Sideloaded debug builds and unpublished apps cannot be resolved by Google's cloud voice assistant without active 24-hour test tool previews or Google Play Store indexing. Furthermore, system-level Gemini cannot provide deep domain-specific health intelligence, prescription OCR, or multi-family member care coordination.
2. **Product Evolution:** Gobi is evolving from a single-device medication logger into a **Family Health & Caregiving Hub** managing multiple dependent profiles (self, elderly parents, children), prescription multimodal scanning, vitals tracking, and proactive family alerts.

We need a robust, scalable architecture that provides superior natural language voice understanding, multimodal prescription OCR, reliable backend data persistence, and human-in-the-loop safeguards.

---

## 2. Decision Summary

We adopt a **Server-Backed Agentic Architecture** powered by **FastAPI, PostgreSQL, and OpenRouter.ai**:

1. **AI Processing Layer:** All LLM reasoning and multimodal vision tasks are orchestrated server-side in `backend-api` via **OpenRouter.ai** (`https://openrouter.ai/api/v1/chat/completions`) using structured JSON Schema tool calling.
   - **Prototyping Phase Cost Optimization:** The system defaults to **100% Free OpenRouter Models** (`:free` endpoints), such as:
     - **Voice Intent & Tool Calling:** `meta-llama/llama-3.3-70b-instruct:free` / `google/gemini-2.0-flash-exp:free` / `meta-llama/llama-3.1-8b-instruct:free`.
     - **Prescription & Document Vision OCR:** `google/gemini-2.0-flash-exp:free` / `meta-llama/llama-3.2-11b-vision-instruct:free`.
   - The model selection is fully parameterized via environment variables (`OPENROUTER_TEXT_MODEL` and `OPENROUTER_VISION_MODEL`) so production models can be switched seamlessly later.
2. **Mobile Interaction:** The Flutter mobile app adopts a **Dashboard-First model with Contextual AI buttons** (*Voice Log* and *Scan Prescription*).
3. **Voice Pipeline:** Hybrid execution—native device Speech-to-Text (`speech_to_text`) transcribes audio on the device, sending the text to `POST /api/v1/ai/parse-intent` on the backend for tool extraction.
4. **Prescription OCR Pipeline:** Device camera/gallery captures prescription photos, sending multipart uploads to `POST /api/v1/ai/scan-prescription` on the backend, where OpenRouter Multimodal Vision (Gemini 1.5 Flash) extracts medications, dosages, frequency, and instructions.
5. **Human-in-the-Loop Safeguards (Adaptive Confirmation):**
   - **New Schedules & OCR Scans:** Displayed in an **Interactive Review Bottom Sheet** for user editing and confirmation before committing.
   - **Simple Dose Logging:** Executed immediately with a 5-second **Undo Snackbar**.

---

## 3. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           FLUTTER MOBILE APP                            │
│  - Dashboard (Today / All Schedules / Vitals / Documents / Family)      │
│  - Contextual AI: Native STT Voice Log + Camera Prescription Picker     │
│  - Adaptive UI: Review Bottom Sheet + Instant Undo Snackbar             │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │
                     HTTPS REST API  │ (Bearer Auth + Multipart)
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         FASTAPI BACKEND API                             │
│  - Auth & Family Permissions Management                                 │
│  - Endpoints: /api/v1/ai/parse-intent, /api/v1/ai/scan-prescription    │
│  - OpenRouter Service (Structured Tool Calling & Multimodal Vision)     │
└───────────────────┬─────────────────────────────────┬───────────────────┘
                    │                                 │
                    ▼                                 ▼
      ┌───────────────────────────┐     ┌───────────────────────────┐
      │      PostgreSQL DB        │     │      OpenRouter.ai        │
      │  - users, dependents      │     │  - google/gemini-flash-1.5│
      │  - medications, dose_logs │     │  - meta-llama/llama-3.1   │
      │  - vitals, documents      │     │  - structured JSON schema │
      └───────────────────────────┘     └───────────────────────────┘
```

---

## 4. Milestone 1 Implementation Plan

1. **Backend (`backend-api`):**
   - Create `OpenRouterService` with tool-calling schemas for `set_schedule`, `get_schedule`, and `record_dose`.
   - Implement `POST /api/v1/ai/parse-intent` endpoint.
   - Implement `POST /api/v1/ai/scan-prescription` multimodal endpoint.
2. **Mobile (`gobi-mobile`):**
   - Integrate `speech_to_text` and camera/image picker.
   - Build the **Review Bottom Sheet** for reviewing AI-parsed schedules and OCR results.
   - Connect in-app voice logging and prescription scanning to the backend API.
   - Add instant dose logging with Undo feedback.
