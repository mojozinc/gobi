.PHONY: run test install docker-build

install:
	pip install -r requirements.txt

run:
	uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

test:
	PYTHONPATH=. pytest -v

docker-build:
	docker build -t gobi-backend-api:latest .
