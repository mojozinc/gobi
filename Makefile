HOST_IP = $(shell hostname -I | awk '{print $$1}')
API_URL = http://$(HOST_IP):8000

.PHONY: run up down ip

# Mobile
run:
	cd gobi-mobile && flutter run --dart-define=API_BASE_URL=$(API_URL)

# Backend (Docker)
up:
	docker compose -f backend-api/docker-compose.yml up -d

down:
	docker compose -f backend-api/docker-compose.yml down

# Print resolved URL
ip:
	@echo $(API_URL)
