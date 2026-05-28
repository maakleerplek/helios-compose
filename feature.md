# Feature: GitOps Webhook Auto-Deploy

## What
Automatically redeploy the stack whenever a commit is pushed to `main` on GitHub.

**Flow:**
```
git push → GitHub webhook → adnanh/webhook container → git pull + docker compose up -d
```

## Why not Watchtower?
Watchtower watches container image registries for new tags. It has no concept of git repositories. A dedicated webhook listener is needed for repo-triggered deploys.

## Implementation plan

### New service: `hel-prod-apps-webhook`
- Image: `almir/webhook` (adnanh/webhook, maintained build)
- Listens on port `9000`
- Exposed via NPM at e.g. `webhook.int.maakleerplek.be/hooks/deploy` (internal only)
- Needs access to Docker socket and the repo directory on the host

### Files to add
```
services/hel-prod-apps-webhook/
├── compose.yml
└── hooks.json          # webhook definition + HMAC validation rule
```

### Deploy script (on host)
```bash
#!/bin/bash
# /var/lib/docker-compose/hel-prod-apps-webhook/deploy.sh
set -e
cd /opt/helios-compose        # wherever the repo is cloned on the host
git pull origin main
docker compose up -d --remove-orphans
```

### hooks.json
```json
[
  {
    "id": "deploy",
    "execute-command": "/scripts/deploy.sh",
    "command-working-directory": "/",
    "trigger-rule": {
      "match": {
        "type": "payload-hmac-sha256",
        "secret": "WEBHOOK_SECRET",
        "parameter": { "source": "header", "name": "X-Hub-Signature-256" }
      }
    }
  }
]
```

### GitHub setup
1. Repo → Settings → Webhooks → Add webhook
2. Payload URL: `https://webhook.int.maakleerplek.be/hooks/deploy`
3. Content type: `application/json`
4. Secret: value of `WEBHOOK_SECRET` in `helios.env`
5. Trigger: "Just the push event"

## Security notes

| Risk | Mitigation |
|---|---|
| Unauthorized trigger | HMAC-SHA256 signature validated on every request — unsigned requests rejected |
| Malicious payload | Deploy script takes no input from the payload, only runs fixed commands |
| Repo compromise = prod deploy | Accepted risk for ICT-managed private repo; restrict write access on GitHub |
| Docker socket = root | Same risk as any Docker host service; acceptable in this context |

**The HMAC secret is the critical piece** — keep it strong and store it in Bitwarden.

## Env var to add to `helios.env`
```
# --- hel-prod-apps-webhook ---------------------------------------------------
WEBHOOK_SECRET=        # strong random string, also set in GitHub webhook settings
```
