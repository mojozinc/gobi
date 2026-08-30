.PHONY: help build run test clean docker-build docker-up docker-down tidy

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the application
	@echo "Building communication-gateway..."
	@go build -o bin/communication-gateway ./cmd/server
	@echo "Build complete: bin/communication-gateway"

run: ## Run the application
	@go run cmd/server/main.go

dev: ## Run with auto-reload (requires air: go install github.com/air-verse/air@latest)
	@air

test: ## Run tests
	@go test -v ./...

tidy: ## Tidy Go modules
	@go mod tidy

clean: ## Clean build artifacts and sessions
	@echo "Cleaning..."
	@rm -rf bin/
	@rm -rf sessions/
	@echo "Clean complete"

docker-build: ## Build Docker image
	@docker build -t gobi-communication-gateway .

docker-up: ## Start service with Docker Compose
	@docker-compose up -d
	@echo "Service started on http://localhost:8080"

docker-down: ## Stop Docker Compose services
	@docker-compose down

docker-logs: ## View Docker logs
	@docker-compose logs -f

setup: ## Initial setup - copy .env.example to .env
	@cp .env.example .env
	@echo ".env file created. Please edit it with your configuration."

qr: ## Get QR code for WhatsApp authentication
	@./scripts/show-qr.sh

status: ## Check WhatsApp connection status
	@curl -s -H "Authorization: Bearer $${API_KEY:-test-api-key}" \
	http://localhost:8080/api/v1/status | jq

send: ## Send test message (usage: make send PHONE=1234567890 MSG="Hello")
	@curl -X POST http://localhost:8080/api/v1/send \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer $${API_KEY:-test-api-key}" \
	-d '{"phone":"$(PHONE)","message":"$(MSG)"}' | jq
