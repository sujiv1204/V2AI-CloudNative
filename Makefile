.PHONY: help build up down logs clean test

help:
	@echo "V2AI Development Commands"
	@echo "build       - Build Docker images"
	@echo "up          - Start services"
	@echo "down        - Stop services"
	@echo "logs        - Show service logs"
	@echo "test        - Run tests"
	@echo "clean       - Clean up containers and volumes"

build:
	docker-compose build

up:
	docker-compose up -d

down:
	docker-compose down

logs:
	docker-compose logs -f

test:
	docker-compose exec backend python -m pytest tests/

clean:
	docker-compose down -v
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
