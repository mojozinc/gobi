HOST_IP = $(shell hostname -I | awk '{print $$1}')
API_URL = http://$(HOST_IP):8000

.PHONY: run up down ip codegen watch-codegen test clean

# Mobile - Run App
run:
	cd gobi-mobile && flutter run --dart-define=API_BASE_URL=$(API_URL)

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

# Print resolved URL
ip:
	@echo $(API_URL)

