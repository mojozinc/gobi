-include .env

AVD_NAME ?= Gobi_Pixel_API34
AVD_DIR ?= D:/android-avds
ADB_PORT ?= 5038
EMULATOR_API_URL ?= http://10.0.2.2:8000
PUB_CACHE ?= D:/pub-cache

IS_WINDOWS := 0

ifeq ($(OS),Windows_NT)
    IS_WINDOWS := 1
else
    UNAME_S := $(shell uname -s 2>/dev/null)
    UNAME_R := $(shell uname -r 2>/dev/null)
    ifneq ($(findstring Microsoft,$(UNAME_R)),)
        IS_WINDOWS := 1
    endif
    ifneq ($(findstring microsoft,$(UNAME_R)),)
        IS_WINDOWS := 1
    endif
    ifneq ($(findstring WSL,$(UNAME_R)),)
        IS_WINDOWS := 1
    endif
    ifneq ($(findstring MINGW,$(UNAME_S)),)
        IS_WINDOWS := 1
    endif
    ifneq ($(findstring CYGWIN,$(UNAME_S)),)
        IS_WINDOWS := 1
    endif
endif

ifeq ($(IS_WINDOWS),1)
    HOST_IP ?= 127.0.0.1
    EMULATOR_BIN ?= "%LOCALAPPDATA%/Android/Sdk/emulator/emulator.exe"
    ADB_BIN ?= "%LOCALAPPDATA%/Android/Sdk/platform-tools/adb.exe"
else
    HOST_IP := $(shell hostname -I 2>/dev/null | awk '{print $$1}')
    ifeq ($(HOST_IP),)
        HOST_IP := 127.0.0.1
    endif
    EMULATOR_BIN ?= emulator
    ADB_BIN ?= adb
endif

API_URL ?= http://$(HOST_IP):8000

.PHONY: run run-emulator emulator adb-fix up down ip codegen watch-codegen test clean

# Mobile - Run App
run:
	cd gobi-mobile && flutter run --dart-define=API_BASE_URL=$(API_URL)

# Mobile - Run App on Android Emulator
run-emulator:
ifeq ($(IS_WINDOWS),1)
	cd gobi-mobile && cmd.exe /c "set ANDROID_ADB_SERVER_PORT=$(ADB_PORT)&& flutter run -d emulator-5554 --dart-define=API_BASE_URL=$(EMULATOR_API_URL)"
else
	cd gobi-mobile && ANDROID_ADB_SERVER_PORT=$(ADB_PORT) flutter run -d emulator-5554 --dart-define=API_BASE_URL=$(EMULATOR_API_URL)
endif

# Mobile - Launch Android Emulator GUI Window
emulator:
	@echo "Launching Android Emulator ($(AVD_NAME))..."
ifeq ($(IS_WINDOWS),1)
	@cmd.exe /c "set ANDROID_AVD_HOME=$(AVD_DIR)&& set ANDROID_ADB_SERVER_PORT=$(ADB_PORT)&& start "" $(EMULATOR_BIN) -avd $(AVD_NAME) -gpu host"
else
	@ANDROID_AVD_HOME="$(AVD_DIR)" ANDROID_ADB_SERVER_PORT="$(ADB_PORT)" $(EMULATOR_BIN) -avd $(AVD_NAME) -gpu host &
endif

# Mobile - Restart ADB on port 5038 to fix Windows port 5037 conflicts
adb-fix:
ifeq ($(IS_WINDOWS),1)
	cmd.exe /c "set ANDROID_ADB_SERVER_PORT=$(ADB_PORT)&& $(ADB_BIN) kill-server&& $(ADB_BIN) start-server"
else
	ANDROID_ADB_SERVER_PORT=$(ADB_PORT) $(ADB_BIN) kill-server && ANDROID_ADB_SERVER_PORT=$(ADB_PORT) $(ADB_BIN) start-server
endif




# Mobile - Code Generation (Drift SQLite, Hive models)
codegen:
	cd gobi-mobile && dart run build_runner build --delete-conflicting-outputs

# Mobile - Live Code Generation Watcher
watch-codegen:
	cd gobi-mobile && dart run build_runner watch --delete-conflicting-outputs

# Mobile - Run Tests
test:
	cd gobi-mobile && flutter test

# Mobile - Clean and Reinstall Dependencies
clean:
	cd gobi-mobile && flutter clean && flutter pub get

# Backend (Docker)
up:
	docker compose -f backend-api/docker-compose.yml up -d

down:
	docker compose -f backend-api/docker-compose.yml down

watch-backend:
	docker compose -f backend-api/docker-compose.yml up --watch

# Print resolved URL
ip:
	@echo $(API_URL)

# AI Chat API Smoke Test
smoke-chat:
	@./scripts/smoke_test_chat.sh

# Cloudflare Tunnel for Backend API
tunnel:
	@echo "Starting Cloudflare Quick Tunnel on http://localhost:8000..."
	cloudflared tunnel --url http://localhost:8000

# Deploy Backend to Google Cloud Run
GCP_REGION ?= europe-west1
GCP_SERVICE ?= gobi-backend

deploy-backend:
	@echo "Deploying $(GCP_SERVICE) to Google Cloud Run ($(GCP_REGION))..."
	cd backend-api && gcloud run deploy $(GCP_SERVICE) \
		--source . \
		--region $(GCP_REGION) \
		--allow-unauthenticated


