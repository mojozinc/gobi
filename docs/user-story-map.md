# Gobi: Master User Story Map (Backbone & Ribs)

> **Framework:** User Story Mapping (Jeff Patton) & Human-Centered Design (Don Norman)  
> **Product Identity:** Family Health & Caregiving Hub (Multi-profile medication adherence, prescription OCR, vitals tracking, and caregiver coordination)  
> **Status:** Active Master Map  
> **Last Updated:** 2026-09-08

---

## 1. Personas & Mental Models

```
┌──────────────────────────────┐  ┌──────────────────────────────┐  ┌──────────────────────────────┐
│  Alex (Primary Caregiver)    │  │  Maria (Aging Parent)        │  │  Dr. Rao (Doctor / Clinician)│
│  - Working adult with family │  │  - Prefers simple voice      │  │  - Needs concise adherence   │
│  - Coordinates parent's meds │  │  - Large font & clear cards  │  │    history & vitals trends   │
│  - Needs peace of mind       │  │  - Doesn't like typing       │  │  - Requires PDF export       │
└──────────────────────────────┘  └──────────────────────────────┘  └──────────────────────────────┘
```

---

## 2. The 2D Story Map Matrix

```
┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                      THE HORIZONTAL BACKBONE (User Journey Across Time)                                │
├───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────┤
│ 1. Onboarding &   │ 2. Set Up         │ 3. Daily Dose     │ 4. Scan Rx &      │ 5. Track Vitals & │ 6. Caregiver      │ 7. Health Q&A │
│    Family Profile │    Medications    │    Adherence      │    Documents      │    Biomarkers     │    Escalation     │    & Reports  │
├───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────┤
│                                                      THE VERTICAL RIBS (Release Slices)                                               │
├───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ SLICE 1: WALKING SKELETON / MVP (Current Focus)                                                                                       │
├───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────┤
│ • Phone/Email Auth│ • Create Schedule │ • Today's Doses   │ • Camera Rx photo │ • Manual BP &     │ • Single-user     │ • Basic status│
│ • Single profile  │   (manual entry)  │   Dashboard       │   upload          │   Glucose entry   │   in-app activity │   queries     │
│ • Token storage   │ • Voice Schedule  │ • Voice Log Dose  │ • OpenRouter      │ • Simple Vitals   │   feed            │   ("What meds │
│                   │   (OpenRouter)    │   ("took pill")   │   Vision OCR      │   history list    │                   │   are left?") │
│                   │ • Schedule review │ • 5-sec Undo      │ • Rx Review       │                   │                   │               │
│                   │   bottom sheet    │   Snackbar        │   Bottom Sheet    │                   │                   │               │
├───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────┤
│ SLICE 2: FAMILY CARE & MULTI-PROFILE                                                                                                  │
├───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────┤
│ • Add Dependent   │ • Assign meds to  │ • Filter doses by │ • Tag documents   │ • Filter vitals   │ • Real-time push  │ • "Did mom    │
│   profiles        │   family member   │   family member   │   by family member│   by member       │   notification on │   take her    │
│ • Switch profile  │ • Pill inventory  │ • Mark as skipped │ • Document archive│ • Normal vs       │   missed dose     │   pills?"     │
│   switcher        │   depletion alert │   with reason     │   with PDF viewer │   abnormal tags   │ • Caregiver alert │   queries     │
├───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────┤
│ SLICE 3: ADVANCED CLINICAL & BIOMARKER TRENDS                                                                                         │
├───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────────┬───────────────┤
│ • Invite family   │ • Drug-to-drug    │ • Offline speech  │ • Lab report PDF  │ • Interactive BP/ │ • Multi-caregiver │ • Doctor visit│
│   caregivers with │   interaction     │   buffering &     │   biomarker value │   Glucose trend   │   escalation tier │   PDF export  │
│   RBAC permissions│   warnings        │   auto-sync       │   extraction      │   charts          │   (SMS/WhatsApp)  │   generator   │
└───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────────┴───────────────┘
```

---

## 3. Deep-Dive: Backbone Step Specifications

### Step 1: Onboarding & Family Profile Setup
- **User Goal:** Set up Gobi, secure health data, and establish family members/dependents.
- **Affordances & Signifiers:**
  - Clear authentication screen with phone OTP / token auth.
  - Avatar chips for switching between *Self*, *Mom*, *Dad*, *Child*.
- **Technical Enablers:**
  - `POST /api/v1/auth/login`, `POST /api/v1/auth/register`
  - `POST /api/v1/dependents` (CRUD for family members).

---

### Step 2: Set Up Medications & Routines
- **User Goal:** Add recurring or as-needed medication schedules quickly without friction.
- **Affordances & Signifiers:**
  - Floating `+ Set Schedule` button on Medications screen.
  - Mic button for voice scheduling (*"Take Vitamin D 1000 IU once every Sunday for 6 weeks"*).
  - **Interactive Review Bottom Sheet:** Shows extracted medication name, dosage, frequency, and start date with editable fields before saving.
- **Technical Enablers:**
  - Backend: `POST /api/v1/ai/parse-intent` via OpenRouter (`google/gemini-2.0-flash-exp:free` or `meta-llama/llama-3.3-70b-instruct:free`).
  - Database: `medications` & `dose_logs` tables with recurring interval generators.

---

### Step 3: Daily Dose Adherence & Logging
- **User Goal:** Check what pills are due right now, log doses in 1 second, and receive feedback.
- **Affordances & Signifiers:**
  - **Today / Due Tab:** Card list with big friendly green checkmarks for `TAKEN` and green `Take Dose` action buttons for `PENDING`.
  - **Voice Action:** Tapping mic and saying *"I just took my morning blood pressure pill"*.
  - **Adaptive Confirmation:** Instant execution with 5-second **Undo Snackbar** (matches Norman's Principle of Forgiving Design).
- **Technical Enablers:**
  - `POST /api/v1/doses/{id}/take`, `POST /api/v1/doses/{id}/undo`
  - Real-time reactive state updates across UI tabs.

---

### Step 4: Prescription & Health Document Hub
- **User Goal:** Take a photo of a doctor's handwritten/printed prescription and have Gobi automatically extract medications into schedules.
- **Affordances & Signifiers:**
  - `Scan Prescription` camera button with viewfinder overlay.
  - Upload progress indicator $\rightarrow$ **Review Bottom Sheet** displaying extracted medications, dosage, and doctor notes with confirmation checkboxes.
- **Technical Enablers:**
  - Multipart upload to `POST /api/v1/ai/scan-prescription`.
  - Backend OpenRouter Vision processing (`google/gemini-2.0-flash-exp:free` / `meta-llama/llama-3.2-11b-vision-instruct:free`).
  - Document storage in S3/MinIO/local storage.

---

### Step 5: Vitals & Biomarker Tracking
- **User Goal:** Record daily vitals (Blood Pressure, Blood Glucose, Weight, SpO2) effortlessly and visualize trends.
- **Affordances & Signifiers:**
  - Quick-entry cards on the Home dashboard.
  - Voice entry (*"Log blood pressure 125 over 80"*).
  - Color-coded indicator tags (Normal: Green, Elevated: Yellow, High: Red).
- **Technical Enablers:**
  - `POST /api/v1/vitals` (type, value, unit, measured_at, dependent_id).
  - Trend aggregation endpoints (`GET /api/v1/vitals/trends`).

---

### Step 6: Caregiver Monitoring & Escalation
- **User Goal:** Keep family members informed when an elderly parent misses a critical dose or logs abnormal vitals.
- **Affordances & Signifiers:**
  - Activity feed on Caregiver dashboard.
  - Missed dose push notification to caregiver after a 60-minute grace window.
  - Emergency contact quick-dial button.
- **Technical Enablers:**
  - Background scheduler (cron/Celery) detecting overdue doses.
  - Push notification gateway / WebSocket alerts.

---

### Step 7: Conversational Health Q&A & Doctor Reports
- **User Goal:** Ask conversational questions over family health history and generate clinical export PDFs for doctor appointments.
- **Affordances & Signifiers:**
  - Natural language Q&A (*"Did dad take all his meds this week?"*, *"What was mom's average fasting sugar last month?"*).
  - One-tap `Export Doctor Summary (PDF)` button.
- **Technical Enablers:**
  - RAG query over user's historical `dose_logs`, `vitals`, and `documents`.
  - PDF generator template.

---

## 4. Current Execution Focus: Slice 1 (Walking Skeleton)

| Task ID | Component | Description | Status |
|---|---|---|---|
| **S1-BE-01** | Backend | OpenRouter client service with free-tier model support & structured JSON schemas | ⏳ Ready to build |
| **S1-BE-02** | Backend | `POST /api/v1/ai/parse-intent` for voice scheduling & dose logging | ⏳ Ready to build |
| **S1-BE-03** | Backend | `POST /api/v1/ai/scan-prescription` for multimodal image OCR | ⏳ Ready to build |
| **S1-FE-01** | Mobile | In-app Speech-to-Text (`speech_to_text`) voice input modal & mic button | ⏳ Ready to build |
| **S1-FE-02** | Mobile | Camera/Gallery prescription picker | ⏳ Ready to build |
| **S1-FE-03** | Mobile | **Interactive Review Bottom Sheet** for schedule & OCR confirmation | ⏳ Ready to build |
| **S1-FE-04** | Mobile | Instant dose logging with 5-second Undo Snackbar | ⏳ Ready to build |
