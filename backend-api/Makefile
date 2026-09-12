.PHONY: run test install docker-build docker-up docker-down docker-watch

install:
	pip install -r requirements.txt

run:
	uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

test:
	PYTHONPATH=. pytest -v

docker-build:
	docker build -t gobi-backend-api:latest .

docker-up:
	docker compose up -d

docker-down:
	docker compose down

docker-watch:
	docker compose up --watch
