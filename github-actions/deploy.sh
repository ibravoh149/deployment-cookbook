#!/usr/bin/env bash
# Copy what the server builds from, rebuild there, and wait for https://<domain>/health.
# By hand from the repo:  DEPLOY_HOST=ubuntu@api.example.com DEPLOY_URL=https://api.example.com bash scripts/deploy.sh
#
#   DEPLOY_HOST  the server, as you'd ssh to it
#   DEPLOY_KEY   the SSH key for it (default ~/.ssh/id_ed25519)
#   DEPLOY_URL   where the server answers, for the health check
#   DEPLOY_DIR   the folder on the server (default: app)
set -euo pipefail

HOST="${DEPLOY_HOST:?set DEPLOY_HOST, e.g. ubuntu@api.example.com}"
KEY="${DEPLOY_KEY:-$HOME/.ssh/id_ed25519}"
KEY="${KEY/#\~/$HOME}"
URL="${DEPLOY_URL:?set DEPLOY_URL, e.g. https://api.example.com}"
DIR="${DEPLOY_DIR:-app}"
SSH=(ssh -i "$KEY" -o ConnectTimeout=15)

cd "$(git rev-parse --show-toplevel)"

echo "1/3 Copying to $HOST"
# Never the server's own .env or backups: they exist only there.
rsync -azR --exclude node_modules --exclude dist --exclude deploy/.env --exclude deploy/backups \
  -e "ssh -i $KEY" app deploy "$HOST:$DIR/"

echo "2/3 Rebuilding on the server"
# All services, not only the app: a new or changed service in docker-compose.yml then ships too. Unchanged ones
# (the database, Caddy, backups) keep running. Old images are removed so they don't fill the disk.
"${SSH[@]}" "$HOST" "cd ~/$DIR/deploy && docker compose up -d --build && docker image prune -f >/dev/null && docker compose ps"

echo "3/3 Waiting for $URL/health"
for _ in $(seq 1 30); do
  if curl -fs -m 5 "$URL/health" >/dev/null; then
    echo "The server is up on the new version."
    exit 0
  fi
  sleep 2
done
echo "No healthy answer after a minute. See: ssh -i $KEY $HOST 'cd ~/$DIR/deploy && docker compose logs --tail 50 app'"
exit 1
