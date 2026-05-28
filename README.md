# Helios Stack

Reproducible Docker infrastructure for `hel-prod-app-docker`. Mirrors the structure of [soteria-compose](https://github.com/maakleerplek/soteria_compose).

This repo covers **infrastructure-level services only**.

## Architecture

```
hel-prod-app-docker (Rocky 9.5 — Docker host on Helios/Proxmox)
  ├── hel-prod-apps-taiga        ICT project planning (+ async, front, events, gateway, rabbitmq, postgres)
  ├── hel-prod-apps-truedesk     User helpdesk & feature requests (+ mongodb)
  ├── hel-prod-apps-watchtower   Nightly auto-update of app containers
  └── hel-prod-mon               Monitoring stack (Grafana + Prometheus + node-exporter + cAdvisor)
```

## Data Management

- **All persistent data**: `/var/lib/docker-compose/` — backed up to TrueNAS
- **Secrets**: `./secrets/helios.env` — excluded from Git, backed up to TrueNAS + stored in Bitwarden
- **Configuration**: all `compose.yml` files — version controlled here

## Common Operations

```bash
make deploy       # pull latest images + start all services
make up           # start all services (no pull)
make down         # stop all services (no data loss)
make ps           # show container status
make logs         # stream all logs
make logs SERVICE=hel-prod-apps-taiga-back   # stream logs for one service
make restart SERVICE=hel-prod-apps-taiga-back
make backup       # rsync data + secrets to TrueNAS
```

## 🚨 Disaster Recovery

1. **Provision fresh Rocky 9.5 VM on Helios**
2. **Install Docker**
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   ```
3. **Clone this repo**
   ```bash
   git clone https://github.com/maakleerplek/helios-compose
   cd helios-compose
   ```
4. **Restore data from TrueNAS**
   ```bash
   rsync -az hel-prod-nas-truenas:/mnt/pool/backups/helios/var/lib/docker-compose/ /var/lib/docker-compose/
   ```
5. **Restore secrets**
   ```bash
   rsync -az hel-prod-nas-truenas:/mnt/pool/backups/helios/secrets/ ./secrets/
   # Or retrieve from Bitwarden
   ```
6. **Deploy**
   ```bash
   make up
   ```
7. **Verify**
   ```bash
   make ps
   make logs
   ```

## Adding a New Service

1. Create `services/hel-prod-{role}-{app}/compose.yml`
2. Follow the conventions in CLAUDE.md
3. Add the include line to root `docker-compose.yml`
4. Add secrets to `secrets/.env` and update `secrets/.env.example`
5. `make deploy`
6. Commit and push

## Current Services

| Service | Role | Port | Notes |
|---|---|---|---|
| `hel-prod-apps-taiga` | ICT project planning | 8083 | Proxied by NPM → `taiga.maakleerplek.be` |
| `hel-prod-apps-truedesk` | User helpdesk & feature requests | 8084 | Proxied by NPM → `truedesk.maakleerplek.be` |
| `hel-prod-apps-watchtower` | Nightly container auto-update | — | DBs excluded, runs at 04:00 |
| `hel-prod-mon-grafana` | Dashboards | 3000 | Proxied by NPM → `grafana.int.maakleerplek.be` |
| `hel-prod-mon-prometheus` | Metrics storage (30d retention) | — | Internal only |
| `hel-prod-mon-node-exporter` | Host metrics | — | Internal only |
| `hel-prod-mon-cadvisor` | Container metrics | — | Internal only |

## Grafana Dashboards

After first login to Grafana, import these from the dashboard library (Dashboards → Import → enter ID):

| ID | Dashboard |
|---|---|
| `1860` | Node Exporter Full — host CPU, RAM, disk, network |
| `14282` | Docker cAdvisor — per-container resource usage |

## Planned Services

| Service | Role |
|---|---|
| `hel-prod-apps-webhook` | GitOps auto-deploy on git push (see `feature.md`) |
