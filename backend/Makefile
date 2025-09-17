.PHONY: help test test-race test-verbose test-coverage cover lint migrate clean deps docker-up docker-down

# Default target
help:		## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Dependencies
deps:		## Download dependencies
	go mod download
	go mod verify

# Testing
test:		## Run all tests
	go test ./... -v

test-race:	## Run tests with race detection
	go test ./... -race -v

test-verbose:	## Run tests with verbose output
	go test ./... -v -count=1

test-coverage:	## Run tests with coverage
	go test ./... -race -coverprofile=coverage.out -covermode=atomic
	go tool cover -func=coverage.out
	@echo ""
	@echo "Coverage report generated: coverage.out"

cover:		## Show coverage in browser
	go tool cover -html=coverage.out

# Coverage threshold check
check-coverage: test-coverage	## Check if coverage meets 80% threshold
	@coverage=$$(go tool cover -func=coverage.out | grep total | awk '{print $$3}' | sed 's/%//'); \
	echo "Test coverage: $${coverage}%"; \
	if [ $$(echo "$${coverage} < 80" | bc) -eq 1 ]; then \
		echo "❌ Coverage $${coverage}% is below required 80%"; \
		exit 1; \
	else \
		echo "✅ Coverage $${coverage}% meets requirement (≥80%)"; \
	fi

# Linting
lint:		## Run linter
	golangci-lint run --timeout=5m

# Database operations
migrate:	## Run database migrations
	@echo "Running database migrations..."
	@if [ -z "$$DATABASE_URL" ]; then \
		echo "DATABASE_URL environment variable is not set"; \
		echo "Using default: postgres://postgres:postgres@localhost:5432/desci?sslmode=disable"; \
		export DATABASE_URL="postgres://postgres:postgres@localhost:5432/desci?sslmode=disable"; \
	fi
	@for file in migrations/*.sql; do \
		echo "Executing $$file..."; \
		PGPASSWORD=postgres psql "$$DATABASE_URL" -f "$$file"; \
	done

# Docker operations
docker-up:	## Start PostgreSQL with docker-compose
	docker run --name desci-postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_USER=postgres -e POSTGRES_DB=desci -p 5432:5432 -d postgres:16

docker-down:	## Stop and remove PostgreSQL container
	docker stop desci-postgres || true
	docker rm desci-postgres || true

# Build
build:		## Build the application
	go build -o bin/desci-backend ./cmd/...

# Run
run:		## Run the application
	go run ./cmd/server

# Development
dev-setup: docker-up	## Set up development environment
	@echo "Waiting for PostgreSQL to be ready..."
	@sleep 5
	$(MAKE) migrate
	@echo "Development environment is ready!"

# Clean
clean:		## Clean build artifacts and test cache
	go clean -testcache
	rm -f coverage.out coverage.html
	rm -rf bin/

# Integration tests (requires running PostgreSQL)
test-integration:	## Run integration tests
	@echo "Running integration tests..."
	@if [ -z "$$DATABASE_URL" ]; then \
		echo "DATABASE_URL not set, using default"; \
		export DATABASE_URL="postgres://postgres:postgres@localhost:5432/desci_test?sslmode=disable"; \
	fi
	go test ./tests/ -v -tags=integration

# Full test suite (unit + integration)
test-all: test test-integration	## Run all tests (unit + integration)

# CI simulation
ci: deps lint check-coverage	## Simulate CI pipeline locally

# Benchmark
benchmark:	## Run benchmark tests
	go test ./... -bench=. -benchmem

# Security check
security:	## Run security checks
	gosec ./...

# Generate mocks (if using mockgen)
mocks:		## Generate mocks for testing
	@echo "Generating mocks..."
	@# Add mockgen commands here if needed

# Database reset (development only)
db-reset: docker-down docker-up	## Reset database (WARNING: destroys data)
	@sleep 5
	$(MAKE) migrate
	@echo "Database reset complete"

# Show environment info
env:		## Show environment information
	@echo "Go version: $$(go version)"
	@echo "GOPATH: $$GOPATH"
	@echo "PWD: $$PWD"
	@echo "DATABASE_URL: $$DATABASE_URL" 