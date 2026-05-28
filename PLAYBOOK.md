# Infrastructure Playbook

Reusable runbook for managing a `*-compose` Docker infrastructure repo (helios-compose, soteria-compose, etc.).

---

## 1. Naming Convention

Pattern: `{server}-{env}-{role}-{app}`

| Part | Examples |
|---|---|
| server | `hel`, `sot` |
| env | `prod` |
| role | `apps`, `mon`, `inv`, `db`, `auth` |
| app | `taiga`, `grafana`, `netbox`, … |

Sub-services append a suffix: `hel-prod-apps-taiga-db`, `hel-prod-apps-taiga-rabbitmq`

- Container name must match the service key exactly
- Directory name matches the top-level service: `services/hel-prod-apps-taiga/`

---

## 2. Adding a New Service — Checklist

### Step 1 — Verify image versions
**Never use `:latest` in production.** Look up the current pinned tag before writing the compose file.

```
Docker Hub:  https://hub.docker.com/r/<vendor>/<image>/tags
GitHub:      https://github.com/<org>/<repo>/releases
```

### Step 2 — Create the service directory and compose.yml

```
services/
  hel-prod-{role}-{app}/
    compose.yml          # required
    prometheus.yml       # if it's the monitoring service
    nginx.conf           # if it needs an internal gateway (e.g. Taiga)
    provisioning/        # if Grafana auto-provisioning is needed
```

**compose.yml template:**
```yaml
services:
  hel-prod-{role}-{app}:
    image: vendor/image:pinned-version
    container_name: hel-prod-{role}-{app}
    restart: unless-stopped
    environment:
      TZ: 'Europe/Brussels'
      SOME_SECRET: ${ENV_VAR}
    volumes:
      - /var/lib/docker-compose/hel-prod-{role}-{app}:/app/data
    ports:
      - "HOST:CONTAINER"   # only what NPM needs to proxy
```

**Rules:**
- Always set `TZ: 'Europe/Brussels'`
- Always set `container_name` matching the service key
- All volumes use `/var/lib/docker-compose/{container-name}/` on the host
- Pin image versions — verify on Docker Hub or GitHub releases before writing

### Step 3 — Add Watchtower labels to stateful services

Databases, message brokers, and search engines should NOT be auto-updated — version upgrades often require migrations.

Add to every stateful sub-service (Postgres, MongoDB, Redis, RabbitMQ, Elasticsearch, etc.):
```yaml
    labels:
      com.centurylinklabs.watchtower.enable: "false"
```

App-tier containers (backends, frontends, workers) can auto-update — leave them unlabelled.

### Step 4 — Register in root docker-compose.yml

```yaml
include:
  - services/hel-prod-{role}-{app}/compose.yml
```

### Step 5 — Add secrets to `secrets/helios.env`

```
# --- hel-prod-{role}-{app} ---------------------------------------------------
APP_DB_NAME=appname
APP_DB_USER=appname
APP_DB_PASSWORD=        # fill in: strong random string
APP_SECRET_KEY=         # fill in: long random string
```

Generate random secrets:
```bash
openssl rand -hex 32    # 64-char hex secret
openssl rand -base64 48 # 64-char base64 secret
```

Store all filled-in values in **Bitwarden** and back up to **TrueNAS**.

### Step 6 — Decide on public vs internal domain

| Access pattern | Subdomain |
|---|---|
| ICT / admins only | `service.int.maakleerplek.be` |
| All users / volunteers | `service.maakleerplek.be` |

Point NPM to `host-ip:HOST_PORT`.

### Step 7 — Update README.md

- Add to architecture diagram
- Add row to Current Services table (service name, role, port, NPM domain)
- Add any setup tips (e.g. dashboard import IDs for Grafana)

### Step 8 — Commit and push

```bash
git add services/hel-prod-{role}-{app}/ docker-compose.yml secrets/helios.env README.md
git commit -m "feat({role}): add {app} service"
git push
```

---

## 3. Standard Supporting Services

These should exist in every `*-compose` repo. Set them up first.

### Watchtower — nightly auto-update
```yaml
# services/hel-prod-apps-watchtower/compose.yml
image: containrrr/watchtower:1.7.1
environment:
  WATCHTOWER_CLEANUP: "true"
  WATCHTOWER_SCHEDULE: "0 0 4 * * *"   # 04:00 every night
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```
- Watches all containers by default
- Exclude stateful services with `com.centurylinklabs.watchtower.enable: "false"`

### Monitoring stack — Grafana + Prometheus
```
services/hel-prod-mon/
  compose.yml              # Grafana, Prometheus, node-exporter, cAdvisor
  prometheus.yml           # scrape config
  provisioning/
    datasources/
      prometheus.yml       # auto-provisions Prometheus as Grafana data source
```

Pinned versions (verified May 2026):
| Image | Version |
|---|---|
| `grafana/grafana` | `13.0.1` |
| `prom/prometheus` | `v2.52.0` |
| `prom/node-exporter` | `v1.9.1` |
| `gcr.io/cadvisor/cadvisor` | `v0.52.1` |

Grafana dashboard IDs to import after setup:
- `1860` — Node Exporter Full (host metrics)
- `14282` — Docker cAdvisor (container metrics)

---

## 4. Port Registry

Keep this updated to avoid conflicts. NPM proxies these to the outside.

| Port | Service |
|---|---|
| 3000 | `hel-prod-mon-grafana` |
| 8083 | `hel-prod-apps-taiga-gateway` |
| 8084 | `hel-prod-apps-truedesk` |

---

## 5. Planned / Future Services

See `feature.md` for services that are designed but not yet implemented.

| Feature | Description |
|---|---|
| GitOps webhook | Auto-deploy on `git push` via `adnanh/webhook` + GitHub webhook + HMAC validation |

---

## 6. Removing a Service

1. Stop the containers: `docker compose stop hel-prod-{role}-{app}`
2. Remove from root `docker-compose.yml` include list
3. Delete `services/hel-prod-{role}-{app}/` directory
4. Remove env vars from `secrets/helios.env`
5. Update README architecture diagram and services table
6. Commit and push
7. Data in `/var/lib/docker-compose/hel-prod-{role}-{app}/` is kept until manually deleted — intentional, prevents accidental data loss
