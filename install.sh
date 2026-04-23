#!/bin/bash
# =============================================================================
# hel-prod-app-docker — bootstrap script
# Run once on a fresh Rocky Linux 9.5 install.
# After this script: restore data from TrueNAS, restore secrets, then make up.
# =============================================================================

set -euo pipefail

# --- Guards ------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

echo "==> Starting hel-prod-app-docker bootstrap"

# --- System update + base dependencies ---------------------------------------

echo "==> Updating system and installing base dependencies"
dnf update -y
dnf install -y git make rsync curl

# --- Docker ------------------------------------------------------------------

echo "==> Installing Docker"
dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
echo "    Docker $(docker --version) installed and running"

# --- Directory structure -----------------------------------------------------

echo "==> Creating /opt/stacks"
mkdir -p /opt/stacks

echo "==> Creating /var/lib/docker-compose data directories"
mkdir -p \
  /var/lib/docker-compose/hel-prod-apps-coolify-ssh \
  /var/lib/docker-compose/hel-prod-apps-coolify-applications \
  /var/lib/docker-compose/hel-prod-apps-coolify-databases \
  /var/lib/docker-compose/hel-prod-apps-coolify-services \
  /var/lib/docker-compose/hel-prod-apps-coolify-backups \
  /var/lib/docker-compose/hel-prod-apps-coolify-db \
  /var/lib/docker-compose/hel-prod-apps-coolify-redis \
  /var/lib/docker-compose/hel-prod-inv-netbox-media \
  /var/lib/docker-compose/hel-prod-inv-netbox-reports \
  /var/lib/docker-compose/hel-prod-inv-netbox-scripts \
  /var/lib/docker-compose/hel-prod-inv-netbox-db \
  /var/lib/docker-compose/hel-prod-inv-netbox-redis \
  /var/lib/docker-compose/hel-prod-inv-netbox-redis-cache

echo "==> Setting Coolify storage ownership (runs as UID 9999)"
chown -R 9999:root /var/lib/docker-compose/hel-prod-apps-coolify-ssh \
  /var/lib/docker-compose/hel-prod-apps-coolify-applications \
  /var/lib/docker-compose/hel-prod-apps-coolify-databases \
  /var/lib/docker-compose/hel-prod-apps-coolify-services \
  /var/lib/docker-compose/hel-prod-apps-coolify-backups

echo "==> Creating coolify Docker network"
docker network create --attachable coolify 2>/dev/null || echo "    network 'coolify' already exists"

# --- Clone repo --------------------------------------------------------------

echo "==> Cloning helios-compose"
if [[ -d /opt/stacks/helios-compose ]]; then
  echo "    /opt/stacks/helios-compose already exists, pulling latest"
  git -C /opt/stacks/helios-compose pull
else
  git clone https://github.com/maakleerplek/helios-compose.git /opt/stacks/helios-compose
fi

# --- Done --------------------------------------------------------------------

echo ""
echo "==> Bootstrap complete. Next steps:"
echo ""
echo "  1. Restore data from TrueNAS:"
echo "       rsync -az hel-prod-nas-truenas:/mnt/pool/backups/helios/docker_data/ /var/lib/docker-compose/"
echo ""
echo "  2. Restore secrets:"
echo "       rsync -az hel-prod-nas-truenas:/mnt/pool/backups/helios/secrets/ /opt/stacks/helios-compose/secrets/"
echo "       # Or retrieve from Bitwarden and create secrets/.env + secrets/coolify.env manually"
echo "       # See secrets/*.example for templates"
echo ""
echo "  3. Deploy:"
echo "       cd /opt/stacks/helios-compose && make up"
echo ""
