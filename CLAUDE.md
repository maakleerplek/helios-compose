# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Project Overview

Docker Compose infrastructure for `hel-prod-cont-docker` — the Docker host VM on Helios (Proxmox). Mirrors the structure of soteria-compose. Infrastructure-level services only; Coolify manages its own app stacks separately.

## Architecture

Modular structure using Docker Compose `include`:
- **Root** `docker-compose.yml` — stack name + include list
- **`services/{service-name}/compose.yml`** — one directory per service
- **`secrets/.env`** — all secrets, git-ignored, backed up to TrueNAS + Bitwarden
- **`/docker_data/`** — all persistent data on the host, backed up to TrueNAS

## Naming Convention

Pattern: `{server}-{env}-{role}-{app}`

| Part | Values |
|---|---|
| server | `hel` (Helios) |
| env | `prod` |
| role | `apps`, `inv`, `mon`, `db`, `auth` |
| app | `coolify`, `netbox`, `grafana`, `prometheus`, etc. |

Examples: `hel-prod-apps-coolify`, `hel-prod-inv-netbox`, `hel-prod-mon-grafana`

Sub-services (databases, workers) append a suffix: `hel-prod-inv-netbox-db`, `hel-prod-inv-netbox-redis`

Container names must match the service key exactly.

## Conventions for compose.yml files

```yaml
services:
  hel-prod-{role}-{app}:
    image: vendor/image:pinned-version     # pin versions, don't use latest in prod
    container_name: hel-prod-{role}-{app}  # always set, matches service key
    restart: unless-stopped
    environment:
      TZ: 'Europe/Brussels'                # always set timezone
      SOME_SECRET: ${ENV_VAR}              # reference secrets/.env via ${}
    volumes:
      - /docker_data/hel-prod-{role}-{app}:/app/data   # always /docker_data/
    ports:
      - "host:container"                   # expose only what NPM needs to proxy
```

## Secrets

All in `secrets/.env`. Never committed to Git.
- Template: `secrets/.env.example` (committed, no real values)
- Backup: TrueNAS `/mnt/pool/backups/helios/secrets/` + Bitwarden

## Data

All volumes use `/docker_data/{container-name}/` on the host. One rsync backs up everything:
```bash
rsync -az /docker_data/ hel-prod-nas-truenas:/mnt/pool/backups/helios/docker_data/
```

## Deployment

No Portainer. All operations via `make` or direct `docker compose` commands.

```bash
make deploy                              # standard deploy: pull + up
make logs SERVICE=hel-prod-inv-netbox   # tail logs for one service
docker compose exec hel-prod-inv-netbox sh   # shell into container
```

## What belongs here vs Coolify

| Here (helios-compose) | Coolify |
|---|---|
| Coolify itself | User apps deployed via Coolify |
| Netbox | Volunteer projects |
| Monitoring stack | Team tooling deployed by users |
| Any future ICT-owned infra services | |

Rule of thumb: if it monitors, routes, or enables other services — it's here. If a user asked for it — it's Coolify.
