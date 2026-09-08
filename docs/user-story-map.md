# Gobi: Master User Story Map (Backbone & Ribs)

> **Framework:** User Story Mapping (Jeff Patton) & Human-Centered Design (Don Norman)  
> **Product Identity:** Family Medication & Health Hub (Prescription OCR, voice-assisted adherence, and RAG-powered health chat)  
> **Status:** Active Master Map  
> **Last Updated:** 2026-09-08

---

## 1. Personas & Core User Journey

```
┌──────────────────────────────┐  ┌──────────────────────────────┐
│  Alex (Caregiver / User)     │  │  Maria (Elderly Parent)      │
│  - Manages family meds & Rx  │  │  - Speaks doses into app     │
│  - Scans paper prescriptions │  │  - Needs clear Today view    │
│  - Chats with AI over history│  │  - Forgiving, simple inputs  │
└──────────────────────────────┘  └──────────────────────────────┘
```

---

## 2. The Streamlined 5-Step Story Map Matrix

```
┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   THE HORIZONTAL BACKBONE (User Journey Across Time)                                  │
├───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────────────────────────────┤
│ 1. Onboarding &   │ 2. Set Up         │ 3. Daily Dose     │ 4. Scan Rx &      │ 5. Raw Health Chat &                  │
│    Family Profiles│    Medications    │    Adherence      │    Documents      │    History (RAG)                      │
├───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────────────────────────────┤
│                                                  THE VERTICAL RIBS (Release Slices)                                   │
├───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ 🦴 SLICE 1: WALKING SKELETON / MVP (Current Scope)                                                                    │
├───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────────────────────────────┤
│ • Basic Auth      │ • Manual Schedule │ • Today's Doses   │ • Camera Rx photo │ • Raw Chat Screen                     │
│ • Single profile  │   entry           │   Dashboard       │   upload          │ • RAG over SQLite/Postgres data:      │
│ • Token storage   │ • In-App Voice    │ • Voice Log Dose  │ • OpenRouter      │   Inject active schedules & dose logs │
│                   │   Schedule        │   ("took pill")   │   Vision OCR      │ • OpenRouter free tier chat           │
│                   │ • Review Bottom   │ • 5-sec Undo Toast│ • Rx Review Sheet │ • Q&A: "When did I last take vit d?"  │
│                   │   Sheet           │                   │                   │                                       │
├───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────────────────────────────┤
│ 🦴 SLICE 2: FAMILY PROFILES & DOCUMENT ARCHIVE                                                                        │
├───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────────────────────────────┤
│ • Dependent family│ • Assign schedules│ • Filter today's  │ • Multi-page PDF  │ • Multi-profile RAG chat:             │
│   profiles        │   by dependent    │   doses by member │   document upload │   "What medications is mom taking?"   │
│ • Profile switcher│ • Pill inventory  │ • Skip dose with  │ • Prescription &  │ • Full prescription document text     │
│   avatar bar      │   depletion alert │   custom reason   │   lab doc archive │   indexing in RAG context             │
├───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────────────────────────────┤
│ 🦴 SLICE 3: ADVANCED RAG & VECTOR SEARCH                                                                              │
├───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────────────────────────────┤
│ • Role-based      │ • Drug-to-drug    │ • Offline speech  │ • Lab report text │ • Semantic Vector Search (pgvector)   │
│   family sharing  │   interaction     │   buffering &     │   extraction &    │ • Multi-turn conversational memory    │
│   permissions     │   warnings        │   auto-sync       │   indexing        │ • Clinical summary export             │
└───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────────────────────────────┘
```

---

## 3. Backbone Step Details

### Step 1: Onboarding & Family Profile Setup
- **User Goal:** Set up Gobi, secure data, and switch between family members (Self, Mom, Dad, Child).
- **Enablers:**
  - `POST /api/v1/auth/login`, `POST /api/v1/auth/register`
  - `POST /api/v1/dependents` (CRUD for family members).

---

### Step 2: Set Up Medications & Routines
- **User Goal:** Create schedules with recurring intervals via manual form or voice speech.
- **Affordance:** Floating `+ Set Schedule` button and Mic voice scheduling (*"Take Metformin 500mg twice daily for 30 days"*).
- **Safeguard:** **Interactive Review Bottom Sheet** to verify and edit before saving.
- **Enablers:**
  - `POST /api/v1/ai/parse-intent` via OpenRouter (tool: `set_schedule`).
  - Database: `medications` & `dose_logs` tables.

---

### Step 3: Daily Dose Adherence & Logging
- **User Goal:** View today's schedule, log taken doses in 1 tap or voice, with instant feedback.
- **Affordance:** Big checkmarks, `Take Dose` action buttons, voice logging (*"I just took my morning pill"*), and 5-second **Undo Snackbar**.
- **Enablers:**
  - `POST /api/v1/doses/{id}/take`, `POST /api/v1/doses/{id}/undo`.

---

### Step 4: Scan Prescriptions & Documents (Multimodal OCR)
- **User Goal:** Take a photo of a prescription or upload a PDF to automatically extract medication names, dosages, and instructions.
- **Affordance:** Camera viewfinder $\rightarrow$ OpenRouter Vision OCR $\rightarrow$ **Review Bottom Sheet** showing parsed items with confirmation checkboxes.
- **Enablers:**
  - `POST /api/v1/ai/scan-prescription` via OpenRouter Vision (`google/gemini-2.0-flash-exp:free` or `meta-llama/llama-3.2-11b-vision-instruct:free`).

---

### Step 5: Raw Health Chat & History with RAG
- **User Goal:** Chat naturally with an AI assistant that has complete context over all your saved data (current schedules, adherence history, prescription text, doctor instructions).
- **Affordance:** Chat tab / Floating assistant view where the user can ask questions like:
  - *"Did I take my Vitamin D this week?"*
  - *"What are the instructions on the prescription I scanned last month?"*
  - *"Summarize my medication routine for my doctor appointment."*
- **RAG Architecture:**
  - Injects user profile, active medications, recent dose logs, and indexed document OCR texts directly into the prompt context / vector retrieval layer.
  - Queries OpenRouter free-tier LLM for rich, context-grounded conversational answers.

---

## 4. Slice 1 (Walking Skeleton) Task Packages

| Task ID | Component | Feature |
|---|---|---|
| **S1-BE-01** | Backend | OpenRouter client with free-tier model configuration (`:free`) |
| **S1-BE-02** | Backend | `POST /api/v1/ai/parse-intent` for voice scheduling and dose logging |
| **S1-BE-03** | Backend | `POST /api/v1/ai/scan-prescription` for multimodal vision OCR |
| **S1-BE-04** | Backend | `POST /api/v1/ai/chat` (RAG chat endpoint querying user's meds, dose logs & doc OCR) |
| **S1-FE-01** | Mobile | In-app STT voice input button & modal |
| **S1-FE-02** | Mobile | Camera/Gallery prescription photo picker |
| **S1-FE-03** | Mobile | **Interactive Review Bottom Sheet** for schedule/OCR validation |
| **S1-FE-04** | Mobile | Instant dose logging with 5-second **Undo Snackbar** |
| **S1-FE-05** | Mobile | Dedicated **Health Chat Tab** (RAG assistant) |
