# The server stack: Docker Compose

Five containers, all defined in [docker-compose.yml](docker-compose.yml):

| Service | What it does |
|---|---|
| `postgres` | The database. Its data lives in a Docker volume, so it survives restarts and rebuilds. |
| `app` | Your app, built from its Dockerfile. Reachable only through Caddy. |
| `caddy` | https on ports 80 and 443, with Let's Encrypt certificates obtained and renewed by itself. |
| `backup` | A copy of the database every night ([../backups/](../backups/)). |
| `offsite` | Copies each backup to Cloudflare R2 every hour ([../backups/](../backups/), [../r2/](../r2/)). |

The example assumes an app that listens on port 3000, reads `DATABASE_URL`, and answers `GET /health`. Change the
`app` service to match yours.

## 1. Copy the files to the server (Mac)

Lay the repo out with the deploy files in a `deploy/` folder next to the app:

```
your-repo/
  app/            your code and its Dockerfile
  deploy/         docker-compose.yml, Caddyfile, .env.example  (from this folder)
```

Then copy only what the server builds from:

```bash
rsync -azR --exclude node_modules --exclude dist --exclude deploy/.env --exclude deploy/backups \
  -e "ssh -i ~/.ssh/<name>_oracle" app deploy ubuntu@<server-ip>:<name>/
```

`--exclude deploy/.env` and `--exclude deploy/backups` matter from the second copy on: the server's secrets and
backups exist only there and must never be overwritten.

## 2. Settings (server)

```bash
cd ~/<name>/deploy
cp .env.example .env
openssl rand -hex 32      # the database password: paste it into .env
nano .env                 # DOMAIN=api.<your-domain>, POSTGRES_PASSWORD=<the line above>
```

> **Snag: use hex for the password.** A base64 password (`openssl rand -base64`) can contain `/` or `+`, which
> break the `postgres://user:password@host/db` URL the app connects with.

## 3. Start it (server)

```bash
docker compose up -d --build
docker compose logs -f caddy      # wait for "certificate obtained successfully", then Ctrl+C
curl https://api.<your-domain>/health
docker compose ps                 # every service Up; postgres (healthy)
```

## 4. Updating

Copy the files again (step 1), then on the server:

```bash
cd ~/<name>/deploy && docker compose up -d --build && docker image prune -f
```

Only what changed is rebuilt or recreated; the database and its data stay. Use `up -d --build` for everything
rather than `up -d --build app`, or a new or changed service in the Compose file never starts.

To do this automatically on every merge, see [../github-actions/](../github-actions/).

## Day to day

```bash
docker compose ps                         # what's running
docker compose logs --tail 50 app         # an app's recent output
docker compose restart app                # restart one service
df -h /                                   # disk space (old images: docker image prune -f)
```
