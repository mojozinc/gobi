# Project Gobi - Developer & Agent Guardrails

## 1. Mobile & Backend Networking
- **Dynamic LAN Base URL**: The mobile app receives its backend URL dynamically via `--dart-define=API_BASE_URL=http://$(HOST_IP):8000` (invoked via `make run`).
- **No `adb reverse` Requirement**: When running over local Wi-Fi, do NOT require or instruct `adb reverse`. `adb reverse` is only a fallback for USB-only environments with Wi-Fi client isolation.
- **Provider Resolution**: Always wire `AppConfig.apiBaseUrl` into network services rather than hardcoding `localhost` or `10.0.2.2`.

## 2. Client Authentication & 401 Recovery
- **Self-Healing Requests**: Network clients must verify authentication before sending requests and automatically attempt anonymous login or token refresh if a `401 Unauthorized` is returned, retrying the request once.
- **Explicit Error Propagation**: Never return empty or `null` models on non-200 HTTP responses; always throw structured exceptions so state notifiers and UI error boundaries can display retry mechanisms.

## 3. Backend Observability & Logging
- **Configurable `LOG_LEVEL`**: Backend services must default to `LOG_LEVEL=DEBUG` in development, exposed through `docker-compose.yml` and `Settings`.
- **Request Logging Middleware**: All incoming requests, latencies (ms), client IPs, and status codes >= 400 must be explicitly logged with structured timestamps.
- **External AI Service Diagnostics**: When calling OpenRouter or third-party LLMs, log model selection, token responses, and full upstream error payloads upon failure.

## 4. Reproducible Environment & Makefile Shortcuts
- **Launch Emulator**: Use `make emulator` to launch the Android emulator GUI window with custom `ANDROID_AVD_HOME=D:/android-avds` and `ANDROID_ADB_SERVER_PORT=5038`.
- **Run App on Emulator**: Use `make run-emulator` to build and run the Flutter app on `emulator-5554` targeting `http://10.0.2.2:8000`.
- **ADB Port Resolution**: Use `make adb-fix` to restart ADB on port `5038` whenever default port `5037` reports connection refusal or socket errors.
- **Kotlin Incremental Build Configuration**: Maintain `kotlin.incremental=false` and `kotlin.incremental.useClasspathSnapshot=false` in `android/gradle.properties` to prevent Kotlin compiler `FilePageCache` locking errors (`Storage for [...file-to-id.tab] is already registered`) when Flutter Android plugin subprojects (`image_picker_android`, `speech_to_text`, `shared_preferences_android`) compile in parallel on Windows.

