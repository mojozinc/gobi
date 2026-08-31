# ADR 0002: Specification for Sovereign Local-First Architecture, CDC Replication, and Android System AI

- **Status:** Accepted
- **Date:** 2026-08-31
- **Author:** Team Gobi

---

## Problem Statement

Users managing health, prescriptions, and medical histories for themselves and their families face significant privacy, reliability, and usability barriers with traditional health tech platforms:
1. **Privacy Liability & Data Monetization:** Existing cloud medical platforms centralize sensitive patient records, exposing users to third-party data broker profiling, insurance risk inflation, and data breaches.
2. **Online Dependency & Fragility:** Medical records, dosage schedules, and medication alerts become inaccessible when network connectivity fails (e.g. during hospital visits, traveling, or outages).
3. **App Bloat & AI Friction:** In-app AI assistants typically require bloated multi-gigabyte models or expensive, privacy-compromising cloud LLM endpoints with high latency, rather than leveraging the capable AI already built into the user's mobile operating system (e.g. Android Gemini / Google Assistant).
4. **Backend Heavy Maintenance:** Complex centralized backends introduce high maintenance overhead and server operational costs for what is fundamentally a personal and familial management tool.

---

## Solution

A **Sovereign Local-First Medical Assistant** built on Flutter and an embedded SQLite/Drift database engine, where:
1. **100% On-Device Single Source of Truth:** All medical records, prescriptions, dose logs, family member profiles, and vitals reside on-device in a relational SQLite store. The app functions with complete feature parity completely offline.
2. **Append-Only Change Data Capture (CDC):** Local mutations trigger append-only journal entries with Hybrid Logical Clock (HLC) timestamps, enabling deterministic Last-Write-Wins (LWW) field convergence across multiple family devices.
3. **OS-Level System AI Integration:** Instead of bundling heavy local models or streaming health data to cloud LLM APIs, Gobi integrates natively with the host OS's built-in AI (Android Gemini / Google Assistant) via Android App Actions, Dynamic Shortcuts, and Custom Intents to execute voice commands locally.
4. **On-Device OCR & Entity Parsing:** Physical prescriptions and lab reports are scanned and parsed directly on-device using Google ML Kit and deterministic regex/heuristic extractors in under 300ms with zero network traffic.
5. **Dumb Catch-All Backend:** An optional, blind End-to-End Encrypted (E2EE) event relay and encrypted blob storage bucket that requires zero plaintext knowledge of user records and can be completely eliminated or self-hosted without impacting the app's functionality.

---

## User Stories

### A. Local-First Medication & Routine Management
1. As a household caregiver, I want all my family's medication schedules to load instantly and reliably offline, so that I can administer medications on time regardless of network availability.
2. As a patient, I want to log my dose as "taken", "skipped", or "pending" with a single tap, so that my adherence history is accurately captured.
3. As a caregiver, I want automatic inventory deduction when doses are logged and alerts when remaining counts breach a refill threshold, so that my dependents never run out of vital medications.
4. As a health-conscious individual, I want to configure flexible dosage schedules (daily, multiple times a day, as-needed/PRN, weekly), so that complex medication regimens are clearly represented.
5. As a user, I want local push notifications scheduled strictly on-device, so that alarms ring even if the device is in airplane mode.

### B. System AI (Android Gemini & Assistant) Voice Interface
6. As a busy caregiver, I want to say *"Hey Gemini, log that I took my morning Metformin in Gobi"*, so that my dose is logged hands-free without opening and navigating the app.
7. As a patient, I want to ask *"Hey Gemini, what medications do I have left today in Gobi?"*, so that I get an immediate summary of my upcoming daily schedule via voice/overlay.
8. As a user, I want voice commands to execute locally via deep links and Android App Actions, so that my private health queries are never routed through third-party cloud LLM APIs.
9. As a user, I want app shortcuts displayed on my Android home screen and Assistant suggestions, so that I can quickly jump to prescription scanning or emergency medical summaries.

### C. Sovereign Document Archival & On-Device OCR
10. As a patient, I want to take a picture of a physical paper prescription and have drug names, dosages, and frequencies extracted automatically on my phone, so that I don't have to type long medical names manually.
11. As a privacy-conscious user, I want prescription OCR to run 100% locally via on-device ML Kit, so that photos of my medical records never leave my phone without my explicit consent.
12. As a user, I want to review and correct any extracted prescription fields before saving to my local database, so that errors in handwriting or scanning are caught.

### D. CDC Multi-Device Synchronization & Data Sovereignty
13. As a family managing shared care for an elderly parent, I want medication logs taken on my phone to replicate to my sibling's device, so that we avoid duplicate dosing.
14. As a user with multiple devices, I want offline edits made on my tablet to reconcile deterministically with edits on my phone when reconnected, so that no data is silently dropped.
15. As a sovereign data owner, I want to export and import my complete medical database as an encrypted SQLite/JSON backup at any time, so that I retain perpetual ownership of my health data.

---

## Implementation Decisions

### 1. Embedded Relational Database & Reactive State
- **Database Engine:** Embedded SQLite managed through Drift (Dart type-safe persistence).
- **Reactive UI Layer:** Riverpod stream providers observing Drift queries for instantaneous, reactive UI updates.
- **Isolate Offloading:** Database operations run on background isolates using `NativeDatabase.createInBackground` to eliminate UI frame drops.

### 2. Append-Only CDC Replication Protocol
- **Event Log Schema:** An internal `cdc_events` table captures every `INSERT`, `UPDATE`, and `DELETE` with:
  - `id`: UUID v4
  - `entity_type`: Target entity string (`medication`, `dose_log`, `dependent`, `vital`, `document`)
  - `entity_id`: Target record UUID
  - `operation`: Mutation type
  - `payload`: Serialized JSON delta
  - `hlc_timestamp`: Monotonic Hybrid Logical Clock string (`millis:counter:deviceId`)
  - `device_id`: Originating device UUID
  - `is_synced`: Boolean sync flag
- **Conflict Resolution:** Deterministic field-level Last-Write-Wins (LWW) governed by HLC comparison during sync event replay.

### 3. Android System Gemini / Assistant Interface
- **Integration Boundary:** Android App Actions, Custom Intents, and `shortcuts.xml` capability definitions.
- **Intent Targets:**
  - `actions.intent.RECORD_MEDICATION` &rarr; `gobi://intent/medication/log`
  - `actions.intent.GET_MEDICATION_SCHEDULE` &rarr; `gobi://intent/medication/schedule`
  - `actions.intent.OPEN_APP_FEATURE` &rarr; `gobi://intent/camera/ocr-scan`
- **Zero Local LLM Runtime Bloat:** Delegates natural language understanding to the Android OS, invoking Gobi's intent router with structured parameters.

### 4. On-Device OCR Processing
- **Engine:** Google ML Kit Text Recognition v2 + Android Document Scanner API.
- **Parsing Seam:** Background Dart isolate executing deterministic regex patterns for dosage units (`mg`, `mcg`, `ml`, `IU`, `tablets`, `pills`), frequencies (`OD`, `BD`, `TID`, `QID`, `PRN`, `daily`), and common medication name lexicons.

### 5. Dumb Catch-All Backend Contract
- **Role:** Minimal End-to-End Encrypted (E2EE) mailbox relay and encrypted document blob store.
- **Stateless Relaying:** The server stores opaque ciphertexts with user-controlled auth headers; no database migrations or relational business logic reside on the server.
- **Decoupled Lifecycle:** Gobi runs with 100% functionality without the backend container active.

---

## Testing Decisions

### 1. Seams and Test Boundaries
- **Primary Seam (Repository / Engine Level):** All unit and integration tests exercise the application at the Repository and Drift Database boundary using in-memory SQLite instances (`NativeDatabase.memory()`).
- **CDC Determinism Tests:** Simulate multi-device concurrent mutations across two separate in-memory Drift databases, exchanging CDC event streams and asserting identical final converged state under arbitrary message delivery orders.
- **Intent Router Tests:** Validate that incoming deep links and intent URIs parse parameters and invoke the appropriate local repository actions correctly.
- **UI Component Smoke Tests:** Exercise Flutter widget flows (adding medications, marking doses taken, theme toggling) backed by in-memory repositories.

---

## Out of Scope

1. Third-party cloud LLM API integrations (OpenAI / Anthropic / Cloud Gemini APIs) sending raw user data.
2. In-app heavy LLM weight distribution (>500MB model downloads).
3. Server-side plaintext prescription processing or relational business logic.
4. Centralized third-party advertising or telemetric health trackers.

---

## Further Notes

- Existing Go/PostgreSQL backend services will be progressively slimmed down to act as a lightweight E2EE sync relay.
- All Flutter entities and database migrations will maintain forward/backward schema compatibility via Drift schema versioning.
