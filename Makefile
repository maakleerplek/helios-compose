.PHONY: up down pull deploy logs ps restart backup help

# Load secrets
ENV_FILE := ./secrets/helios.env

## Start all services
up:
	docker compose --env-file $(ENV_FILE) up -d --remove-orphans

## Stop all services (no data loss)
down:
	docker compose --env-file $(ENV_FILE) down

## Pull latest images
pull:
	docker compose --env-file $(ENV_FILE) pull

## Pull latest images and restart — standard deploy
deploy: pull up

## Stream logs (all services). Usage: make logs  or  make logs SERVICE=hel-prod-inv-netbox
logs:
	docker compose --env-file $(ENV_FILE) logs -f $(SERVICE)

## Show container status
ps:
	docker compose --env-file $(ENV_FILE) ps

## Restart a service. Usage: make restart SERVICE=hel-prod-inv-netbox
restart:
	docker compose --env-file $(ENV_FILE) restart $(SERVICE)

## Backup all data and secrets to TrueNAS
backup:
	rsync -az /var/lib/docker-compose/ hel-prod-nas-truenas:/mnt/pool/backups/helios/var/lib/docker-compose/
	rsync -az ./secrets/helios.env hel-prod-nas-truenas:/mnt/pool/backups/helios/secrets/

## Show this help
help:
	@grep -E '^##' Makefile | sed 's/## //'
