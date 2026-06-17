# WordPress Docker Makefile
# Universal template for local WordPress development

# Default target: show help
.DEFAULT_GOAL := help

# Load environment variables from .env
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Default values
WP_PORT ?= 8080
NEW ?= http://localhost:$(WP_PORT)

.PHONY: help setup up down logs clean build import-db wp composer replace-urls pull pull-files pull-db

# ------------------------------------------------------------------------------
# Core Commands
# ------------------------------------------------------------------------------

## Interactive setup wizard for new WordPress instance
setup:
	@bash setup.sh

## Build/rebuild WordPress image (after changing PHP_VERSION)
build:
	@docker compose build
	@echo "Image rebuilt. Run 'make up' to start with new image."

## Start WordPress and database containers
up:
	@docker compose up -d
	@echo "WordPress running at http://localhost:$(WP_PORT)"

## Stop containers (data persists)
down:
	@docker compose down

## Follow container logs
logs:
	@docker compose logs -f

## Stop containers and DELETE all data (database volume)
clean:
	@echo "WARNING: This will delete the database volume!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@docker compose down -v
	@echo "Containers stopped and volumes removed."

# ------------------------------------------------------------------------------
# Database Import
# ------------------------------------------------------------------------------

## Import database from data/dump.sql or data/dump.sql.gz
## Usage: make import-db
import-db:
	@echo "Dropping and recreating database $(MYSQL_DATABASE)..."
	@docker compose exec -T db mysql -u root -p$(MYSQL_ROOT_PASSWORD) \
		-e "DROP DATABASE IF EXISTS \`$(MYSQL_DATABASE)\`; CREATE DATABASE \`$(MYSQL_DATABASE)\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
	@if [ -f data/dump.sql.gz ]; then \
		echo "Importing data/dump.sql.gz..."; \
		gunzip -c data/dump.sql.gz | docker compose exec -T db mysql -u root -p$(MYSQL_ROOT_PASSWORD) $(MYSQL_DATABASE); \
	elif [ -f data/dump.sql ]; then \
		echo "Importing data/dump.sql..."; \
		docker compose exec -T db mysql -u root -p$(MYSQL_ROOT_PASSWORD) $(MYSQL_DATABASE) < data/dump.sql; \
	else \
		echo "Error: No dump file found. Place dump.sql or dump.sql.gz in data/ directory."; \
		exit 1; \
	fi
	@echo "Database import complete."

# ------------------------------------------------------------------------------
# WP-CLI
# ------------------------------------------------------------------------------

## Run WP-CLI command in WordPress container
## Usage: make wp -- plugin list
##        make wp -- user list
wp:
	@docker compose exec wordpress wp --allow-root $(filter-out $@,$(MAKECMDGOALS))

## Replace URLs in database after import
## Usage: make replace-urls OLD=https://example.com
##        make replace-urls OLD=https://example.com NEW=http://localhost:8080
replace-urls:
ifndef OLD
	$(error OLD is required. Usage: make replace-urls OLD=https://example.com)
endif
	@echo "Replacing $(OLD) with $(NEW)..."
	@docker compose exec wordpress wp search-replace "$(OLD)" "$(NEW)" --all-tables --allow-root
	@echo "URL replacement complete."

# ------------------------------------------------------------------------------
# Composer
# ------------------------------------------------------------------------------

## Run Composer command in WordPress container
## Usage: make composer -- install
##        make composer -- require wpackagist-plugin/advanced-custom-fields
composer:
	@docker compose exec wordpress composer $(filter-out $@,$(MAKECMDGOALS))

# ------------------------------------------------------------------------------
# Pull from Server (optional)
# ------------------------------------------------------------------------------

## Pull wp-content and database from remote server
## Usage: make pull SERVER=user@host WP_PATH=/var/www/html
## Requires: SSH access, WP-CLI on server
pull: pull-files pull-db import-db
	@echo "Pull complete. Run 'make replace-urls OLD=https://your-site.com' to update URLs."

## Pull only wp-content files from server
## Usage: make pull-files SERVER=user@host WP_PATH=/var/www/html
pull-files:
ifndef SERVER
	$(error SERVER is required. Usage: make pull-files SERVER=user@host WP_PATH=/path/to/wp)
endif
ifndef WP_PATH
	$(error WP_PATH is required. Usage: make pull-files SERVER=user@host WP_PATH=/path/to/wp)
endif
	@if command -v rsync >/dev/null 2>&1; then \
		echo "Syncing wp-content from $(SERVER):$(WP_PATH)/wp-content/ (rsync)..."; \
		mkdir -p data/wp-content; \
		rsync -avz --delete \
			--exclude='cache/' \
			--exclude='w3tc-config/' \
			--exclude='wp-rocket-config/' \
			--exclude='breeze/' \
			--exclude='wpo-cache/' \
			--exclude='litespeed/' \
			--exclude='endurance-page-cache/' \
			--exclude='upgrade/' \
			--exclude='*-cache/' \
			$(SERVER):$(WP_PATH)/wp-content/ ./data/wp-content/; \
	else \
		echo "rsync not found, using scp instead..."; \
		echo "Note: scp does not support incremental sync. For large sites, install rsync:"; \
		echo "  macOS:  brew install rsync"; \
		echo "  Ubuntu: sudo apt install rsync"; \
		mkdir -p data/wp-content; \
		scp -r $(SERVER):$(WP_PATH)/wp-content/ ./data/wp-content/; \
	fi
	@echo "Files synced."

## Pull only database from server
## Usage: make pull-db SERVER=user@host WP_PATH=/var/www/html
## Tries WP-CLI first, falls back to mysqldump using wp-config.php credentials
pull-db:
ifndef SERVER
	$(error SERVER is required. Usage: make pull-db SERVER=user@host WP_PATH=/path/to/wp)
endif
ifndef WP_PATH
	$(error WP_PATH is required. Usage: make pull-db SERVER=user@host WP_PATH=/path/to/wp)
endif
	@echo "Exporting database from $(SERVER)..."
	@if ssh $(SERVER) "command -v wp >/dev/null 2>&1 && cd $(WP_PATH) && wp db export - 2>/dev/null" > data/dump.sql 2>/dev/null && [ -s data/dump.sql ]; then \
		echo "Database exported via WP-CLI to data/dump.sql"; \
	else \
		echo "WP-CLI not available or failed, trying mysqldump..."; \
		rm -f data/dump.sql; \
		ssh $(SERVER) "cd $(WP_PATH) && \
			DB_NAME=\$$(awk -F\\' '/define.*DB_NAME/{print \$$4}' wp-config.php) && \
			DB_USER=\$$(awk -F\\' '/define.*DB_USER/{print \$$4}' wp-config.php) && \
			DB_PASS=\$$(awk -F\\' '/define.*DB_PASSWORD/{print \$$4}' wp-config.php) && \
			DB_HOST=\$$(awk -F\\' '/define.*DB_HOST/{print \$$4}' wp-config.php) && \
			mysqldump -h\$$DB_HOST -u\$$DB_USER -p\$$DB_PASS \$$DB_NAME" > data/dump.sql; \
		echo "Database exported via mysqldump to data/dump.sql"; \
	fi

# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------

## Show this help
help:
	@echo ""
	@echo "WordPress Docker - Local Development Environment"
	@echo "================================================"
	@echo ""
	@echo "CORE COMMANDS:"
	@echo "  make setup             Interactive setup wizard (recommended for first use)"
	@echo "  make up                Start WordPress and database containers"
	@echo "  make down              Stop containers (data persists in volumes)"
	@echo "  make build             Rebuild image (after changing PHP_VERSION in .env)"
	@echo "  make logs              Follow container logs in real-time"
	@echo "  make clean             Stop containers AND delete database volume (destructive!)"
	@echo ""
	@echo "DATABASE:"
	@echo "  make import-db         Import database from data/dump.sql or data/dump.sql.gz"
	@echo "  make replace-urls      Replace URLs after import"
	@echo "                         Usage: make replace-urls OLD=https://production-site.com"
	@echo "                         Optional: NEW=http://localhost:8080 (default from .env)"
	@echo ""
	@echo "WP-CLI:"
	@echo "  make wp -- <command>   Run any WP-CLI command inside the container"
	@echo "                         Examples:"
	@echo "                           make wp -- plugin list"
	@echo "                           make wp -- user list"
	@echo "                           make wp -- cache flush"
	@echo "                           make wp -- option get siteurl"
	@echo ""
	@echo "COMPOSER:"
	@echo "  make composer -- <cmd>  Run Composer command inside the container"
	@echo "                         Examples:"
	@echo "                           make composer -- install"
	@echo "                           make composer -- require wpackagist-plugin/acf"
	@echo "                           make composer -- dump-autoload"
	@echo ""
	@echo "PULL FROM SERVER (requires SSH access):"
	@echo "  make pull              Pull wp-content + database, then import"
	@echo "  make pull-files        Pull only wp-content directory"
	@echo "  make pull-db           Pull only database (requires WP-CLI on server)"
	@echo "                         Usage: make pull SERVER=user@host WP_PATH=/var/www/html"
	@echo ""
	@echo "QUICK START:"
	@echo "  make setup                 (interactive wizard - recommended)"
	@echo "  --- or manually ---"
	@echo "  1. cp .env.example .env    (edit passwords)"
	@echo "  2. make up                 (start containers)"
	@echo "  3. Place dump.sql in data/ and run: make import-db"
	@echo "  4. make replace-urls OLD=https://your-site.com"
	@echo ""

# Catch-all target to allow passing arguments to wp
%:
	@:
